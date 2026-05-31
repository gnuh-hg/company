import { useCallback, useEffect, useRef, useState } from 'react';
import {
  ReactFlow,
  Background,
  Controls,
  MiniMap,
  useNodesState,
  useEdgesState,
  MarkerType,
  useReactFlow,
  Panel,
} from '@xyflow/react';
import '@xyflow/react/dist/style.css';

import { nodeTypes } from './nodes.jsx';
import { applyDagreLayout } from './layout.js';

// ── helpers ────────────────────────────────────────────────────────────────

/**
 * Convert raw engine graph JSON into React Flow nodes + edges.
 * Detects terminal nodes (no outgoing edges) and sets ntype accordingly.
 */
function toReactFlow(graph) {
  const { nodes: raw, edges: rawEdges, entry } = graph;

  const hasOutgoing = new Set(rawEdges.map(e => e.from));

  const rfNodes = raw.map(n => {
    let ntype;
    if (n.type === 'router') ntype = 'router';
    else if (n.type === 'approval') ntype = 'approval';
    else if (!hasOutgoing.has(n.id)) ntype = 'terminal';
    else ntype = 'worker';

    return {
      id: n.id,
      type: ntype,
      data: {
        label: n.id,
        agent: n.agent ?? '',
        ntype,
        isEntry: n.id === entry,
      },
      position: { x: 0, y: 0 },
    };
  });

  const rfEdges = rawEdges.map((e, i) => ({
    id: `e-${e.from}-${e.to}-${i}`,
    source: e.from,
    target: e.to,
    label: e.when ?? '',
    // back-edge flag will be applied after layout
    type: 'smoothstep',
    markerEnd: { type: MarkerType.ArrowClosed, width: 16, height: 16 },
    style: {},
    labelStyle: { fontSize: 10, fontFamily: 'monospace', fill: '#475569' },
    labelBgStyle: { fill: '#f8fafc', fillOpacity: 0.85 },
  }));

  return { rfNodes, rfEdges };
}

/**
 * Apply back-edge visual overrides after dagre layout.
 * Back-edges get an orange dashed style to distinguish loops.
 */
function styleBackEdges(edges, backEdgeIds) {
  return edges.map(e =>
    backEdgeIds.has(e.id)
      ? {
          ...e,
          type: 'bezier',
          animated: false,
          style: { stroke: '#f97316', strokeDasharray: '5,3', strokeWidth: 1.5 },
          markerEnd: { type: MarkerType.ArrowClosed, width: 14, height: 14, color: '#f97316' },
        }
      : e,
  );
}

// ── FitOnLoad: call fitView after first render ──────────────────────────────
function FitOnLoad({ ready }) {
  const { fitView } = useReactFlow();
  useEffect(() => {
    if (ready) {
      // Small delay lets React Flow measure node dimensions first
      const t = setTimeout(() => fitView({ padding: 0.15, duration: 300 }), 80);
      return () => clearTimeout(t);
    }
  }, [ready, fitView]);
  return null;
}

// ── GraphView ──────────────────────────────────────────────────────────────

export default function GraphView({ project, nodeStatuses = {} }) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [meta, setMeta] = useState(null); // { entry, max_steps, nodeCount, edgeCount }

  const [nodes, setNodes, onNodesChange] = useNodesState([]);
  const [edges, setEdges, onEdgesChange] = useEdgesState([]);
  const [ready, setReady] = useState(false);

  // Refs for debounced layout save (always current values, no stale-closure risk)
  const nodesRef = useRef([]);
  const dagreRef = useRef([]); // dagre auto-layout positions for reset
  const saveTimerRef = useRef(null);
  useEffect(() => { nodesRef.current = nodes; }, [nodes]);

  useEffect(() => {
    if (!project) {
      setNodes([]);
      setEdges([]);
      setMeta(null);
      setReady(false);
      return;
    }

    setLoading(true);
    setError(null);
    setReady(false);

    Promise.all([
      fetch(`/api/graph?project=${encodeURIComponent(project)}`).then(r => {
        if (!r.ok) return r.json().then(b => Promise.reject(b.error ?? r.statusText));
        return r.json();
      }),
      // Load saved layout; silently fall back to {} on any error
      fetch(`/api/layout?project=${encodeURIComponent(project)}`).then(r => r.json()).catch(() => ({})),
    ])
      .then(([graph, layoutData]) => {
        const { rfNodes, rfEdges } = toReactFlow(graph);
        const { nodes: laid, backEdgeIds } = applyDagreLayout(rfNodes, rfEdges);

        // Apply saved positions (override dagre) if the layout file exists
        const saved = layoutData?.positions ?? {};
        const finalNodes = Object.keys(saved).length > 0
          ? laid.map(n => saved[n.id] ? { ...n, position: saved[n.id] } : n)
          : laid;

        dagreRef.current = laid; // save for Reset layout
        const styledEdges = styleBackEdges(rfEdges, backEdgeIds);
        setNodes(finalNodes);
        setEdges(styledEdges);
        setMeta({
          entry: graph.entry,
          max_steps: graph.max_steps,
          nodeCount: graph.nodes.length,
          edgeCount: graph.edges.length,
        });
        setReady(true);
      })
      .catch(err => {
        setError(String(err));
        setNodes([]);
        setEdges([]);
        setMeta(null);
      })
      .finally(() => setLoading(false));

    return () => { if (saveTimerRef.current) clearTimeout(saveTimerRef.current); };
  }, [project]);

  // Sync live run status into node.data.runStatus (preserves positions/layout).
  useEffect(() => {
    setNodes(prev => {
      let changed = false;
      const next = prev.map(n => {
        const rs = nodeStatuses[n.id] ?? null;
        if ((n.data.runStatus ?? null) === rs) return n;
        changed = true;
        return { ...n, data: { ...n.data, runStatus: rs } };
      });
      return changed ? next : prev;
    });
  }, [nodeStatuses, setNodes]);

  // Reset to dagre auto-layout: restore saved dagre positions + clear server layout file
  const resetLayout = useCallback(() => {
    if (!dagreRef.current.length || !project) return;
    const posMap = {};
    dagreRef.current.forEach(n => { posMap[n.id] = n.position; });
    setNodes(prev => prev.map(n => posMap[n.id] ? { ...n, position: posMap[n.id] } : n));
    fetch(`/api/layout?project=${encodeURIComponent(project)}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ positions: {} }),
    }).catch(() => {});
  }, [project, setNodes]);

  // Debounced save: collect all node positions → POST /api/layout
  const onNodeDragStop = useCallback(() => {
    if (saveTimerRef.current) clearTimeout(saveTimerRef.current);
    saveTimerRef.current = setTimeout(() => {
      const positions = {};
      nodesRef.current.forEach(n => { positions[n.id] = n.position; });
      fetch(`/api/layout?project=${encodeURIComponent(project)}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ positions }),
      }).catch(() => {}); // fire-and-forget, non-critical
    }, 600);
  }, [project]);

  if (!project) {
    return (
      <div className="flex h-full items-center justify-center text-slate-400 text-sm">
        Select a project to view its workflow graph.
      </div>
    );
  }

  if (loading) {
    return (
      <div className="flex h-full items-center justify-center text-slate-400 text-sm">
        Loading graph…
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex h-full items-center justify-center">
        <div className="rounded border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          Error: {error}
        </div>
      </div>
    );
  }

  return (
    <div className="relative h-full w-full">
      {/* Metadata strip */}
      {meta && (
        <div className="absolute top-3 left-1/2 z-10 -translate-x-1/2 rounded-full border border-slate-200 bg-white/90 px-4 py-1 text-xs text-slate-500 shadow-sm backdrop-blur-sm select-none pointer-events-none">
          entry:{' '}<span className="font-mono font-semibold text-slate-700">{meta.entry}</span>
          {'  ·  '}{meta.nodeCount} nodes · {meta.edgeCount} edges
          {meta.max_steps != null && <>{'  ·  '}max_steps:{' '}{meta.max_steps}</>}
        </div>
      )}

      <ReactFlow
        nodes={nodes}
        edges={edges}
        onNodesChange={onNodesChange}
        onEdgesChange={onEdgesChange}
        nodeTypes={nodeTypes}
        minZoom={0.2}
        maxZoom={2.5}
        panOnDrag
        zoomOnScroll
        nodesDraggable
        onNodeDragStop={onNodeDragStop}
      >
        <FitOnLoad ready={ready} />
        <Background color="#e2e8f0" gap={20} />
        <Controls />
        <Panel position="top-right">
          <button
            onClick={resetLayout}
            title="Reset to auto-layout (dagre)"
            style={{
              padding: '4px 10px', fontSize: 11, fontFamily: 'monospace',
              background: 'rgba(255,255,255,0.9)', border: '1px solid #cbd5e1',
              borderRadius: 6, color: '#475569', cursor: 'pointer',
              boxShadow: '0 1px 3px rgba(0,0,0,.08)', backdropFilter: 'blur(4px)',
            }}
          >
            Reset layout
          </button>
        </Panel>
        <MiniMap
          nodeColor={n => {
            switch (n.data?.ntype) {
              case 'router':   return '#fef9c3';
              case 'approval': return '#f3e8ff';
              case 'terminal': return /escalat/.test(n.id) ? '#fee2e2' : '#dcfce7';
              default:         return '#dbeafe';
            }
          }}
          maskColor="#f1f5f9cc"
        />
      </ReactFlow>

      {/* Legend */}
      <div className="absolute bottom-3 left-3 z-10 rounded-lg border border-slate-200 bg-white/90 px-3 py-2 text-xs text-slate-500 shadow-sm backdrop-blur-sm select-none pointer-events-none space-y-1">
        <div className="font-semibold text-slate-600 mb-1">Legend</div>
        <div className="flex items-center gap-2"><span style={{ display: 'inline-block', width: 14, height: 10, background: '#dbeafe', border: '1.5px solid #3b82f6', borderRadius: 2 }} /> worker</div>
        <div className="flex items-center gap-2"><span style={{ display: 'inline-block', width: 12, height: 12, background: '#fef9c3', border: '1.5px solid #ca8a04', clipPath: 'polygon(50% 0%,100% 50%,50% 100%,0% 50%)' }} /> router</div>
        <div className="flex items-center gap-2"><span style={{ display: 'inline-block', width: 14, height: 12, background: '#f3e8ff', border: '1.5px solid #9333ea', clipPath: 'polygon(25% 0%,75% 0%,100% 50%,75% 100%,25% 100%,0% 50%)' }} /> approval ⏸</div>
        <div className="flex items-center gap-2"><span style={{ display: 'inline-block', width: 14, height: 10, background: '#dcfce7', border: '1.5px solid #4ade80', borderRadius: 2 }} /> terminal</div>
        <div className="flex items-center gap-2 mt-1"><span style={{ display: 'inline-block', width: 20, height: 2, background: '#f97316', borderTop: '2px dashed #f97316' }} /> back-edge</div>
      </div>
    </div>
  );
}

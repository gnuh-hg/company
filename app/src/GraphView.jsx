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
  addEdge,
} from '@xyflow/react';
import '@xyflow/react/dist/style.css';

import { nodeTypes } from './nodes.jsx';
import { applyDagreLayout } from './layout.js';

// ── helpers ────────────────────────────────────────────────────────────────

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
      data: { label: n.id, agent: n.agent ?? '', ntype, isEntry: n.id === entry },
      position: { x: 0, y: 0 },
    };
  });

  const rfEdges = rawEdges.map((e, i) => ({
    id: `e-${e.from}-${e.to}-${i}`,
    source: e.from,
    target: e.to,
    label: e.when ?? '',
    type: 'smoothstep',
    markerEnd: { type: MarkerType.ArrowClosed, width: 16, height: 16 },
    style: {},
    labelStyle: { fontSize: 10, fontFamily: 'monospace', fill: '#475569' },
    labelBgStyle: { fill: '#f8fafc', fillOpacity: 0.85 },
  }));

  return { rfNodes, rfEdges };
}

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

// ── FitOnLoad ──────────────────────────────────────────────────────────────
function FitOnLoad({ ready }) {
  const { fitView } = useReactFlow();
  useEffect(() => {
    if (ready) {
      const t = setTimeout(() => fitView({ padding: 0.15, duration: 300 }), 80);
      return () => clearTimeout(t);
    }
  }, [ready, fitView]);
  return null;
}

// ── shared input style ────────────────────────────────────────────────────
const INP_STYLE = {
  display: 'block', width: '100%', marginTop: 2,
  padding: '3px 7px', fontSize: 11, fontFamily: 'monospace',
  border: '1px solid #cbd5e1', borderRadius: 4, outline: 'none',
  boxSizing: 'border-box',
};
const LBL_STYLE = { display: 'block', fontSize: 11, color: '#374151', marginBottom: 5 };
const LBL_KEY = { color: '#6b7280' };

// ── EdgePanel ──────────────────────────────────────────────────────────────
function EdgePanel({ edge, onWhenChange, onDelete, onClose }) {
  const [when, setWhen] = useState(edge.label ?? '');
  useEffect(() => { setWhen(edge.label ?? ''); }, [edge.id, edge.label]);

  return (
    <div style={{
      position: 'absolute', bottom: 90, right: 12, zIndex: 20,
      background: '#fff', border: '1px solid #cbd5e1', borderRadius: 8,
      padding: '10px 12px', boxShadow: '0 4px 16px rgba(0,0,0,.12)',
      width: 228, fontFamily: 'monospace',
    }}>
      <div style={{ fontSize: 10, color: '#94a3b8', marginBottom: 6 }}>
        {edge.source} → {edge.target}
      </div>
      <label style={LBL_STYLE}>
        <span style={LBL_KEY}>when:</span>
        <input
          type="text" value={when}
          onChange={e => { setWhen(e.target.value); onWhenChange(e.target.value); }}
          placeholder="(leave blank for default edge)" autoFocus style={INP_STYLE}
        />
      </label>
      <div style={{ display: 'flex', gap: 6, marginTop: 8 }}>
        <button onClick={onDelete} style={{
          flex: 1, padding: '4px 0', fontSize: 11, fontFamily: 'monospace',
          background: '#fee2e2', color: '#b91c1c', border: '1px solid #fca5a5',
          borderRadius: 5, cursor: 'pointer',
        }}>Delete edge</button>
        <button onClick={onClose} style={{
          flex: 1, padding: '4px 0', fontSize: 11, fontFamily: 'monospace',
          background: '#f1f5f9', color: '#475569', border: '1px solid #cbd5e1',
          borderRadius: 5, cursor: 'pointer',
        }}>Close</button>
      </div>
    </div>
  );
}

// ── NodePanel ──────────────────────────────────────────────────────────────
// Floating panel for editing an existing node's fields or deleting it.
function NodePanel({ rawNode, onUpdateField, onDelete, onClose }) {
  const [agent, setAgent] = useState(rawNode.agent ?? '');
  const [nodeType, setNodeType] = useState(rawNode.type ?? 'worker');
  const [outputKey, setOutputKey] = useState(rawNode.output_key ?? '');
  const [prompt, setPrompt] = useState(rawNode.prompt ?? '');

  // Re-sync when a different node is selected
  useEffect(() => {
    setAgent(rawNode.agent ?? '');
    setNodeType(rawNode.type ?? 'worker');
    setOutputKey(rawNode.output_key ?? '');
    setPrompt(rawNode.prompt ?? '');
  }, [rawNode.id]); // eslint-disable-line react-hooks/exhaustive-deps

  function handle(field, value) {
    if (field === 'agent') setAgent(value);
    else if (field === 'type') setNodeType(value);
    else if (field === 'output_key') setOutputKey(value);
    else if (field === 'prompt') setPrompt(value);
    onUpdateField(rawNode.id, field, value);
  }

  function handleDelete() {
    if (window.confirm(`Delete node "${rawNode.id}" and all its connected edges?`)) {
      onDelete(rawNode.id);
    }
  }

  const sel = (label, value, field, options) => (
    <label style={LBL_STYLE}>
      <span style={LBL_KEY}>{label}:</span>
      <select value={value} onChange={e => handle(field, e.target.value)}
        style={{ ...INP_STYLE, padding: '3px 4px' }}>
        {options.map(o => <option key={o} value={o}>{o}</option>)}
      </select>
    </label>
  );

  const inp = (label, value, field, placeholder = '') => (
    <label style={LBL_STYLE}>
      <span style={LBL_KEY}>{label}:</span>
      <input type="text" value={value} onChange={e => handle(field, e.target.value)}
        placeholder={placeholder} style={INP_STYLE} autoComplete="off" />
    </label>
  );

  return (
    <div style={{
      position: 'absolute', bottom: 90, left: 12, zIndex: 20,
      background: '#fff', border: '1px solid #cbd5e1', borderRadius: 8,
      padding: '10px 12px', boxShadow: '0 4px 16px rgba(0,0,0,.12)',
      width: 240, fontFamily: 'monospace',
    }}>
      <div style={{ fontSize: 10, color: '#94a3b8', marginBottom: 6 }}>
        node: <strong style={{ color: '#374151' }}>{rawNode.id}</strong>
      </div>
      {sel('type', nodeType, 'type', ['worker', 'router', 'approval'])}
      {inp('agent', agent, 'agent', 'catalog role')}
      {nodeType === 'worker' && inp('output_key', outputKey, 'output_key', 'e.g. result')}
      {inp('prompt', prompt, 'prompt', '(optional system prompt)')}
      <div style={{ display: 'flex', gap: 6, marginTop: 8 }}>
        <button onClick={handleDelete} style={{
          flex: 1, padding: '4px 0', fontSize: 11, fontFamily: 'monospace',
          background: '#fee2e2', color: '#b91c1c', border: '1px solid #fca5a5',
          borderRadius: 5, cursor: 'pointer',
        }}>Delete node</button>
        <button onClick={onClose} style={{
          flex: 1, padding: '4px 0', fontSize: 11, fontFamily: 'monospace',
          background: '#f1f5f9', color: '#475569', border: '1px solid #cbd5e1',
          borderRadius: 5, cursor: 'pointer',
        }}>Close</button>
      </div>
    </div>
  );
}

// ── AddNodePanel ───────────────────────────────────────────────────────────
// Floating form for creating a new node.
function AddNodePanel({ existingIds, onAdd, onClose }) {
  const [id, setId] = useState('');
  const [nodeType, setNodeType] = useState('worker');
  const [agent, setAgent] = useState('');
  const [outputKey, setOutputKey] = useState('');
  const [prompt, setPrompt] = useState('');
  const [err, setErr] = useState('');

  function handleAdd() {
    const trimId = id.trim();
    if (!trimId) { setErr('ID is required'); return; }
    if (!/^[A-Za-z0-9_-]+$/.test(trimId)) { setErr('ID: letters, digits, - _ only'); return; }
    if (existingIds.has(trimId)) { setErr('ID already exists'); return; }
    const result = onAdd({
      id: trimId, type: nodeType,
      agent: agent.trim(),
      output_key: outputKey.trim(),
      prompt: prompt.trim(),
    });
    if (result) { setErr(result); return; }
    onClose();
  }

  const inp = (label, value, onChange, placeholder = '') => (
    <label style={LBL_STYLE}>
      <span style={LBL_KEY}>{label}:</span>
      <input type="text" value={value} onChange={e => onChange(e.target.value)}
        placeholder={placeholder} autoComplete="off"
        style={INP_STYLE} />
    </label>
  );

  return (
    <div style={{
      position: 'absolute', top: 55, left: 12, zIndex: 20,
      background: '#fff', border: '1px solid #93c5fd', borderRadius: 8,
      padding: '10px 12px', boxShadow: '0 4px 16px rgba(0,0,0,.12)',
      width: 248, fontFamily: 'monospace',
    }}>
      <div style={{ fontWeight: 700, fontSize: 11, color: '#1e40af', marginBottom: 7 }}>+ Add node</div>
      {err && <div style={{ color: '#dc2626', fontSize: 10, marginBottom: 5 }}>⚠ {err}</div>}
      {inp('id', id, setId, 'node-id (unique, no spaces)')}
      <label style={LBL_STYLE}>
        <span style={LBL_KEY}>type:</span>
        <select value={nodeType} onChange={e => setNodeType(e.target.value)}
          style={{ ...INP_STYLE, padding: '3px 4px' }}>
          <option value="worker">worker</option>
          <option value="router">router</option>
          <option value="approval">approval</option>
        </select>
      </label>
      {nodeType !== 'approval' && inp('agent', agent, setAgent, 'catalog role (optional)')}
      {nodeType === 'worker' && inp('output_key', outputKey, setOutputKey, 'e.g. result')}
      {inp('prompt', prompt, setPrompt, '(optional)')}
      <div style={{ display: 'flex', gap: 6, marginTop: 8 }}>
        <button onClick={handleAdd} style={{
          flex: 1, padding: '4px 0', fontSize: 11, fontFamily: 'monospace', fontWeight: 700,
          background: '#3b82f6', color: '#fff', border: 'none',
          borderRadius: 5, cursor: 'pointer',
        }}>Add</button>
        <button onClick={onClose} style={{
          flex: 1, padding: '4px 0', fontSize: 11, fontFamily: 'monospace',
          background: '#f1f5f9', color: '#475569', border: '1px solid #cbd5e1',
          borderRadius: 5, cursor: 'pointer',
        }}>Cancel</button>
      </div>
    </div>
  );
}

// ── GraphView ──────────────────────────────────────────────────────────────

export default function GraphView({ project, nodeStatuses = {}, editMode = false, onDirtyChange, onFormatDetected }) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [meta, setMeta] = useState(null);

  const [nodes, setNodes, onNodesChange] = useNodesState([]);
  const [edges, setEdges, onEdgesChange] = useEdgesState([]);
  const [ready, setReady] = useState(false);

  // Edit-mode state
  const [rawGraph, setRawGraph] = useState(null);
  const [isDirty, setIsDirty] = useState(false);
  const [selectedEdgeId, setSelectedEdgeId] = useState(null);
  const [selectedNodeId, setSelectedNodeId] = useState(null);
  const [showAddNode, setShowAddNode] = useState(false);
  const [saveLoading, setSaveLoading] = useState(false);
  const [saveErrors, setSaveErrors] = useState([]);
  const [savedOk, setSavedOk] = useState(false);
  const [reloadKey, setReloadKey] = useState(0);

  const nodesRef = useRef([]);
  const dagreRef = useRef([]);
  const saveTimerRef = useRef(null);
  useEffect(() => { nodesRef.current = nodes; }, [nodes]);

  useEffect(() => { onDirtyChange?.(isDirty); }, [isDirty, onDirtyChange]);

  // ── Load graph ─────────────────────────────────────────────────────────
  useEffect(() => {
    if (!project) {
      setNodes([]); setEdges([]); setMeta(null); setRawGraph(null);
      setIsDirty(false); setSelectedEdgeId(null); setSelectedNodeId(null);
      setShowAddNode(false); setSaveErrors([]); setReady(false);
      onFormatDetected?.(null);
      return;
    }
    setLoading(true); setError(null); setReady(false);

    Promise.all([
      fetch(`/api/graph?project=${encodeURIComponent(project)}`).then(r => {
        if (!r.ok) return r.json().then(b => Promise.reject(b.error ?? r.statusText));
        return r.json();
      }),
      fetch(`/api/layout?project=${encodeURIComponent(project)}`).then(r => r.json()).catch(() => ({})),
      fetch(`/api/workflow?project=${encodeURIComponent(project)}`).then(r => r.ok ? r.json() : null).catch(() => null),
    ])
      .then(([graph, layoutData, rawWorkflow]) => {
        // Detect workflow format: pipeline-v1 has a `pipeline` array (not `nodes`/`edges`).
        const format = Array.isArray(rawWorkflow?.pipeline) ? 'pipeline-v1' : 'graph';
        onFormatDetected?.(format);
        const { rfNodes, rfEdges } = toReactFlow(graph);
        const { nodes: laid, backEdgeIds } = applyDagreLayout(rfNodes, rfEdges);
        const saved = layoutData?.positions ?? {};
        const finalNodes = Object.keys(saved).length > 0
          ? laid.map(n => saved[n.id] ? { ...n, position: saved[n.id] } : n)
          : laid;
        dagreRef.current = laid;
        const styledEdges = styleBackEdges(rfEdges, backEdgeIds);
        setRawGraph(rawWorkflow ?? graph);
        setNodes(finalNodes);
        setEdges(styledEdges);
        setMeta({ entry: graph.entry, max_steps: graph.max_steps, nodeCount: graph.nodes.length, edgeCount: graph.edges.length });
        setIsDirty(false); setSelectedEdgeId(null); setSelectedNodeId(null);
        setShowAddNode(false); setSaveErrors([]); setSavedOk(false); setReady(true);
      })
      .catch(err => {
        setError(String(err)); setNodes([]); setEdges([]); setMeta(null); setRawGraph(null);
      })
      .finally(() => setLoading(false));

    return () => { if (saveTimerRef.current) clearTimeout(saveTimerRef.current); };
  }, [project, reloadKey]);

  // Sync live run status into node data
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

  // Reset to dagre layout
  const resetLayout = useCallback(() => {
    if (!dagreRef.current.length || !project) return;
    const posMap = {};
    dagreRef.current.forEach(n => { posMap[n.id] = n.position; });
    setNodes(prev => prev.map(n => posMap[n.id] ? { ...n, position: posMap[n.id] } : n));
    fetch(`/api/layout?project=${encodeURIComponent(project)}`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ positions: {} }),
    }).catch(() => {});
  }, [project, setNodes]);

  // Debounced layout save on drag
  const onNodeDragStop = useCallback(() => {
    if (saveTimerRef.current) clearTimeout(saveTimerRef.current);
    saveTimerRef.current = setTimeout(() => {
      const positions = {};
      nodesRef.current.forEach(n => { positions[n.id] = n.position; });
      fetch(`/api/layout?project=${encodeURIComponent(project)}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ positions }),
      }).catch(() => {});
    }, 600);
  }, [project]);

  // ── Edit-mode: edge callbacks ──────────────────────────────────────────

  const handleEdgesChange = useCallback((changes) => {
    if (!editMode) {
      onEdgesChange(changes.filter(c => c.type !== 'remove'));
      return;
    }
    if (changes.some(c => c.type === 'remove')) {
      setIsDirty(true);
      setSelectedEdgeId(prev =>
        changes.some(c => c.type === 'remove' && c.id === prev) ? null : prev
      );
    }
    onEdgesChange(changes);
  }, [editMode, onEdgesChange]);

  const onConnect = useCallback((params) => {
    if (!editMode) return;
    setEdges(prev => addEdge({
      ...params,
      id: `e-${params.source}-${params.target}-${Date.now()}`,
      label: '', type: 'smoothstep',
      markerEnd: { type: MarkerType.ArrowClosed, width: 16, height: 16 },
      style: {},
      labelStyle: { fontSize: 10, fontFamily: 'monospace', fill: '#475569' },
      labelBgStyle: { fill: '#f8fafc', fillOpacity: 0.85 },
    }, prev));
    setIsDirty(true);
  }, [editMode, setEdges]);

  const onEdgeClick = useCallback((_event, edge) => {
    if (!editMode) return;
    setSelectedEdgeId(edge.id);
    setSelectedNodeId(null);
  }, [editMode]);

  const updateEdgeWhen = useCallback((when) => {
    setEdges(prev => prev.map(e => e.id === selectedEdgeId ? { ...e, label: when } : e));
    setIsDirty(true);
  }, [selectedEdgeId, setEdges]);

  const deleteSelectedEdge = useCallback(() => {
    setEdges(prev => prev.filter(e => e.id !== selectedEdgeId));
    setSelectedEdgeId(null);
    setIsDirty(true);
  }, [selectedEdgeId, setEdges]);

  // ── Edit-mode: node callbacks ──────────────────────────────────────────

  const onNodeClick = useCallback((_event, node) => {
    if (!editMode) return;
    setSelectedNodeId(node.id);
    setSelectedEdgeId(null);
    setShowAddNode(false);
  }, [editMode]);

  // Update a field of a raw node; also sync RF node visual if needed.
  const updateNodeField = useCallback((nodeId, field, value) => {
    setRawGraph(prev => {
      if (!prev) return prev;
      return { ...prev, nodes: prev.nodes.map(n => n.id === nodeId ? { ...n, [field]: value } : n) };
    });
    if (field === 'type') {
      // RF node type must match for correct shape rendering.
      const rfType = value === 'router' ? 'router' : value === 'approval' ? 'approval' : 'worker';
      setNodes(prev => prev.map(n => n.id === nodeId
        ? { ...n, type: rfType, data: { ...n.data, ntype: rfType } }
        : n
      ));
    }
    if (field === 'agent') {
      setNodes(prev => prev.map(n => n.id === nodeId
        ? { ...n, data: { ...n.data, agent: value } }
        : n
      ));
    }
    setIsDirty(true);
  }, [setNodes]);

  // Delete a node and cascade-remove all connected edges.
  const deleteNode = useCallback((nodeId) => {
    setEdges(prev => prev.filter(e => e.source !== nodeId && e.target !== nodeId));
    setNodes(prev => prev.filter(n => n.id !== nodeId));
    setRawGraph(prev => prev ? { ...prev, nodes: prev.nodes.filter(n => n.id !== nodeId) } : prev);
    setSelectedNodeId(null);
    setIsDirty(true);
  }, [setEdges, setNodes]);

  // Add a new node (semantic + RF).
  const addNode = useCallback((nodeData) => {
    const { id, type, agent, output_key, prompt } = nodeData;
    if (!id) return 'ID is required';
    if (rawGraph?.nodes.some(n => n.id === id)) return 'ID already exists';

    const rawNode = { id, type: type || 'worker' };
    if (agent) rawNode.agent = agent;
    if (output_key) rawNode.output_key = output_key;
    if (prompt) rawNode.prompt = prompt;

    setRawGraph(prev => prev ? { ...prev, nodes: [...prev.nodes, rawNode] } : prev);

    const rfType = type === 'router' ? 'router' : type === 'approval' ? 'approval' : 'worker';
    // Place new node near center with a small random offset so multiple adds don't stack.
    const newRFNode = {
      id, type: rfType,
      data: { label: id, agent: agent ?? '', ntype: rfType, isEntry: false },
      position: { x: 200 + Math.random() * 80, y: 160 + Math.random() * 80 },
    };
    setNodes(prev => [...prev, newRFNode]);
    setIsDirty(true);
    return null;
  }, [rawGraph, setNodes]);

  // Graph-level: change entry node.
  const updateEntry = useCallback((nodeId) => {
    setRawGraph(prev => prev ? { ...prev, entry: nodeId } : prev);
    setNodes(prev => prev.map(n => ({ ...n, data: { ...n.data, isEntry: n.id === nodeId } })));
    setMeta(prev => prev ? { ...prev, entry: nodeId } : prev);
    setIsDirty(true);
  }, [setNodes]);

  // Graph-level: change max_steps.
  const updateMaxSteps = useCallback((val) => {
    const n = parseInt(val, 10);
    if (isNaN(n) || n < 1) return;
    setRawGraph(prev => prev ? { ...prev, max_steps: n } : prev);
    setMeta(prev => prev ? { ...prev, max_steps: n } : prev);
    setIsDirty(true);
  }, []);

  // ── Save / Discard ─────────────────────────────────────────────────────

  const saveGraph = useCallback(async () => {
    if (!rawGraph || !project || saveLoading) return;
    setSaveLoading(true); setSaveErrors([]); setSavedOk(false);

    const semanticEdges = edges.map(e => {
      const obj = { from: e.source, to: e.target };
      if (e.label) obj.when = e.label;
      return obj;
    });
    const candidate = {
      ...(rawGraph.name !== undefined && { name: rawGraph.name }),
      nodes: rawGraph.nodes,
      edges: semanticEdges,
      entry: rawGraph.entry,
      max_steps: rawGraph.max_steps,
    };

    try {
      const r = await fetch(`/api/workflow?project=${encodeURIComponent(project)}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(candidate),
      });
      const body = await r.json();
      if (r.ok && body.ok) {
        // Re-fetch both normalized graph (for layout/meta) + raw workflow (for round-trip).
        const [updatedGraph, updatedWorkflow] = await Promise.all([
          fetch(`/api/graph?project=${encodeURIComponent(project)}`).then(r2 => r2.json()),
          fetch(`/api/workflow?project=${encodeURIComponent(project)}`).then(r2 => r2.ok ? r2.json() : null).catch(() => null),
        ]);
        const { rfNodes: newRfNodes, rfEdges: newRfEdges } = toReactFlow(updatedGraph);
        const { nodes: laid, backEdgeIds } = applyDagreLayout(newRfNodes, newRfEdges);
        const posMap = {};
        nodesRef.current.forEach(n => { posMap[n.id] = n.position; });
        const finalNodes = laid.map(n => posMap[n.id] ? { ...n, position: posMap[n.id] } : n);
        setRawGraph(updatedWorkflow ?? updatedGraph);
        setNodes(finalNodes);
        setEdges(styleBackEdges(newRfEdges, backEdgeIds));
        setMeta({
          entry: updatedGraph.entry,
          max_steps: updatedGraph.max_steps,
          nodeCount: updatedGraph.nodes.length,
          edgeCount: updatedGraph.edges.length,
        });
        // Persist positions (incl. new nodes added this session) so reload restores them.
        // Without this, new nodes fall back to dagre on next load.
        const positions = {};
        finalNodes.forEach(n => { positions[n.id] = n.position; });
        fetch(`/api/layout?project=${encodeURIComponent(project)}`, {
          method: 'POST', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ positions }),
        }).catch(() => {});
        setIsDirty(false); setSelectedEdgeId(null); setSelectedNodeId(null);
        setShowAddNode(false); setSaveErrors([]); setSavedOk(true);
        setTimeout(() => setSavedOk(false), 2500);
      } else {
        setSaveErrors(body.errors ?? [body.error ?? 'Unknown error']);
      }
    } catch (err) {
      setSaveErrors([String(err)]);
    } finally {
      setSaveLoading(false);
    }
  }, [rawGraph, project, saveLoading, edges, setNodes, setEdges]);

  const discardChanges = useCallback(() => {
    setIsDirty(false); setSelectedEdgeId(null); setSelectedNodeId(null);
    setShowAddNode(false); setSaveErrors([]);
    setReloadKey(k => k + 1);
  }, []);

  // ── Derived ────────────────────────────────────────────────────────────
  const selectedEdge = selectedEdgeId ? edges.find(e => e.id === selectedEdgeId) : null;
  const selectedRawNode = selectedNodeId && rawGraph
    ? rawGraph.nodes.find(n => n.id === selectedNodeId)
    : null;
  const existingNodeIds = rawGraph?.nodes ? new Set(rawGraph.nodes.map(n => n.id)) : new Set();

  // ── Render ─────────────────────────────────────────────────────────────
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

      {/* Edit mode badge */}
      {editMode && (
        <div style={{
          position: 'absolute', top: 12, left: 12, zIndex: 10,
          padding: '3px 10px', fontSize: 10, fontFamily: 'monospace', fontWeight: 700,
          background: isDirty ? '#fef3c7' : '#fffbeb',
          border: `1px solid ${isDirty ? '#f59e0b' : '#fde68a'}`,
          borderRadius: 20, color: isDirty ? '#92400e' : '#b45309',
          boxShadow: '0 1px 3px rgba(0,0,0,.08)',
          pointerEvents: 'none', userSelect: 'none',
        }}>
          ✎ EDIT{isDirty ? ' — unsaved changes' : ''}
        </div>
      )}

      <ReactFlow
        nodes={nodes} edges={edges}
        onNodesChange={onNodesChange}
        onEdgesChange={handleEdgesChange}
        onConnect={onConnect}
        onEdgeClick={onEdgeClick}
        onNodeClick={onNodeClick}
        onPaneClick={() => {
          if (editMode) { setSelectedEdgeId(null); setSelectedNodeId(null); }
        }}
        nodeTypes={nodeTypes}
        nodesConnectable={editMode}
        edgesFocusable={editMode}
        minZoom={0.2} maxZoom={2.5}
        panOnDrag zoomOnScroll nodesDraggable
        onNodeDragStop={onNodeDragStop}
      >
        <FitOnLoad ready={ready} />
        <Background color="#e2e8f0" gap={20} />
        <Controls />

        {/* Top-right panel: save/discard + graph settings + reset layout */}
        <Panel position="top-right">
          <div style={{ display: 'flex', flexDirection: 'column', gap: 5, alignItems: 'flex-end' }}>
            {editMode && (
              <>
                <div style={{ display: 'flex', gap: 5 }}>
                  <button
                    onClick={() => { setShowAddNode(v => !v); setSelectedNodeId(null); setSelectedEdgeId(null); }}
                    title="Add a new node to the graph"
                    style={{
                      padding: '4px 10px', fontSize: 11, fontFamily: 'monospace', fontWeight: 700,
                      background: showAddNode ? '#dbeafe' : 'rgba(255,255,255,0.9)',
                      color: showAddNode ? '#1e40af' : '#64748b',
                      border: showAddNode ? '1px solid #93c5fd' : '1px solid #cbd5e1',
                      borderRadius: 6, cursor: 'pointer',
                      boxShadow: '0 1px 3px rgba(0,0,0,.08)',
                    }}
                  >
                    + Node
                  </button>
                  <button
                    onClick={saveGraph}
                    disabled={saveLoading || !isDirty}
                    title="Save graph via engine (validate-gated)"
                    style={{
                      padding: '4px 12px', fontSize: 11, fontFamily: 'monospace', fontWeight: 700,
                      background: saveLoading ? '#e2e8f0' : (!isDirty ? '#e2e8f0' : '#22c55e'),
                      color: (!isDirty || saveLoading) ? '#94a3b8' : '#fff',
                      border: 'none', borderRadius: 6,
                      cursor: (!isDirty || saveLoading) ? 'not-allowed' : 'pointer',
                      boxShadow: '0 1px 3px rgba(0,0,0,.1)', transition: 'background 0.15s',
                    }}
                  >
                    {saveLoading ? '⏳ Saving…' : savedOk ? '✓ Saved' : '💾 Save graph'}
                  </button>
                  <button
                    onClick={discardChanges}
                    disabled={saveLoading}
                    title="Discard all pending changes and reload from disk"
                    style={{
                      padding: '4px 10px', fontSize: 11, fontFamily: 'monospace',
                      background: 'rgba(255,255,255,0.9)', border: '1px solid #cbd5e1',
                      borderRadius: 6, color: '#64748b',
                      cursor: saveLoading ? 'not-allowed' : 'pointer',
                      boxShadow: '0 1px 3px rgba(0,0,0,.08)', backdropFilter: 'blur(4px)',
                    }}
                  >
                    Discard
                  </button>
                </div>

                {/* Validation errors from rejected save */}
                {saveErrors.length > 0 && (
                  <div style={{
                    background: '#fff1f2', border: '1px solid #fca5a5', borderRadius: 6,
                    padding: '6px 10px', maxWidth: 300, fontSize: 10, fontFamily: 'monospace',
                    color: '#b91c1c', lineHeight: 1.5,
                  }}>
                    <div style={{ fontWeight: 700, marginBottom: 3 }}>Validation errors:</div>
                    {saveErrors.map((e, i) => <div key={i}>• {e}</div>)}
                  </div>
                )}

                {/* Graph-level settings: entry + max_steps */}
                {rawGraph && (
                  <div style={{
                    background: 'rgba(255,255,255,0.95)', border: '1px solid #e2e8f0',
                    borderRadius: 6, padding: '7px 10px', fontSize: 11, fontFamily: 'monospace',
                    width: 220, boxShadow: '0 1px 3px rgba(0,0,0,.07)',
                  }}>
                    <div style={{ color: '#6b7280', fontSize: 10, fontWeight: 700, marginBottom: 5 }}>
                      Graph settings
                    </div>
                    <label style={{ ...LBL_STYLE, marginBottom: 6 }}>
                      <span style={LBL_KEY}>entry:</span>
                      <select
                        value={rawGraph.entry ?? ''}
                        onChange={e => updateEntry(e.target.value)}
                        style={{ ...INP_STYLE, padding: '3px 4px' }}
                      >
                        {rawGraph.nodes.map(n => (
                          <option key={n.id} value={n.id}>{n.id}</option>
                        ))}
                      </select>
                    </label>
                    <label style={{ ...LBL_STYLE, marginBottom: 0 }}>
                      <span style={LBL_KEY}>max_steps:</span>
                      <input
                        type="number" min={1}
                        value={rawGraph.max_steps ?? ''}
                        onChange={e => updateMaxSteps(e.target.value)}
                        style={{ ...INP_STYLE, width: 80 }}
                      />
                    </label>
                  </div>
                )}
              </>
            )}

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
          </div>
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

      {/* Add-node panel (top-left, below EDIT badge) */}
      {editMode && showAddNode && (
        <AddNodePanel
          existingIds={existingNodeIds}
          onAdd={addNode}
          onClose={() => setShowAddNode(false)}
        />
      )}

      {/* Node edit panel (bottom-left) */}
      {editMode && selectedRawNode && (
        <NodePanel
          rawNode={selectedRawNode}
          onUpdateField={updateNodeField}
          onDelete={deleteNode}
          onClose={() => setSelectedNodeId(null)}
        />
      )}

      {/* Edge edit panel (bottom-right) */}
      {editMode && selectedEdge && (
        <EdgePanel
          edge={selectedEdge}
          onWhenChange={updateEdgeWhen}
          onDelete={deleteSelectedEdge}
          onClose={() => setSelectedEdgeId(null)}
        />
      )}

      {/* Legend */}
      <div className="absolute bottom-3 left-3 z-10 rounded-lg border border-slate-200 bg-white/90 px-3 py-2 text-xs text-slate-500 shadow-sm backdrop-blur-sm select-none pointer-events-none space-y-1">
        <div className="font-semibold text-slate-600 mb-1">Legend</div>
        <div className="flex items-center gap-2"><span style={{ display: 'inline-block', width: 14, height: 10, background: '#dbeafe', border: '1.5px solid #3b82f6', borderRadius: 2 }} /> worker</div>
        <div className="flex items-center gap-2"><span style={{ display: 'inline-block', width: 12, height: 12, background: '#fef9c3', border: '1.5px solid #ca8a04', clipPath: 'polygon(50% 0%,100% 50%,50% 100%,0% 50%)' }} /> router</div>
        <div className="flex items-center gap-2"><span style={{ display: 'inline-block', width: 14, height: 12, background: '#f3e8ff', border: '1.5px solid #9333ea', clipPath: 'polygon(25% 0%,75% 0%,100% 50%,75% 100%,25% 100%,0% 50%)' }} /> approval ⏸</div>
        <div className="flex items-center gap-2"><span style={{ display: 'inline-block', width: 14, height: 10, background: '#dcfce7', border: '1.5px solid #4ade80', borderRadius: 2 }} /> terminal</div>
        <div className="flex items-center gap-2 mt-1"><span style={{ display: 'inline-block', width: 20, height: 2, background: '#f97316', borderTop: '2px dashed #f97316' }} /> back-edge</div>
        {editMode && (
          <>
            <div className="flex items-center gap-2 mt-1" style={{ color: '#b45309' }}>✎ click node to edit fields</div>
            <div className="flex items-center gap-2" style={{ color: '#b45309' }}>✎ drag handles to connect</div>
          </>
        )}
      </div>
    </div>
  );
}

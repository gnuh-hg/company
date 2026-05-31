import dagre from 'dagre';

// Bounding-box dimensions fed to dagre for layout.
// These must match the rendered sizes of each custom node.
export const NODE_DIMS = {
  worker:   { width: 164, height: 52 },
  router:   { width: 90,  height: 90 },
  approval: { width: 108, height: 90 },
  terminal: { width: 164, height: 52 },
};

/**
 * Compute TB dagre layout positions and detect back-edges (source lower than
 * target in the top-down layout = edge going upward = loop back-edge).
 *
 * @param {import('@xyflow/react').Node[]} nodes - React Flow nodes (position ignored)
 * @param {import('@xyflow/react').Edge[]} edges - React Flow edges
 * @returns {{ nodes: import('@xyflow/react').Node[], backEdgeIds: Set<string> }}
 */
export function applyDagreLayout(nodes, edges) {
  const g = new dagre.graphlib.Graph({ multigraph: true });
  g.setDefaultEdgeLabel(() => ({}));
  g.setGraph({ rankdir: 'TB', ranksep: 80, nodesep: 44, marginx: 32, marginy: 32 });

  nodes.forEach(n => {
    const d = NODE_DIMS[n.data.ntype] ?? NODE_DIMS.worker;
    g.setNode(n.id, { width: d.width, height: d.height });
  });

  edges.forEach(e => {
    g.setEdge(e.source, e.target, {}, e.id);
  });

  dagre.layout(g);

  const positioned = nodes.map(n => {
    const { x, y, width, height } = g.node(n.id);
    return { ...n, position: { x: x - width / 2, y: y - height / 2 } };
  });

  const posY = Object.fromEntries(positioned.map(n => [n.id, n.position.y]));
  const backEdgeIds = new Set(
    edges
      .filter(e => (posY[e.source] ?? 0) > (posY[e.target] ?? 0))
      .map(e => e.id),
  );

  return { nodes: positioned, backEdgeIds };
}

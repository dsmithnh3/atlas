<!-- Ported from atlas/docs/STATUS.md (Earlier milestones section) on 2026-05-07 via /port-docs -->
# Atlas — Earlier Milestones (pre-2026-04-27)

Snapshot of the undated "Earlier milestones" section from `docs/STATUS.md` (last updated 2026-04-29). Preserved here because items are not date-attributable to a specific session. Newer dated work lives in `~/.claude/sessions/atlas/`.

## Quick Orientation (from same STATUS.md)

Atlas is a macOS PDF reader with an AI-powered knowledge map. Read `CLAUDE.md` in the project root for build commands, architecture, and gotchas.

Key entry points:
- `MultiDocumentView.swift` — main container (sidebar + detail pane)
- `PDFViewerView.swift` — PDF viewer (~1800 lines, largest file)
- `Atlas/` directory — knowledge map system (extraction pipeline, graph, renderer)

## Earlier milestones

- Cross-document merge engine with LLM-powered semantic merge proposals
- Concept-entity hierarchy rendering in canvas
- Persistent color-coded PDF highlights synced from knowledge graph
- Per-document and batch extraction triggers in project files panel
- Debounced resize to fix window and split pane lag
- Bounding box pulse highlight on page navigation
- Text-selection-based highlighting (replaced rectangle drag)
- Multi-document tabs, comparison mode, project explorer
- Full AI extraction pipeline with 4 backends

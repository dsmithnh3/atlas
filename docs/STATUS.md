# Atlas PDF Viewer - Current Status

**Last updated:** 2026-04-29

## Quick Orientation

Atlas is a macOS PDF reader with an AI-powered knowledge map. Read `CLAUDE.md` in the project root for build commands, architecture, and gotchas.

Key entry points:
- `MultiDocumentView.swift` — main container (sidebar + detail pane)
- `PDFViewerView.swift` — PDF viewer (~1800 lines, largest file)
- `Atlas/` directory — knowledge map system (extraction pipeline, graph, renderer)

## Recent Work (newest first)

### 2026-04-28 — Map interaction fixes + session restore (PR #23)
- **Recenter button** in map toolbar — fits all nodes into viewport
- **Persisted graph loading** — graphs saved to disk now load automatically when reopening a document
- **Fit viewport on zoom level change** — switching semantic zoom levels auto-fits content
- **Pan/drag fix** — node drag used cumulative translation causing runaway movement; fixed to use `startPos + delta`
- **Split pane resize fix** — debounced resize-triggered work to eliminate window/split-pane lag
- **Scroll-wheel zoom** — new `ScrollWheelOverlay.swift` captures AppKit scroll events, zoom centers on cursor position
- **Session restore** — split pane state and open documents restored across launches
- **Guard layout during drag** — `fitToContent` and `recomputeLayout` gated by `isDraggingNode` flag
- **Structured logging** — `AtlasLogger` with `os_log` categories: pipeline, ai, graph, text, sync, ui
- **Pipeline fixes** — cancel fully resets state, `isProcessing` lifecycle moved to `processFullDocument`, extraction cancellation sets document state to `.unprocessed`
- **Project graph persistence** — `projectID` threaded through extraction; saves to project graph when applicable
- **`GraphStore.flushPendingSave`** — called on app termination to avoid data loss

### 2026-04-27 — Viewer UX + Extraction UX (4 fixes)
- **Alert system** — `CompactAlertView` overlay wired into `MultiDocumentView`. `AppError` has `.severity` (`.modal` vs `.toast`). `AlertManager.routeError()` dispatches accordingly.
- **Recent files UX** — Inaccessible files shown dimmed with warning icon instead of silently removed. Right-click context menu. Stale launch counter auto-removes after 3 launches. `DocumentManager.openDocument()` returns `OpenResult` enum.
- **Progress + cancel** — `ExtractionPipeline` has `progress` property, `cancel()` via Task cancellation, page counter. Map view shows progress bar + cancel button.
- **OCR fallback** — `TextExtractor` has Vision OCR (`ocrExtractPages`) at 300 DPI. Auto-runs when no embedded text found. Scanned PDF banner with "Run OCR" button.

### Earlier milestones
- Cross-document merge engine with LLM-powered semantic merge proposals
- Concept-entity hierarchy rendering in canvas
- Persistent color-coded PDF highlights synced from knowledge graph
- Per-document and batch extraction triggers in project files panel
- Debounced resize to fix window and split pane lag
- Bounding box pulse highlight on page navigation
- Text-selection-based highlighting (replaced rectangle drag)
- Multi-document tabs, comparison mode, project explorer
- Full AI extraction pipeline with 4 backends

## What's Next

### Remaining work from `docs/TODO.md` (not yet started):
- **Annotation move/resize** — handles/drag UX (TODO item 13)
- **Dark mode** — end-to-end appearance validation (TODO item 13)
- **Instruments profiling** — Time Profiler + Allocations on large PDFs (TODO item 11)
- **Annotation coordinate system** — verify accuracy, use PDFKit built-in methods (TODO item 9)
- **State management** — currentHighlight sync, annotation persistence (TODO item 10)
- **Xcode test target** — test files exist in `pdf_app1Tests/` but aren't wired into a scheme (TODO item 16)
- **Project-level search** — V2 of Projects feature, multi-PDF search (TODO item 18)

### Priority order:
1. Manual testing of recent UX fixes
2. Annotation move/resize
3. Dark mode tuning
4. Project-level search (V2)

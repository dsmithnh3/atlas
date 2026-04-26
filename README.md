# Atlas

A native macOS PDF reader with a live, AI-generated knowledge map. Open a PDF, and Atlas builds a navigable graph of concepts as you read — linked back to every source passage, spanning multiple documents.

## What It Does

- **PDF Viewer** — Full-featured reader with highlights, annotations, search, bookmarks, multi-tab, comparison mode
- **Knowledge Map** — AI extracts concepts from your PDFs and renders them as an interactive force-directed graph in a right-side panel
- **Bidirectional Sync** — Scroll the PDF and the active concept lights up on the map. Click a map node and the PDF jumps to the source passage with a color-matched pulse
- **Cross-Document Correlations** — Add multiple PDFs to a project. Atlas merges shared concepts across documents and shows you the connections
- **Pluggable AI** — Bring your own API key for Claude, OpenAI, Gemini, or run locally via Ollama
- **Export** — Export your knowledge graph to Obsidian (wikilinks), Markdown, or JSON

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 16.0 or later
- No external dependencies — uses only Apple system frameworks (PDFKit, SwiftUI, AppKit, CryptoKit, Security)

## Getting Started

### 1. Clone and open

```bash
git clone <repository-url>
cd pdf_app_1
open pdf_app1/pdf_app1.xcodeproj
```

### 2. Build and run

In Xcode, select the `pdf_app1` scheme, target your Mac, and press **Cmd+R**.

Alternatively, build from the command line:

```bash
cd pdf_app1
xcodebuild -project pdf_app1.xcodeproj -scheme pdf_app1 -configuration Debug build
```

The built app will be in `~/Library/Developer/Xcode/DerivedData/pdf_app1-*/Build/Products/Debug/pdf_app1.app`.

### 3. Configure AI (optional but recommended)

1. Open **Settings** (Cmd+,) and go to the **AI** tab
2. Select a provider: Anthropic Claude, OpenAI, Google Gemini, or Ollama (local)
3. Enter your API key (stored in macOS Keychain, never in plain files)
4. Choose a model (e.g., `claude-sonnet-4-5-20250514`, `gpt-4o`, `gemini-2.5-flash`)

For Ollama (free, local, no API key):
- Install Ollama: `brew install ollama`
- Pull a model: `ollama pull llama3.1`
- Atlas connects to `http://localhost:11434` by default

### 4. Open a PDF and analyze

1. Open a PDF via the project sidebar or Cmd+T
2. The split view shows the PDF on the left and the knowledge map on the right
3. Click **Analyze Document** (brain icon) in the map panel to start concept extraction
4. Concepts appear as nodes; scroll the PDF to see the active node highlighted

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Cmd+1 | PDF only |
| Cmd+2 | Map only |
| Cmd+3 | Split view (default) |
| Cmd+K | Command palette — jump to any concept or page |
| Cmd+F | Search (context-aware: searches whichever pane has focus) |
| Cmd+T | New tab / open file |
| Cmd+W | Close tab |
| Cmd+Z | Undo |
| Cmd+Shift+Z | Redo |
| Cmd+Shift+D | Comparison mode |

## Project Structure

```
pdf_app1/pdf_app1/
  PDFViewerApp.swift              App entry point, environment injection
  MultiDocumentView.swift         Main UI: sidebar + split pane detail
  PDFViewerView.swift             PDF viewer + annotation engine
  DocumentManager.swift           Multi-tab document state
  ProjectsManager.swift           Project management + bookmarks
  Constants.swift                 App-wide enums and constants
  AppPreferences.swift            Settings (General, Display, AI)
  AppError.swift                  Error types, alerts, notifications
  ...                             (other existing files)

  Atlas/
    Models/
      ConceptTypes.swift          ConceptType, EdgeType, ReadingState, PaneMode enums
      KnowledgeGraph.swift        Core graph: ConceptNode, GraphEdge, SourceAnchor
    Persistence/
      GraphStore.swift            JSON persistence per document/project
      GraphMergeEngine.swift      Cross-document entity resolution
    AI/
      AtlasModelProtocol.swift    AI backend protocol (4 operations)
      PromptTemplates.swift       All LLM prompts
      AIServiceManager.swift      Backend selection, Keychain keys, caching
      ExtractionPipeline.swift    Full pipeline: pages -> concepts -> graph
      TextExtractor.swift         PDFKit text extraction with bounding boxes
      LayoutAnalyzer.swift        Heuristic block classifier (heading/body/etc)
      Backends/
        ClaudeBackend.swift       Anthropic Messages API
        OpenAIBackend.swift       OpenAI-compatible (also Ollama, LM Studio)
        GeminiBackend.swift       Google Gemini API
    Renderer/
      KnowledgeMapView.swift      Map panel with extraction trigger + controls
      MapCanvasRenderer.swift     SwiftUI Canvas graph renderer
      ForceDirectedLayout.swift   Fruchterman-Reingold layout algorithm
      MapInteraction.swift        Pan, zoom, click, drag interactions
      DensityManager.swift        Node collapse/expand by zoom level
    Sync/
      BidirectionalSyncManager.swift  PDF <-> map sync coordination
      ScrollTracker.swift              PDF page change monitoring
      HighlightSyncBridge.swift        Highlight/annotation <-> node bridging
    UI/
      SplitPaneContainer.swift    Two-pane resizable layout
      AISettingsView.swift        AI backend configuration
      CommandPaletteView.swift    Cmd+K fuzzy search overlay
      MapSearchView.swift         Map-specific concept search
      UnifiedSearchManager.swift  Context-aware search dispatcher
      ConceptDetailPopover.swift  Node detail: summary, sources, edges
      FirstRunView.swift          Onboarding experience
      MapToolbar.swift            Map pane toolbar (zoom, filter, export)
      MergeProposalView.swift     Accept/reject concept merge proposals
      ProjectCorrelationSidebar.swift  Enhanced project sidebar with stats
    Export/
      ExportManager.swift         Export to Obsidian, Markdown, JSON
```

## How It Works

1. **Text Extraction** — PDFKit extracts text with bounding-box coordinates per block
2. **Layout Analysis** — Heuristics classify blocks as headings, body, captions, footnotes, equations
3. **AI Concept Extraction** — Text (with +/- 2 pages context) is sent to the configured LLM, which returns concepts with exact source quotes
4. **Source Anchoring** — Each concept's text span is mapped back to a PDF bounding box. Concepts without valid anchors are rejected (hallucination mitigation)
5. **Edge Proposal** — The LLM proposes typed relationships between concepts (depends-on, defines, contradicts, etc.)
6. **Graph Rendering** — A force-directed layout (Fruchterman-Reingold) positions nodes, rendered via SwiftUI Canvas with frustum culling and level-of-detail
7. **Bidirectional Sync** — Scroll events update the active node; node clicks navigate the PDF with an 800ms pulse animation

## Data & Privacy

- **Local-first** — All graphs, annotations, and settings are stored on your Mac
- **API keys in Keychain** — Never stored in plain text or UserDefaults
- **Minimal data sent** — Only the text of pages being analyzed is sent to the AI provider (typically 5-page batches)
- **No Atlas cloud** — There is no server component. Your documents stay on your machine

## License

[Add your license here]

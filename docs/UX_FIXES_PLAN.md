# UX Dealbreaker Fixes — Implementation Plan

**Created:** 2026-04-27
**Status:** Planned, not yet implemented

These are the issues that would make a student uninstall Atlas after their first session. Each is mapped to exact code locations with the fix approach.

---

## 1. Alert System is Dead Code (CRITICAL)

**The bug:** `CompactAlertView` (AppError.swift:120-187) and `AlertManager` (AppError.swift:86-108) exist but are never rendered. The overlay is missing from `MultiDocumentView`. Every error — including "file access denied" and "corrupted PDF" — shows as a 3-second auto-dismissing toast that vanishes before users can read it.

**Where:**
- `MultiDocumentView.swift:258` — `AlertManager` is created as `@StateObject`
- `MultiDocumentView.swift:326` — injected via `.environmentObject(alertManager)`
- `MultiDocumentView.swift:300` — **missing**: no `.overlay` renders `CompactAlertView`

**Fix:**
1. Add an `.overlay` block at `MultiDocumentView.swift:300` (after toast overlay, before command palette overlay) that renders `CompactAlertView` when `alertManager.alertItem` is non-nil
2. Add a `severity` property to `AppError` — `.modal` for file/PDF errors, `.toast` for save/annotation errors
3. Add a `routeError()` helper that sends modal-severity errors to `alertManager` and toast-severity to `notificationManager`

**Effort:** Small (~20-30 lines across 2 files)

---

## 2. Recent Files Silently Disappear (CRITICAL)

**The bug:** When bookmarks go stale or files are moved/deleted, they're silently removed from the recent files list. The `inaccessibleFiles` property is published but never consumed by UI. When `openDocument` fails, the `Bool` return is ignored.

**Where:**
- `RecentFilesManager.swift:42` — `inaccessibleFiles` published but unused
- `RecentFilesManager.swift:148-157` — background file existence check auto-removes missing files
- `MultiDocumentView.swift:677` — `documentManager.openDocument(url)` return value ignored
- `DocumentManager.swift:63-80` — returns `Bool` with no failure reason

**Fix:**
1. **RecentFilesManager.swift** — Stop auto-removing inaccessible files. Instead, populate `inaccessibleFiles` with their indices so the UI can show them dimmed.
2. **DocumentManager.swift** — Change `openDocument` return from `Bool` to an enum (`OpenResult`: `.success`, `.alreadyOpen`, `.tooManyTabs`, `.fileNotReadable`, `.invalidPDF`). Keep `@discardableResult`.
3. **MultiDocumentView.swift:654-678** — In the recent files `ForEach`:
   - Check `inaccessibleFiles.contains(index)` per row
   - Dim inaccessible files (`.opacity(0.5)`), swap icon to warning triangle, add "File not accessible" subtitle
   - On tap failure: show modal alert (from fix #1) with "Remove from Recents" option
   - Add `.contextMenu` with "Remove from Recents" on all items

**Effort:** Medium (~80-120 lines across 3 files)

---

## 3. No Extraction Progress or Cancel (MEDIUM)

**The bug:** AI extraction shows only a small spinner + batch-level text ("Analyzing pages 1-5..."). No progress bar, no page fraction, no cancel button. The pipeline has `currentPage` and `totalPages` state but they aren't surfaced visually. No way to abort a long-running extraction (180s HTTP timeout per batch).

**Where:**
- `ExtractionPipeline.swift:18-21` — has `currentPage`, `totalPages` but no `progress` or `isCancelled`
- `ExtractionPipeline.swift:61` — `while` loop has no cancellation check
- `KnowledgeMapView.swift:374-384` — `processingIndicator` is just `ProgressView() + Text(statusMessage)`
- `KnowledgeMapView.swift:238` — analyze button disabled during processing but no cancel alternative

**Fix:**
1. **ExtractionPipeline.swift** — Add:
   - `var isCancelled: Bool = false` + `func cancel()` method
   - `var progress: Double` computed from `currentPage / totalPages`
   - Cancellation check at top of `while` loop (line 61)
   - Update `statusMessage` to include total: `"Analyzing pages X-Y of Z..."`
2. **KnowledgeMapView.swift:374-384** — Replace `processingIndicator` with:
   - Linear `ProgressView(value: pipeline.progress)` (200pt wide)
   - Page counter: `"5/25 pages"` with `.monospacedDigit()`
   - Cancel button (`.bordered`, `.controlSize(.small)`)
   - 360pt wide material-background card

**Effort:** Small-medium (~50-70 lines across 2 files)

---

## 4. Scanned PDFs Silently Produce Nothing (MEDIUM)

**The bug:** `TextExtractor` uses `page.string` which returns empty for scanned/image-only PDFs. The pipeline detects this (`totalChars == 0`) but silently returns with only a console log. User sees "Done — 0 concepts extracted" with no explanation of why.

**Where:**
- `TextExtractor.swift:58-66` — relies on `page.string` (nil for scanned PDFs)
- `ExtractionPipeline.swift:134-137` — `if totalChars == 0 { return }` with only a `log.warning`
- No Vision framework import anywhere in the codebase

### Phase 4a: Detection + Messaging

**Fix:**
1. **ExtractionPipeline.swift** — Add `var scannedPDFDetected: Bool = false`. In the `totalChars == 0` block, set flag and update `statusMessage` to explain. Also detect low-density text (< 50 chars/page) as "possibly scanned."
2. **KnowledgeMapView.swift** — When `scannedPDFDetected && nodeCount == 0`, show banner explaining the PDF appears scanned, with "Run OCR" button.

**Effort:** Small (~30 lines)

### Phase 4b: Vision OCR Fallback

**Fix:**
1. **TextExtractor.swift** — Add `import Vision`. New async method:
   - Render PDF page to CGImage at 300 DPI via `NSGraphicsContext`
   - Run `VNRecognizeTextRequest` with `.accurate` level + language correction
   - Convert `VNRecognizedTextObservation` bounding boxes (normalized 0-1) to PDF page coordinates
   - Per-page: try embedded text first, fall back to OCR
2. **ExtractionPipeline.swift:134-137** — Instead of returning, invoke OCR fallback. If OCR also yields nothing, then set `scannedPDFDetected = true`.

**Note:** Vision.framework is a system framework — no entitlement changes needed.

**Effort:** Medium-large (~100-150 lines)

---

## Design Decisions (from grilling session, 2026-04-27)

| Decision | Original | Revised |
|----------|----------|---------|
| Alert z-order | Before command palette overlay | **After** command palette; alert auto-dismisses palette |
| Error callsite migration | New code only | **Migrate existing** `showError` callsites (~9 in PDFViewerView.swift) |
| `OpenResult` enum | Not specified | **Plain cases** (no associated values) |
| Stale recent files | Keep dimmed forever | **Notify then auto-remove after 3 launches** (needs per-entry launch counter in UserDefaults) |
| Cancel semantics | Check `isCancelled` flag between batches | **Cancel in-flight HTTP request** via `Task.cancel()` — immediate cancellation |
| OCR memory | Render all pages at 300 DPI | **One page at a time** — render → OCR → release CGImage before next page |
| Scanned PDF threshold | < 50 chars/page | **< 10 chars/page** for low-density; zero text triggers auto-OCR |
| OCR trigger | User clicks "Run OCR" button | **Auto-run OCR** when totalChars == 0, with cancel option. Banner only if OCR also fails |
| Implementation order | 5 sequential steps | **Two PRs** (see below) |

### Key implementation notes from decisions:

1. **Alert overlay must go AFTER command palette overlay** (not before as originally planned). When alert fires, set `showCommandPalette = false` to prevent dual-scrim stacking.

2. **Task-based cancellation** requires storing `private var processingTask: Task<Void, Never>?` on `ExtractionPipeline`. `cancel()` calls `processingTask?.cancel()`. In `processBatch`'s catch block, check for `CancellationError` and break cleanly with "Cancelled — X concepts extracted" status instead of showing an error.

3. **Stale file launch counter** needs a `[URL: Int]` dictionary persisted in UserDefaults. Increment on each `loadRecentFiles()` call. When count reaches 3 and file is still stale, auto-remove and show toast: "N missing files removed from Recents".

4. **OCR auto-runs** for zero-text PDFs. Phases 4a/4b merge for this path — no "Run OCR" button needed. The banner with "Run OCR" is only shown for low-density text (< 10 chars/page) where it's ambiguous.

---

## Implementation Order

### PR1: Viewer UX (Alerts + Recent Files)

| Step | What | Files | Depends on |
|------|------|-------|------------|
| 1 | Wire up alert overlay + migrate callsites | MultiDocumentView.swift, AppError.swift, PDFViewerView.swift | — |
| 2 | Recent files UX + stale launch counter | RecentFilesManager.swift, DocumentManager.swift, MultiDocumentView.swift | Step 1 |

### PR2: Extraction UX (Progress + OCR)

| Step | What | Files | Depends on |
|------|------|-------|------------|
| 3 | Extraction progress + Task-based cancel | ExtractionPipeline.swift, KnowledgeMapView.swift | — |
| 4 | Scanned PDF detection + auto-OCR fallback | TextExtractor.swift, ExtractionPipeline.swift, KnowledgeMapView.swift | Step 3 |

PR1 and PR2 have no file overlap and can be developed in parallel.

## Verification Checklist

### PR1: Viewer UX
- [ ] Open corrupted PDF -> modal alert (not toast). Esc dismisses.
- [ ] Open valid PDF -> no alert, no toast.
- [ ] Trigger alert while command palette is open -> palette dismissed, alert shown.
- [ ] "Cannot save: read-only" -> still a toast (not modal). Save errors stay as toasts.
- [ ] Open PDF, quit, move PDF to Trash, relaunch -> file shows dimmed with warning icon.
- [ ] Click inaccessible file -> modal alert with "Remove from Recents".
- [ ] Right-click any recent file -> context menu with remove option.
- [ ] Stale file persists through 3 launches -> auto-removed, toast says "N missing files removed from Recents".

### PR2: Extraction UX
- [ ] Analyze 20+ page PDF -> progress bar fills, page counter updates (e.g., "10/25 pages"), cancel button visible.
- [ ] Click cancel mid-batch -> extraction stops immediately (not after batch finishes), shows "Cancelled — X concepts extracted".
- [ ] Open image-only PDF, Analyze -> OCR auto-runs, status says "No embedded text — running OCR...", concepts extracted.
- [ ] Open PDF with very sparse text (< 10 chars/page avg) -> banner explains "possibly scanned", offers "Run OCR" button.
- [ ] OCR on 25-page scanned PDF -> memory stays reasonable (< 100MB spike), pages processed sequentially.

### Both PRs
- [ ] Build succeeds: `xcodebuild -project pdf_app1.xcodeproj -scheme pdf_app1 -configuration Debug build`

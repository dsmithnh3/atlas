# Backlog

Durable "someday/maybe" items — distinct from session-level Unresolved (which is "next session"). Each entry: one-line item specific enough to act on cold, optional priority, **Why:** if non-obvious.

<!-- from: docs/STATUS.md (What's Next, as of 2026-04-29) -->
<!-- from: docs/TODO.md (unchecked items, as of 2026-05-04) -->

## Bugs

(no open bugs — `.document` summary node implementation landed 2026-05-08, pending test verification; see active items below)

<!-- Fixed 2026-05-07 (on wip/feature-cherry-pick, not yet committed):
  - Shared in-memory graph leaks across documents → MultiDocumentView.loadGraphIfNeeded clears when no saved graph
  - deleteProject doesn't clean up → ProjectsManager.deleteProject deletes per-doc + project graphs; call site closes open tabs
  - Two analyze paths use different modes → MultiDocumentView now reads @AppStorage selectedMode and passes to processFullDocument
  - GraphStore URL-only cache key (content invalidation) → StoredGraph wrapper stamps mtime+size; load invalidates on mismatch
  - hierarchyLevel decode default wrong for concept nodes → KnowledgeGraph.swift:109 now defaults based on level
-->
<!-- Fixed 2026-05-08 (on wip/feature-cherry-pick):
  - JSONRepair double-bracket on truncated edges array → JSONRepair.swift tracks closedArray; targeted test passes (commit 3a0f813)
  - .document zoom = picked-node not summary → ConceptNode gains isDocumentSummary; ExtractionPipeline.appendDocumentSummary helper called from both fast and deep pipelines; DensityManager prefers summary node (uncommitted, build green, tests blocked by testmanagerd hang)
-->

## Active / Next (2026-05-08)

- `[active 2026-05-08]` Run XCTest after the testmanagerd wedge clears (Xcode restart). Verify: (a) `test_jsonRepair_closesUnclosedNovakResponse` passes; (b) `ConceptNode` Codable round-trips with the new `isDocumentSummary` field, including legacy decode (no field present → `false`); (c) no other regressions vs the 23:50ish baseline (1 known failure that's now fixed).
- `[active 2026-05-08]` Commit `.document` summary node implementation (4 files: `KnowledgeGraph.swift`, `ExtractionPipeline.swift`, `DeepExtractionPipeline.swift`, `DensityManager.swift`). Standalone commit per user preference — pending test verification before commit.
- `[next]` Commit doc-migration carryover (7 deletions + untracked scaffolding `audits/`, `prds/`, `misc/`, `test_findings/`, `backlog.md`, `decisions.md`, `glossary.md` + `pdf_app1/scripts/` rename targets) as its own commit. Re-stage with `git add -u && git add audits prds misc test_findings backlog.md decisions.md glossary.md pdf_app1/scripts`.
- `[next]` Resolve pre-merge `STATUS.md` conflict in commit `853cbba` — conflicts with the doc-deletion at merge time.
- Optionally swap `summarizeConcept` for `generateRawResponse` + custom doc-summary prompt if "Summarize the concept '<filename>'" wording produces awkward output once a real run happens. Low priority; only if observed.

## Annotations
- Annotation move/resize — drag handles UX (TODO #13). **Priority:** medium-high.
- Verify annotation coordinate conversion accuracy; use PDFKit built-in conversion methods consistently; fix Y-coordinate inversion if needed; dynamic annotation sizing based on content; coordinate-conversion tests; thorough bounds validation (TODO #9).
- Annotation state persistence between sessions; fix `currentHighlight` sync; improve state management patterns; state validation (TODO #10).

## Dark mode
- Dark mode end-to-end appearance validation: test, optimize colors, ensure readability (TODO #13).

## Performance & profiling
- Run Instruments (Time Profiler + Allocations) on large PDFs and address hotspots (TODO #11; Final Review 2026-01-16).
- Add memory leak detection in tests (TODO #5).

## Recent files
- Test recent files persistence across app restarts and system reboots (TODO #2).
<!-- Removed 2026-05-07: stale-bookmark refresh persistence — already implemented in RecentFilesManager.swift:151-184 (likely via commit 7e1c605). -->


## Window state
- Test default fullscreen on different screen sizes (TODO #3).
- Consider user preference for window state (windowed vs fullscreen) (TODO #3).

## updateNSView
- Test state synchronization for updateNSView (TODO #8).

## Tests / CI
- Wire tests into Xcode: create Unit Test target, add `pdf_app1Tests/*.swift` sources (TODO #16; Final Review). **Priority:** high — test files exist but can't run via `xcodebuild test` until scheme is configured.
- Set up CI/CD with test automation (TODO #16).
- Aim for >80% code coverage (TODO #16).

## Documentation
- Document all extracted constants (TODO #6).
- Code documentation: comments for complex logic, public-API docs, architecture doc, coordinate-conversion logic, annotation system, state management patterns (TODO #7).
- Create developer guide (TODO #7).

## UX research / accessibility
- Research standard PDF viewer UI patterns (Preview.app, Adobe Reader); document best practices (TODO #12).
- Test with accessibility tools (TODO #12).

## Export & sync (future)
- Export annotations: separate file / text / markdown / share (TODO #15). **Priority:** low.
- Cloud sync integration: iCloud, other providers, sync annotations across devices (TODO #15). **Priority:** low.
- Advanced annotation tools: shapes (rectangle, circle, arrow), freehand drawing, stamps, more types (TODO #15). **Priority:** low.

## Project-level search V2
<!-- from: docs/TODO.md #18 -->
- Project-level search bar: searches across PDFs within selected project. **Priority:** medium.
  - UX: scope = selected project (default); group results by file then page; click result opens file + scrolls to page + highlights match.
  - Perf: async + cancellable (typing cancels prior search); progressive/streamed results; hard cap per file and total; avoid re-indexing unchanged PDFs (cache by mtime).
  - Data model: persist per-project search history; persist per-file index metadata (hash/mtime/pages).
  - Implementation: extend `PDFSearchManager` to multi-document; per-file tasks with cooperative cancellation; in-memory index cache for current project session; optional background "index warmup" on project open.
  - Polish: per-file "Searching…" indicator; show skipped (inaccessible/missing) files; "Stop" button.

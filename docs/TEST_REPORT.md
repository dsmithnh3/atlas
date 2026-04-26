# Test Report

## Summary
- Added test strategy and a reusable XCTest suite scaffold.
- Verified app builds after bug fixes and testability refactors.

## Bug Fix Verification (Implementation)
- Multi-select PDFs during project creation: switched selection to `NSOpenPanel` with `allowsMultipleSelection = true`.
- Duplicate project names: enforced case-insensitive uniqueness with automatic suffixing `(<n>)` on create and rename.
- Highlights/annotations persistence:
  - Enabled read-write user-selected file entitlement.
  - Bookmarks now created read-write (not read-only).
  - Added debounced autosave on annotation changes (silent) + manual Save remains explicit.

## Automated Tests Added (Ready to Run)
- `ProjectsManagerTests`
  - Unique naming behavior
  - Persistence to disk via injected storage URL
- `RecentFilesManagerTests`
  - Add/dedupe behavior via injected UserDefaults + bookmarker
- `UndoRedoManagerTests`
  - Basic undo/redo stack behavior
- `PDFPersistenceIntegrationTests`
  - Add highlight -> save -> reload -> highlight exists

## How to Run
- Create a Unit Test target (Xcode UI step) and add `pdf_app1Tests/*.swift` to it.
- Then run with `⌘U`.

## Notes
- Integration test validates PDFKit write/read behavior in a temp directory.
- Sandbox/security-scoped access is handled in-app via entitlements + bookmarks; unit tests avoid sandbox APIs via injection.

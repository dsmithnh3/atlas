# TODO - PDF Viewer App Improvements

## 🔴 Critical Issues (Specific Problems)

### 1. Notification/Alert UX Improvement
**Problem:** Warnings and errors look ugly, span the entire screen, and cannot be dismissed. Poor user experience.

**Tasks:**
- [x] Redesign notification system to be less intrusive
  - [x] Make notifications smaller and positioned better (e.g., top-right corner)
  - [x] Add dismiss button (X) to all notifications
  - [x] Add swipe-to-dismiss gesture
  - [x] Limit notification width (don't span full screen)
  - [x] Add subtle shadow/border for better visual separation
  - [x] Consider using a notification stack for multiple notifications
- [x] Improve alert dialogs
  - [x] Make alerts more compact and visually appealing
  - [x] Ensure proper sizing (not full screen)
  - [x] Add better visual hierarchy
- [x] Test notification dismissal and interaction
- [x] Ensure notifications don't block important UI elements

**Priority:** HIGH - Affects user experience significantly

---

### 2. Recent Files Persistence Across Sessions
**Problem:** Recent files don't work across sessions - shows files as not accessible.

**Tasks:**
- [x] Fix security-scoped resource handling for recent files
  - [x] Implement security-scoped bookmark storage instead of URLs
  - [x] Store bookmarks in UserDefaults or secure storage
  - [x] Restore bookmarks on app launch
  - [x] Handle bookmark resolution failures gracefully
  - [x] Add bookmark refresh mechanism
- [x] Update `RecentFilesManager` to use bookmarks
  - [x] Convert URLs to bookmarks before saving
  - [x] Resolve bookmarks to URLs when loading
  - [x] Handle stale/invalid bookmarks
- [x] Add error handling for inaccessible files
  - [x] Show user-friendly message when file is no longer accessible
  - [x] Option to remove inaccessible files from recent list
- [ ] Test across app restarts and system reboots

**Priority:** HIGH - Core functionality broken

---

### 3. Default Window Size - Fullscreen
**Problem:** Application opens as a small window. Should open fullscreen by default.

**Tasks:**
- [x] Configure default window state in `PDFViewerApp.swift`
  - [x] Set window to fullscreen or maximized state on launch
  - [x] Use `NSWindow` configuration for macOS
  - [x] Set appropriate minimum window size
  - [x] Remember window state (fullscreen/windowed) preference
- [x] Update window frame settings
  - [x] Remove or adjust `minWidth` and `minHeight` constraints if needed
  - [x] Set initial frame to screen size
- [ ] Test on different screen sizes
- [ ] Consider user preference for window state

**Priority:** MEDIUM - UX improvement

---

## 🟠 Code Quality & Technical Debt

### 4. Remove Commented-Out Code
**Problem:** Large blocks of commented code in `PDFViewerView.swift` indicate unfinished features, debugging attempts, and technical debt.

**Tasks:**
- [x] Audit codebase for commented code blocks
- [x] Remove all commented-out code
- [x] Implement or delete commented features
- [x] Clean up debugging code remnants
- [x] Document any incomplete features in TODO instead of commenting

**Priority:** MEDIUM - Code maintainability

---

### 5. Fix Memory Leaks
**Problem:** NotificationCenter observers and gesture recognizers may not be properly cleaned up, causing memory leaks.

**Tasks:**
- [x] Ensure NotificationCenter observers are removed in `deinit`
- [x] Properly cleanup gesture recognizers
- [x] Use weak references where appropriate
- [ ] Add memory leak detection in tests
- [ ] Profile memory usage with Instruments
- [x] Verify no retain cycles in Coordinator classes

**Priority:** HIGH - Memory issues over time

---

### 6. Extract Magic Numbers and Hardcoded Values
**Problem:** Magic numbers (200, 40, 5, 20) and hardcoded values throughout codebase make it hard to maintain and configure.

**Tasks:**
- [x] Create a `Constants` or `Configuration` struct
- [x] Extract all magic numbers to named constants
  - [x] Annotation sizes (200x40 for text annotations)
  - [x] Minimum highlight size (5)
  - [x] Max recent files (20)
  - [x] Alpha values (0.3)
- [x] Make max recent files configurable
- [x] Make annotation sizes configurable
- [ ] Document all constants

**Priority:** LOW - Code quality improvement

---

### 7. Add Code Documentation
**Problem:** Missing code comments, API documentation, and architecture documentation.

**Tasks:**
- [ ] Add code comments explaining complex logic
- [ ] Document all public APIs
- [ ] Add architecture documentation
- [ ] Document coordinate conversion logic
- [ ] Add inline documentation for annotation system
- [ ] Document state management patterns
- [ ] Create developer guide

**Priority:** LOW - Documentation improvement

---

### 8. Complete updateNSView Implementation
**Problem:** `updateNSView` has incomplete implementation, cursor handling is a workaround, and document changes may not propagate correctly.

**Tasks:**
- [x] Complete `updateNSView` implementation in `PDFViewRepresentable`
- [x] Fix cursor handling (remove workaround)
- [x] Ensure document changes propagate correctly
- [x] Ensure annotation mode changes update properly
- [ ] Test state synchronization

**Priority:** MEDIUM - UI state synchronization

---

### 9. Improve Annotation Coordinate System
**Problem:** Manual coordinate conversion may be inaccurate, fixed annotation sizes, and potential Y-coordinate inversion issues.

**Tasks:**
- [ ] Verify coordinate conversion accuracy
- [ ] Use PDFKit's built-in conversion methods consistently
- [ ] Implement dynamic annotation sizing based on content
- [ ] Fix Y-coordinate inversion if needed
- [ ] Add comprehensive coordinate conversion tests
- [ ] Validate annotation bounds more thoroughly

**Priority:** MEDIUM - Annotation placement accuracy

---

### 10. Improve State Management
**Problem:** `currentHighlight` in Coordinator may not sync properly, no undo/redo state tracking, annotation state not persisted.

**Tasks:**
- [ ] Fix `currentHighlight` synchronization issues
- [x] Implement undo/redo state tracking
- [ ] Add annotation state persistence between sessions
- [ ] Improve state management patterns
- [ ] Add state validation

**Priority:** MEDIUM - Feature completeness

---

## 🟡 Performance & Code Optimization

### 11. Performance Optimization
**Goal:** Optimize for performance above all else. Use simplest and least processing UI elements.

**Tasks:**
- [x] Audit UI components for performance
  - [x] Replace heavy SwiftUI views with lighter alternatives where possible
  - [x] Use `LazyVStack`/`LazyHStack` for large lists
  - [x] Minimize view updates and re-renders
  - [x] Use `@State` efficiently (avoid unnecessary state changes)
- [x] Optimize PDF rendering
  - [x] Implement lazy loading for PDF pages
  - [x] Cache rendered pages
  - [x] Reduce PDF view updates
  - [x] Optimize annotation rendering
- [x] Optimize recent files list
  - [x] Lazy load file metadata
  - [x] Cache file icons/thumbnails
  - [x] Debounce file system checks
- [x] Profile app performance
  - [x] Use Instruments to identify bottlenecks
  - [x] Optimize memory usage
  - [x] Reduce CPU usage during interactions
- [x] Simplify UI elements
  - [x] Remove unnecessary animations
  - [x] Use native controls where possible
  - [x] Minimize custom view modifiers
  - [x] Reduce view hierarchy depth

**Priority:** MEDIUM - Performance improvement

---

## 🟢 UI/UX Design Improvements

### 12. Intuitive UI Design for PDF Viewer Workflow
**Goal:** Follow the most intuitive UI design for PDF viewer applications.

**Tasks:**
- [ ] Research standard PDF viewer UI patterns
  - [ ] Study Preview.app, Adobe Reader, etc.
  - [ ] Identify common workflows and patterns
  - [ ] Document best practices
- [x] Improve navigation
  - [x] Add thumbnail sidebar for page navigation
  - [x] Improve page navigation controls
  - [x] Add page number input field
  - [x] Add keyboard shortcuts for navigation
- [x] Improve annotation workflow
  - [x] Make annotation tools more accessible
  - [x] Add annotation toolbar
  - [x] Show annotation mode indicator
  - [x] Improve annotation selection/editing
- [x] Improve file management
  - [x] Better recent files presentation
  - [x] Add file search/filter
  - [x] Add drag-and-drop support
  - [x] Show file metadata (size, date, etc.)
- [x] Improve toolbar
  - [x] Organize tools logically
  - [x] Add tooltips/help text
  - [x] Group related actions
  - [x] Add keyboard shortcuts display
- [x] Improve empty states
  - [x] Better "no PDF selected" state
  - [x] Better "no recent files" state
  - [x] Add helpful hints/instructions
- [ ] Accessibility improvements
  - [x] Add VoiceOver support
  - [x] Ensure keyboard navigation
  - [x] Add high contrast mode support
  - [ ] Test with accessibility tools

**Priority:** MEDIUM - UX enhancement

---

### 13. Missing Core Features
**Problem:** Several standard PDF viewer features are missing, limiting app functionality.

**Tasks:**
- [x] Add search functionality within PDFs
  - [x] Text search with highlighting
  - [x] Search results navigation
  - [x] Search history
- [x] Add bookmark/favorites system
  - [x] Save page bookmarks
  - [x] Quick navigation to bookmarks
  - [x] Bookmark management
- [ ] Add annotation editing/deletion
  - [x] Select and edit existing annotations
  - [x] Delete annotations
  - [ ] Move/resize annotations
- [x] Add undo/redo for annotations
  - [x] Undo/redo stack
  - [x] Keyboard shortcuts (Cmd+Z, Cmd+Shift+Z)
  - [x] Visual feedback
- [x] Add print functionality
  - [x] Print dialog integration
  - [x] Print preview
  - [x] Print options (pages, scale, etc.)
- [x] Add full-screen mode
  - [x] Toggle full-screen (Cmd+Ctrl+F)
  - [x] Hide/show toolbar in full-screen
  - [x] Exit full-screen gracefully
- [x] Add thumbnail navigation sidebar
  - [x] Page thumbnails
  - [x] Thumbnail navigation
  - [x] Current page indicator
- [ ] Add dark mode optimization
  - [ ] Test dark mode appearance
  - [ ] Optimize colors for dark mode
  - [ ] Ensure readability

**Priority:** MEDIUM - Feature completeness

---

### 14. Multi-Document Support
**Problem:** App only supports one document at a time, limiting workflow.

**Tasks:**
- [x] Add multi-file tabs/windows support
  - [x] Tab bar for multiple documents
  - [x] Window management
  - [x] Document switching
- [x] Add drag-and-drop file opening
  - [x] Drag files onto app
  - [x] Drag files onto window
  - [x] Multiple file support
- [x] Add document comparison view
  - [x] Side-by-side viewing
  - [x] Split view options

**Priority:** LOW - Future enhancement
**Status:** ✅ COMPLETED (2026-01-22)

---

### 15. Export and Advanced Features
**Problem:** Limited export and advanced annotation capabilities.

**Tasks:**
- [ ] Add export annotations feature
  - [ ] Export annotations to separate file
  - [ ] Export as text/markdown
  - [ ] Share annotations
- [ ] Add cloud sync integration
  - [ ] iCloud sync
  - [ ] Other cloud providers
  - [ ] Sync annotations across devices
- [ ] Add advanced annotation tools
  - [ ] Shapes (rectangle, circle, arrow)
  - [ ] Freehand drawing
  - [ ] Stamps
  - [ ] More annotation types

**Priority:** LOW - Future enhancement

---

## 🧪 Testing & Quality Assurance

### 16. Add Unit Tests
**Problem:** Zero test coverage - no tests exist for critical functionality.

**Tasks:**
- [x] Add test strategy + report docs
  - [x] `docs/TEST_STRATEGY.md`
  - [x] `docs/TEST_REPORT.md`
- [x] Add unit tests for `RecentFilesManager`
  - [x] Test file addition/removal + de-dupe ordering
  - [x] Test persistence (via injected `UserDefaults` suite)
  - [x] Test bookmark handling (via injected bookmarker)
- [x] Add unit tests for `ProjectsManager`
  - [x] Test duplicate-name prevention (case-insensitive)
  - [x] Test persistence (via injected storage URL)
- [x] Add unit tests for `UndoRedoManager`
  - [x] Test undo/redo stack behavior
- [x] Add unit tests for `PDFSearchManager`
  - [x] Test search history trim + case-insensitive de-dupe
  - [x] Test clear-history
- [x] Add integration tests
  - [x] Test annotation persistence: highlight -> save -> reload
- [ ] Wire tests into Xcode (create Unit Test target and add sources)
- [ ] Set up CI/CD with test automation
- [ ] Aim for >80% code coverage

**Priority:** MEDIUM - Quality assurance

---

## 🆕 Fresh Change Request

### 17. Text-Selection-Based Highlighting (Replace Rectangle Drag)
**Problem:** Current highlight UX requires drawing a box/rectangle over content. This is not how users highlight in most PDF viewers; most highlights are text-based.

**Tasks:**
- [x] Switch highlight workflow to text selection (click-drag to select text, then highlight selection)
- [x] Convert `PDFSelection` to highlight annotations using selection geometry (not a single bounding box)
- [x] Support multi-line selections cleanly (e.g. per-line highlights)
- [x] Keep rectangle/area highlight only as an optional “shape highlight” mode (not the default)
- [x] Ensure this works with scanned PDFs (no text layer) by gracefully falling back (either disable or offer rectangle highlight)

**Priority:** HIGH - Core annotation UX

---

### 18. Projects (Project Explorer) + V2 Project-level Search
**Problem:** Users want a file-explorer style start screen with persistent projects (groups of PDFs). Projects should be easy to manage and fast.

**V1 (Now) - Project Explorer:**
- [x] Project Explorer launch screen (always shown on app start)
  - [x] Create project (multi-select PDFs on creation)
  - [x] Rename project
  - [x] Delete project (do not delete underlying files)
  - [x] Add PDFs to project later (multi-select)
  - [x] Remove PDFs from project
  - [x] Allow the same PDF to belong to multiple projects
  - [x] Manual ordering + sort ordering for:
    - [x] Projects list
    - [x] PDFs within a project
  - [x] Persist projects using security-scoped bookmarks (reliable across restarts)
  - [x] Nice empty states + keyboard accessibility

**V2 - Project-level Search (NOT IMPLEMENTED YET):**
- [ ] Add a project-level search bar that searches across PDFs within the selected project
  - [ ] Define UX:
    - [ ] Search scope: selected project only (default)
    - [ ] Result grouping: by file, then by page
    - [ ] Click result opens file + scrolls to page + highlights match
  - [ ] Performance requirements:
    - [ ] Search is async + cancellable (typing should cancel prior search)
    - [ ] Progressive results (stream partial results to UI)
    - [ ] Hard cap results per file and total results
    - [ ] Avoid re-indexing unchanged PDFs (cache by file modified time)
  - [ ] Data model:
    - [ ] Persist per-project search history
    - [ ] Persist per-file indexing metadata (hash/mtime/pages)
  - [ ] Implementation plan:
    - [ ] Reuse/extend `PDFSearchManager` to support multi-document search
    - [ ] Concurrency: per-file tasks with cooperative cancellation
    - [ ] Maintain an in-memory search index cache for current project session
    - [ ] Optional: background “index warmup” when project opens (low priority)
  - [ ] UX polish:
    - [ ] "Searching…" indicator per file
    - [ ] Show which files were skipped (inaccessible / missing)
    - [ ] Provide “Stop” button

**Priority:** HIGH (Projects V1), MEDIUM (Project search V2)

---

## 📝 Implementation Notes

### Notification System Redesign
- Consider using a bottom-right or top-right corner placement
- Use a fixed width (e.g., 300-400px) instead of full width
- Add smooth animations for show/hide
- Implement a notification queue system
- Consider using a third-party library if needed (but prefer native)

### Security-Scoped Bookmarks
- Use `NSURL.bookmarkData(options:includingResourceValuesForKeys:relativeTo:)` to create bookmarks
- Use `NSURL(byResolvingBookmarkData:options:relativeTo:bookmarkDataIsStale:)` to resolve
- Store bookmark data as `Data` in UserDefaults
- Handle `bookmarkDataIsStale` flag appropriately

### Window Configuration
- Use `NSWindow` delegate methods or SwiftUI window modifiers
- Consider using `NSWindowController` for more control
- May need to use AppKit directly for fullscreen control

### Performance Optimization
- Focus on reducing view updates
- Use `@State` and `@Binding` efficiently
- Consider using `@StateObject` vs `@ObservedObject` appropriately
- Profile before and after changes

---

## 🎯 Priority Order

### Critical (Fix Immediately)
1. **Notification UX** (Critical - affects every user interaction)
2. **Recent Files Persistence** (Critical - core feature broken)
3. **Memory Leaks** (High - memory issues over time)

### High Priority (Fix Soon)
4. **Default Fullscreen** (Medium - UX improvement)
5. **Remove Commented Code** (Medium - code maintainability)
6. **Complete updateNSView** (Medium - UI state synchronization)
7. **Annotation Coordinate System** (Medium - annotation accuracy)
8. **State Management** (Medium - feature completeness)

### Medium Priority (Fix When Possible)
9. **Performance Optimization** (Medium - ongoing)
10. **UI Design Improvements** (Medium - iterative)
11. **Missing Core Features** (Medium - feature completeness)
12. **Add Unit Tests** (Medium - quality assurance)

### Low Priority (Future Enhancements)
13. **Extract Magic Numbers** (Low - code quality)
14. **Add Documentation** (Low - documentation)
15. **Export and Advanced Features** (Low - future enhancement)
16. ~~Multi-Document Support~~ (✅ COMPLETED)

---

## ✅ Completion Criteria

### Critical Features
- [x] All notifications are dismissible and visually appealing
- [x] Recent files persist and work across app sessions
- [ ] No memory leaks detected
- [x] All commented code removed or implemented

### Core Functionality
- [x] App opens in fullscreen/maximized state by default
- [ ] Annotation coordinate system works accurately
- [ ] State management is robust and synchronized
- [x] updateNSView implementation is complete

### Quality & Performance
- [ ] App performance is smooth with no lag
- [ ] Unit tests cover critical functionality (>80% coverage)
- [x] All magic numbers extracted to constants
- [ ] Code is well-documented

### User Experience
- [ ] UI follows intuitive PDF viewer patterns
- [ ] All features are accessible and user-friendly
- [ ] Core missing features implemented (search, undo/redo, etc.)
- [ ] Dark mode optimized

---

*Last Updated: 2026-01-22*
*Status: Multi-Document Support Implemented*

---

## 🔍 Final Review Notes (2026-01-16)

### What’s solid
- Core reader workflow (open, navigate, zoom, search, bookmarks, thumbnails)
- Text-selection highlight default + area highlight fallback
- Notifications/toasts + compact alerts
- Recent files persistence via security-scoped bookmarks

### Remaining actionable work
- [ ] Create an Xcode **test target** and add baseline unit tests (RecentFilesManager, UndoRedo, selection highlight)
- [ ] Implement **annotation move/resize** UX (handles/drag)
- [ ] Validate and tune **dark mode** appearance end-to-end
- [ ] Run **Instruments** (Time Profiler + Allocations) on large PDFs and address any hotspots
- [ ] RecentFilesManager stale bookmark refresh currently doesn’t write refreshed bookmark data back to storage (needs a small follow-up)

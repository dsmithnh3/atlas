# TODO - PDF Viewer App Improvements

## 🔴 Critical Issues (Specific Problems)

### 1. Notification/Alert UX Improvement
**Problem:** Warnings and errors look ugly, span the entire screen, and cannot be dismissed. Poor user experience.

**Tasks:**
- [ ] Redesign notification system to be less intrusive
  - [ ] Make notifications smaller and positioned better (e.g., top-right corner)
  - [ ] Add dismiss button (X) to all notifications
  - [ ] Add swipe-to-dismiss gesture
  - [ ] Limit notification width (don't span full screen)
  - [ ] Add subtle shadow/border for better visual separation
  - [ ] Consider using a notification stack for multiple notifications
- [ ] Improve alert dialogs
  - [ ] Make alerts more compact and visually appealing
  - [ ] Ensure proper sizing (not full screen)
  - [ ] Add better visual hierarchy
- [ ] Test notification dismissal and interaction
- [ ] Ensure notifications don't block important UI elements

**Priority:** HIGH - Affects user experience significantly

---

### 2. Recent Files Persistence Across Sessions
**Problem:** Recent files don't work across sessions - shows files as not accessible.

**Tasks:**
- [ ] Fix security-scoped resource handling for recent files
  - [ ] Implement security-scoped bookmark storage instead of URLs
  - [ ] Store bookmarks in UserDefaults or secure storage
  - [ ] Restore bookmarks on app launch
  - [ ] Handle bookmark resolution failures gracefully
  - [ ] Add bookmark refresh mechanism
- [ ] Update `RecentFilesManager` to use bookmarks
  - [ ] Convert URLs to bookmarks before saving
  - [ ] Resolve bookmarks to URLs when loading
  - [ ] Handle stale/invalid bookmarks
- [ ] Add error handling for inaccessible files
  - [ ] Show user-friendly message when file is no longer accessible
  - [ ] Option to remove inaccessible files from recent list
- [ ] Test across app restarts and system reboots

**Priority:** HIGH - Core functionality broken

---

### 3. Default Window Size - Fullscreen
**Problem:** Application opens as a small window. Should open fullscreen by default.

**Tasks:**
- [ ] Configure default window state in `PDFViewerApp.swift`
  - [ ] Set window to fullscreen or maximized state on launch
  - [ ] Use `NSWindow` configuration for macOS
  - [ ] Set appropriate minimum window size
  - [ ] Remember window state (fullscreen/windowed) preference
- [ ] Update window frame settings
  - [ ] Remove or adjust `minWidth` and `minHeight` constraints if needed
  - [ ] Set initial frame to screen size
- [ ] Test on different screen sizes
- [ ] Consider user preference for window state

**Priority:** MEDIUM - UX improvement

---

## 🟠 Code Quality & Technical Debt

### 4. Remove Commented-Out Code
**Problem:** Large blocks of commented code in `PDFViewerView.swift` indicate unfinished features, debugging attempts, and technical debt.

**Tasks:**
- [ ] Audit codebase for commented code blocks
- [ ] Remove all commented-out code
- [ ] Implement or delete commented features
- [ ] Clean up debugging code remnants
- [ ] Document any incomplete features in TODO instead of commenting

**Priority:** MEDIUM - Code maintainability

---

### 5. Fix Memory Leaks
**Problem:** NotificationCenter observers and gesture recognizers may not be properly cleaned up, causing memory leaks.

**Tasks:**
- [ ] Ensure NotificationCenter observers are removed in `deinit`
- [ ] Properly cleanup gesture recognizers
- [ ] Use weak references where appropriate
- [ ] Add memory leak detection in tests
- [ ] Profile memory usage with Instruments
- [ ] Verify no retain cycles in Coordinator classes

**Priority:** HIGH - Memory issues over time

---

### 6. Extract Magic Numbers and Hardcoded Values
**Problem:** Magic numbers (200, 40, 5, 20) and hardcoded values throughout codebase make it hard to maintain and configure.

**Tasks:**
- [ ] Create a `Constants` or `Configuration` struct
- [ ] Extract all magic numbers to named constants
  - [ ] Annotation sizes (200x40 for text annotations)
  - [ ] Minimum highlight size (5)
  - [ ] Max recent files (20)
  - [ ] Alpha values (0.3)
- [ ] Make max recent files configurable
- [ ] Make annotation sizes configurable
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
- [ ] Complete `updateNSView` implementation in `PDFViewRepresentable`
- [ ] Fix cursor handling (remove workaround)
- [ ] Ensure document changes propagate correctly
- [ ] Ensure annotation mode changes update properly
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
- [ ] Implement undo/redo state tracking
- [ ] Add annotation state persistence between sessions
- [ ] Improve state management patterns
- [ ] Add state validation

**Priority:** MEDIUM - Feature completeness

---

## 🟡 Performance & Code Optimization

### 11. Performance Optimization
**Goal:** Optimize for performance above all else. Use simplest and least processing UI elements.

**Tasks:**
- [ ] Audit UI components for performance
  - [ ] Replace heavy SwiftUI views with lighter alternatives where possible
  - [ ] Use `LazyVStack`/`LazyHStack` for large lists
  - [ ] Minimize view updates and re-renders
  - [ ] Use `@State` efficiently (avoid unnecessary state changes)
- [ ] Optimize PDF rendering
  - [ ] Implement lazy loading for PDF pages
  - [ ] Cache rendered pages
  - [ ] Reduce PDF view updates
  - [ ] Optimize annotation rendering
- [ ] Optimize recent files list
  - [ ] Lazy load file metadata
  - [ ] Cache file icons/thumbnails
  - [ ] Debounce file system checks
- [ ] Profile app performance
  - [ ] Use Instruments to identify bottlenecks
  - [ ] Optimize memory usage
  - [ ] Reduce CPU usage during interactions
- [ ] Simplify UI elements
  - [ ] Remove unnecessary animations
  - [ ] Use native controls where possible
  - [ ] Minimize custom view modifiers
  - [ ] Reduce view hierarchy depth

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
- [ ] Improve navigation
  - [ ] Add thumbnail sidebar for page navigation
  - [ ] Improve page navigation controls
  - [ ] Add page number input field
  - [ ] Add keyboard shortcuts for navigation
- [ ] Improve annotation workflow
  - [ ] Make annotation tools more accessible
  - [ ] Add annotation toolbar
  - [ ] Show annotation mode indicator
  - [ ] Improve annotation selection/editing
- [ ] Improve file management
  - [ ] Better recent files presentation
  - [ ] Add file search/filter
  - [ ] Add drag-and-drop support
  - [ ] Show file metadata (size, date, etc.)
- [ ] Improve toolbar
  - [ ] Organize tools logically
  - [ ] Add tooltips/help text
  - [ ] Group related actions
  - [ ] Add keyboard shortcuts display
- [ ] Improve empty states
  - [ ] Better "no PDF selected" state
  - [ ] Better "no recent files" state
  - [ ] Add helpful hints/instructions
- [ ] Accessibility improvements
  - [ ] Add VoiceOver support
  - [ ] Ensure keyboard navigation
  - [ ] Add high contrast mode support
  - [ ] Test with accessibility tools

**Priority:** MEDIUM - UX enhancement

---

### 13. Missing Core Features
**Problem:** Several standard PDF viewer features are missing, limiting app functionality.

**Tasks:**
- [ ] Add search functionality within PDFs
  - [ ] Text search with highlighting
  - [ ] Search results navigation
  - [ ] Search history
- [ ] Add bookmark/favorites system
  - [ ] Save page bookmarks
  - [ ] Quick navigation to bookmarks
  - [ ] Bookmark management
- [ ] Add annotation editing/deletion
  - [ ] Select and edit existing annotations
  - [ ] Delete annotations
  - [ ] Move/resize annotations
- [ ] Add undo/redo for annotations
  - [ ] Undo/redo stack
  - [ ] Keyboard shortcuts (Cmd+Z, Cmd+Shift+Z)
  - [ ] Visual feedback
- [ ] Add print functionality
  - [ ] Print dialog integration
  - [ ] Print preview
  - [ ] Print options (pages, scale, etc.)
- [ ] Add full-screen mode
  - [ ] Toggle full-screen (Cmd+Ctrl+F)
  - [ ] Hide/show toolbar in full-screen
  - [ ] Exit full-screen gracefully
- [ ] Add thumbnail navigation sidebar
  - [ ] Page thumbnails
  - [ ] Thumbnail navigation
  - [ ] Current page indicator
- [ ] Add dark mode optimization
  - [ ] Test dark mode appearance
  - [ ] Optimize colors for dark mode
  - [ ] Ensure readability

**Priority:** MEDIUM - Feature completeness

---

### 14. Multi-Document Support
**Problem:** App only supports one document at a time, limiting workflow.

**Tasks:**
- [ ] Add multi-file tabs/windows support
  - [ ] Tab bar for multiple documents
  - [ ] Window management
  - [ ] Document switching
- [ ] Add drag-and-drop file opening
  - [ ] Drag files onto app
  - [ ] Drag files onto window
  - [ ] Multiple file support
- [ ] Add document comparison view
  - [ ] Side-by-side viewing
  - [ ] Split view options

**Priority:** LOW - Future enhancement

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
- [ ] Add unit tests for `RecentFilesManager`
  - [ ] Test file addition/removal
  - [ ] Test persistence
  - [ ] Test bookmark handling
- [ ] Add unit tests for annotation logic
  - [ ] Test coordinate conversion
  - [ ] Test annotation creation
  - [ ] Test annotation bounds validation
- [ ] Add unit tests for error handling
  - [ ] Test error types
  - [ ] Test error recovery
- [ ] Add integration tests
  - [ ] Test PDF loading
  - [ ] Test save operations
  - [ ] Test annotation workflow
- [ ] Set up CI/CD with test automation
- [ ] Aim for >80% code coverage

**Priority:** MEDIUM - Quality assurance

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
15. **Multi-Document Support** (Low - future enhancement)
16. **Export and Advanced Features** (Low - future enhancement)

---

## ✅ Completion Criteria

### Critical Features
- [ ] All notifications are dismissible and visually appealing
- [ ] Recent files persist and work across app sessions
- [ ] No memory leaks detected
- [ ] All commented code removed or implemented

### Core Functionality
- [ ] App opens in fullscreen/maximized state by default
- [ ] Annotation coordinate system works accurately
- [ ] State management is robust and synchronized
- [ ] updateNSView implementation is complete

### Quality & Performance
- [ ] App performance is smooth with no lag
- [ ] Unit tests cover critical functionality (>80% coverage)
- [ ] All magic numbers extracted to constants
- [ ] Code is well-documented

### User Experience
- [ ] UI follows intuitive PDF viewer patterns
- [ ] All features are accessible and user-friendly
- [ ] Core missing features implemented (search, undo/redo, etc.)
- [ ] Dark mode optimized

---

*Last Updated: 2024*
*Status: In Progress*

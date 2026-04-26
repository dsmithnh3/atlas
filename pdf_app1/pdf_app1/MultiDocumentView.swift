//
//  MultiDocumentView.swift
//  PDFViewer
//
//  Multi-document interface with tabs and comparison
//
//  Provides tabbed interface for multiple PDF documents
//  with side-by-side comparison capabilities.
//

import SwiftUI
import PDFKit
import UniformTypeIdentifiers

// MARK: - Vertical Tab Bar View
struct DocumentVerticalTabBar: View {
    @Binding var documents: [PDFDocumentItem]
    @Binding var selectedDocumentID: UUID?
    @ObservedObject var documentManager: DocumentManager
    @EnvironmentObject var projectsManager: ProjectsManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Open Documents")
                    .font(.headline)
                Spacer()
                
                // New tab button
                Button(action: {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("OpenNewDocument"),
                        object: nil
                    )
                }) {
                    Image(systemName: "plus")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
                .frame(width: 20, height: 20)
                .help("New Document (⌘T)")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            // Vertical tabs list
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(documents, id: \.id) { document in
                        DocumentVerticalTabItem(
                            document: document,
                            isSelected: document.id == selectedDocumentID,
                            projectName: document.projectID != nil ? 
                                projectsManager.projects.first { $0.id == document.projectID }?.name : nil,
                            onClose: { documentManager.closeDocument(document) },
                            onSelect: { documentManager.selectDocument(id: document.id) }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .frame(minWidth: 200, maxWidth: 250)
    }
}

// MARK: - Vertical Tab Item
struct DocumentVerticalTabItem: View {
    let document: PDFDocumentItem
    let isSelected: Bool
    let projectName: String?
    let onClose: () -> Void
    let onSelect: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            // File icon
            Image(systemName: "doc.fill")
                .font(.system(size: 14))
                .foregroundColor(isSelected ? .accentColor : .blue)
                .frame(width: 16)
            
            // Document info
            VStack(alignment: .leading, spacing: 2) {
                Text(document.title)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                
                if let projectName = projectName {
                    Text(projectName)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Close button
            if isSelected {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
                .frame(width: 16, height: 16)
                .help("Close Tab (⌘W)")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
        )
        .onHover { isHovered in
            if isHovered {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }
        .onTapGesture {
            onSelect()
        }
        .contextMenu {
            if let projectName = projectName {
                Text("Project: \(projectName)")
                    .foregroundColor(.secondary)
                Divider()
            }
            
            Button("Show in Finder") {
                NSWorkspace.shared.selectFile(document.url.path, inFileViewerRootedAtPath: "")
            }
            
            Button("Close Tab") {
                onClose()
            }
            .keyboardShortcut("w", modifiers: [.command])
            
            Divider()
            
            Button("Close Other Tabs") {
                NotificationCenter.default.post(
                    name: NSNotification.Name("CloseOtherTabs"),
                    object: document
                )
            }
            
            Button("Open in New Window") {
                NotificationCenter.default.post(
                    name: NSNotification.Name("OpenDocumentInNewWindow"),
                    object: document
                )
            }
        }
    }
}

// MARK: - Comparison View
struct DocumentComparisonView: View {
    let leftDocument: PDFDocumentItem?
    let rightDocument: PDFDocumentItem?
    let splitView: ComparisonSplitView
    let onSplitViewChange: (ComparisonSplitView) -> Void
    
    var body: some View {
        Group {
            if let left = leftDocument, let right = rightDocument {
                HStack(spacing: 1) {
                    switch splitView {
                    case .sideBySide:
                        HStack(spacing: 1) {
                            DocumentPanel(document: left, title: "Left Document")
                            Divider()
                            DocumentPanel(document: right, title: "Right Document")
                        }
                    case .vertical:
                        VStack(spacing: 1) {
                            DocumentPanel(document: left, title: "Top Document")
                            Divider()
                            DocumentPanel(document: right, title: "Bottom Document")
                        }
                    case .horizontal:
                        HStack(spacing: 1) {
                            DocumentPanel(document: left, title: "Document 1")
                            Divider()
                            DocumentPanel(document: right, title: "Document 2")
                        }
                    }
                }
            } else {
                VStack {
                    Spacer()
                    Text("Select two documents to compare")
                        .foregroundColor(.secondary)
                        .font(.headline)
                    Text("Drag documents to the left and right panels")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Spacer()
                }
            }
        }
        .background(Color(NSColor.textBackgroundColor))
    }
}

// MARK: - Document Panel for Comparison
struct DocumentPanel: View {
    let document: PDFDocumentItem
    let title: String
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text(document.title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // PDF View
            PDFViewerView(
                pdfDocument: document.document,
                pdfURL: document.url,
                annotationMode: .constant(.none),
                highlightColor: .constant(.yellow),
                notificationManager: NotificationManager()
            )
        }
    }
}

// MARK: - Main Multi-Document View
struct MultiDocumentView: View {
    @EnvironmentObject var documentManager: DocumentManager
    @EnvironmentObject var recentFilesManager: RecentFilesManager
    @StateObject private var alertManager = AlertManager()
    @StateObject private var notificationManager = NotificationManager()
    @StateObject private var loadingManager = LoadingStateManager()
    @EnvironmentObject var projectsManager: ProjectsManager
    
    @Environment(KnowledgeGraph.self) var knowledgeGraph

    @State private var selectedPDF: PDFDocument?
    @State private var selectedPDFURL: URL?
    @State private var annotationMode: AnnotationMode = .none
    @State private var highlightColor: Color = .yellow
    @State private var paneMode: PaneMode = .split
    @State private var mapZoomLevel: SemanticZoomLevel = .concept
    @State private var syncManager = BidirectionalSyncManager()
    @State private var showCommandPalette = false
    @State private var sidebarSection: SidebarSection = .projects
    @State private var projectsQuery: String = ""
    @State private var filesQuery: String = ""
    @State private var showingCreateProject = false
    @State private var createProjectName: String = ""
    @State private var createProjectPickedURLs: [URL] = []
    @State private var renamingProjectID: UUID?
    @State private var showingRenameProject = false
    @State private var renameProjectName: String = ""
    
    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            mainContent
        }
        .overlay(alignment: .topTrailing) {
            let visible = Array(notificationManager.notifications.suffix(AppConstants.maxVisibleNotifications).reversed())
            VStack(alignment: .trailing, spacing: 10) {
                ForEach(visible, id: \.id) { notification in
                    ToastNotificationView(item: notification) {
                    notificationManager.dismiss(notification.id)
                }
                }
            }
            .padding()
        }
        .overlay {
            if showCommandPalette {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { showCommandPalette = false }

                VStack {
                    CommandPaletteView(
                        isPresented: $showCommandPalette,
                        graph: knowledgeGraph,
                        onSelectNode: { nodeID in
                            syncManager.navigateToNode(nodeID)
                        },
                        onNavigateToPage: { page in
                            NotificationCenter.default.post(
                                name: NSNotification.Name("NavigateToPage"),
                                object: page
                            )
                        }
                    )
                    .padding(.top, 100)
                    Spacer()
                }
            }
        }
        .environmentObject(alertManager)
        .environmentObject(notificationManager)
        .environmentObject(loadingManager)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenDocuments"))) { notification in
            if let urls = notification.object as? [URL] {
                documentManager.openDocuments(urls, projectID: projectsManager.selectedProjectID)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenNewDocument"))) { _ in
            // Trigger file picker
            let panel = NSOpenPanel()
            panel.title = "Open PDF Document"
            panel.allowsMultipleSelection = true
            panel.allowedContentTypes = [.pdf]
            panel.begin { response in
                if response == .OK {
                    documentManager.openDocuments(panel.urls, projectID: projectsManager.selectedProjectID)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CloseCurrentTab"))) { _ in
            if let document = documentManager.selectedDocument {
                documentManager.closeDocument(document)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CloseOtherTabs"))) { notification in
            if let currentDocument = notification.object as? PDFDocumentItem {
                documentManager.documents.removeAll { $0.id != currentDocument.id }
                documentManager.selectedDocumentID = currentDocument.id
            }
        }
        // Pane mode keyboard shortcuts
        .background(
            Group {
                Button("") { paneMode = .pdfOnly }
                    .keyboardShortcut("1", modifiers: [.command])
                Button("") { paneMode = .mapOnly }
                    .keyboardShortcut("2", modifiers: [.command])
                Button("") { paneMode = .split }
                    .keyboardShortcut("3", modifiers: [.command])
                Button("") { showCommandPalette.toggle() }
                    .keyboardShortcut("k", modifiers: [.command])
            }
            .frame(width: 0, height: 0)
            .opacity(0)
        )
        .onChange(of: documentManager.selectedDocumentID) { _, _ in
            if let doc = documentManager.selectedDocument {
                syncManager.setDocumentURL(doc.url)
                syncManager.setGraph(knowledgeGraph)
            }
        }
        .onAppear {
            if let doc = documentManager.selectedDocument {
                syncManager.setDocumentURL(doc.url)
                syncManager.setGraph(knowledgeGraph)
            }
        }
    }
    
    // MARK: - Sidebar Section
    enum SidebarSection: String, CaseIterable {
        case projects = "Projects"
        case recents = "Recents"
    }

    // MARK: - Sidebar View
    @ViewBuilder
    private var sidebar: some View {
        VStack(spacing: 0) {
            // ── Open Tabs (always visible when documents are open) ──
            if !documentManager.documents.isEmpty {
                VStack(spacing: 0) {
                    HStack {
                        Text("Open")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fontWeight(.semibold)
                            .textCase(.uppercase)
                        Spacer()
                        Button(action: {
                            NotificationCenter.default.post(name: NSNotification.Name("OpenNewDocument"), object: nil)
                        }) {
                            Image(systemName: "plus")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .help("Open PDF (Cmd+T)")
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 6)

                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(documentManager.documents, id: \.id) { document in
                                sidebarTabRow(document)
                            }
                        }
                        .padding(.horizontal, 6)
                    }
                    .frame(maxHeight: min(CGFloat(documentManager.documents.count) * 34, 170))
                }

                Divider()
                    .padding(.top, 4)
            }

            // ── Section Picker ──
            Picker("", selection: $sidebarSection) {
                ForEach(SidebarSection.allCases, id: \.self) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // ── Section Content ──
            switch sidebarSection {
            case .projects:
                projectsSectionContent
            case .recents:
                recentsSectionContent
            }
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        .sheet(isPresented: $showingCreateProject) {
            CreateProjectView(
                projectName: $createProjectName,
                pickedURLs: $createProjectPickedURLs,
                onCreate: { name, urls in
                    projectsManager.createProject(name: name, urls: urls)
                    createProjectName = ""
                    createProjectPickedURLs = []
                }
            )
        }
        .sheet(isPresented: $showingRenameProject) {
            if let projectID = renamingProjectID {
                RenameProjectView(
                    projectID: projectID,
                    currentName: $renameProjectName,
                    onRename: { newName in
                        projectsManager.renameProject(projectID, name: newName)
                        renamingProjectID = nil
                        renameProjectName = ""
                    }
                )
            }
        }
    }

    // MARK: - Open Tab Row
    private func sidebarTabRow(_ document: PDFDocumentItem) -> some View {
        let isSelected = document.id == documentManager.selectedDocumentID
        return HStack(spacing: 6) {
            Image(systemName: "doc.fill")
                .font(.system(size: 11))
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .frame(width: 14)

            Text(document.title)
                .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                .foregroundColor(isSelected ? .primary : .secondary)
                .lineLimit(1)

            Spacer()

            Button(action: { documentManager.closeDocument(document) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
            .opacity(isSelected ? 1 : 0.5)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { documentManager.selectDocument(id: document.id) }
        .contextMenu {
            Button("Show in Finder") {
                NSWorkspace.shared.selectFile(document.url.path, inFileViewerRootedAtPath: "")
            }
            Button("Close Tab") { documentManager.closeDocument(document) }
            Button("Close Other Tabs") {
                NotificationCenter.default.post(name: NSNotification.Name("CloseOtherTabs"), object: document)
            }
        }
    }

    // MARK: - Projects Section
    private var projectsSectionContent: some View {
        VStack(spacing: 0) {
            // Search + New Project
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Search...", text: $projectsQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .controlBackgroundColor)))

                Button(action: { showingCreateProject = true }) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 13))
                }
                .buttonStyle(.borderless)
                .help("New Project")
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            // Project list
            if filteredProjects.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "folder")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No projects yet")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Button("Create Project") { showingCreateProject = true }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filteredProjects) { project in
                            sidebarProjectRow(project)
                        }
                    }
                    .padding(.horizontal, 6)
                }
            }

            // Project files (when a project is selected)
            if projectsManager.selectedProjectID != nil {
                Divider()
                    .padding(.vertical, 4)
                projectFilesPanel
            }
        }
    }

    // MARK: - Project Row
    private func sidebarProjectRow(_ project: Project) -> some View {
        let isSelected = projectsManager.selectedProjectID == project.id
        return HStack(spacing: 6) {
            Image(systemName: "folder.fill")
                .font(.system(size: 12))
                .foregroundColor(isSelected ? .accentColor : .orange)

            VStack(alignment: .leading, spacing: 1) {
                Text(project.name)
                    .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                    .lineLimit(1)
                Text("\(project.files.count) file\(project.files.count == 1 ? "" : "s")")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            projectsManager.selectedProjectID = isSelected ? nil : project.id
        }
        .contextMenu {
            Button("Open All Files") {
                let files = projectsManager.files(for: project.id, query: "")
                documentManager.openProjectFiles(project.id, files: files, projectsManager: projectsManager)
            }
            Divider()
            Button("Rename...") {
                renamingProjectID = project.id
                renameProjectName = project.name
                showingRenameProject = true
            }
            Button("Delete", role: .destructive) {
                projectsManager.deleteProject(project.id)
            }
        }
    }

    // MARK: - Recents Section
    private var recentsSectionContent: some View {
        VStack(spacing: 0) {
            if recentFilesManager.recentFiles.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "clock")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No recent files")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Button("Open PDF") {
                        NotificationCenter.default.post(name: NSNotification.Name("OpenNewDocument"), object: nil)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(recentFilesManager.recentFiles, id: \.path) { url in
                            HStack(spacing: 6) {
                                Image(systemName: "doc.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.blue)
                                    .frame(width: 14)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(url.lastPathComponent)
                                        .font(.system(size: 12))
                                        .lineLimit(1)
                                    Text(url.deletingLastPathComponent().lastPathComponent)
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                documentManager.openDocument(url)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color.clear)
                            )
                        }
                    }
                    .padding(.horizontal, 6)
                }
            }
        }
    }
    
    // MARK: - Main Content
    @ViewBuilder
    private var mainContent: some View {
        Group {
            switch documentManager.viewMode {
            case .single:
                if let document = documentManager.selectedDocument {
                    SplitPaneContainer(paneMode: $paneMode) {
                        PDFViewerView(
                            pdfDocument: document.document,
                            pdfURL: document.url,
                            annotationMode: $annotationMode,
                            highlightColor: $highlightColor,
                            notificationManager: notificationManager
                        )
                        .enhancedDropZone(maxFiles: 10) { urls in
                            documentManager.openDocuments(urls, projectID: projectsManager.selectedProjectID)
                        }
                    } mapContent: {
                        KnowledgeMapView(
                            graph: knowledgeGraph,
                            zoomLevel: $mapZoomLevel,
                            documentURL: document.url,
                            onNavigateToPage: { pageIndex, _ in
                                // Navigate the PDF to the given page
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("NavigateToPage"),
                                    object: pageIndex
                                )
                            }
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Empty state when no document is selected
                    emptyStateView
                }
                
            case .comparison(let splitView):
                VStack(spacing: 0) {
                    // Comparison viewer
                    DocumentComparisonView(
                        leftDocument: documentManager.comparisonDocuments.left,
                        rightDocument: documentManager.comparisonDocuments.right,
                        splitView: splitView,
                        onSplitViewChange: documentManager.setComparisonSplitView
                    )
                    .enhancedDropZone(maxFiles: 2) { urls in
                        if urls.count >= 2 {
                            documentManager.startComparison(
                                left: documentManager.documents.first { $0.url == urls[0] },
                                right: documentManager.documents.first { $0.url == urls[1] }
                            )
                        } else if let first = urls.first {
                            documentManager.openDocument(first, projectID: projectsManager.selectedProjectID)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity) // Take full space
                    
                    // Comparison controls
                    HStack {
                        Text("Comparison Mode")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Picker("Split View", selection: Binding(
                            get: {
                                if case .comparison(let sv) = documentManager.viewMode { return sv }
                                return .sideBySide
                            },
                            set: { documentManager.setComparisonSplitView($0) }
                        )) {
                            Text("Side by Side").tag(ComparisonSplitView.sideBySide)
                            Text("Vertical").tag(ComparisonSplitView.vertical)
                            Text("Horizontal").tag(ComparisonSplitView.horizontal)
                        }
                        .pickerStyle(.segmented)
                        
                        Button("Exit Comparison") {
                            documentManager.exitComparisonMode()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(Color(NSColor.separatorColor)),
                        alignment: .top
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Ensure full space usage
        .background(Color(NSColor.textBackgroundColor)) // Consistent background
    }
    
    // MARK: - Project Files Panel (Left Sidebar)
    @ViewBuilder
    private var projectFilesPanel: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Files")
                    .font(.headline)
                
                Spacer()
                
                // Open all files in project
                Button(action: {
                    if let projectID = projectsManager.selectedProjectID {
                        let projectFiles = projectsManager.files(for: projectID, query: "")
                        documentManager.openProjectFiles(projectID, files: projectFiles, projectsManager: projectsManager)
                    }
                }) {
                    Image(systemName: "doc.text.fill")
                }
                .buttonStyle(.borderless)
                .help("Open All Files in Tabs")
                
                Button(action: {
                    let panel = NSOpenPanel()
                    panel.title = "Add PDFs to Project"
                    panel.allowsMultipleSelection = true
                    panel.allowedContentTypes = [.pdf]
                    panel.begin { response in
                        if response == .OK {
                            if let project = projectsManager.projects.first(where: { $0.id == projectsManager.selectedProjectID }) {
                                projectsManager.addFiles(to: project.id, urls: panel.urls)
                            }
                        }
                    }
                }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Add PDFs to Project")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search files...", text: $filesQuery)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            // Files list - vertical layout like Finder
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(filteredProjectFiles, id: \.self) { file in
                        ProjectFileRow(
                            file: file,
                            projectsManager: projectsManager,
                            projectID: projectsManager.selectedProjectID ?? UUID(),
                            onSelect: { url in
                                // Open the file in the multi-document system with project context
                                documentManager.openDocument(url, projectID: projectsManager.selectedProjectID)
                            },
                            onRemove: { url in
                                if let projectID = projectsManager.selectedProjectID {
                                    // Find the file ID and remove it
                                    let projectFiles = projectsManager.files(for: projectID, query: "")
                                    if let projectFile = projectFiles.first(where: { $0.lastKnownPath == url.path }) {
                                        projectsManager.removeFile(projectID: projectID, fileID: projectFile.id)
                                    }
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .frame(minWidth: 200, maxWidth: 250)
    }
    
    // MARK: - Project File Row (Vertical Layout)
    struct ProjectFileRow: View {
        let file: URL
        let projectsManager: ProjectsManager
        let projectID: UUID
        let onSelect: (URL) -> Void
        let onRemove: (URL) -> Void
        
        var body: some View {
            HStack(spacing: 8) {
                // File icon
                Image(systemName: "doc.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                    .frame(width: 16)
                
                // File name
                Button(action: { onSelect(file) }) {
                    HStack {
                        Text(file.lastPathComponent)
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Spacer()
                    }
                }
                .buttonStyle(.borderless)
                
                // Remove button
                Button(action: { onRemove(file) }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
                .opacity(0.8)
                .onHover { isHovered in
                    // Show remove button more prominently on hover
                    if isHovered {
                        NSCursor.pointingHand.set()
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.clear)
            .onHover { isHovered in
                if isHovered {
                    NSCursor.pointingHand.set()
                } else {
                    NSCursor.arrow.set()
                }
            }
        }
    }
    
    // MARK: - Empty State View
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))

            VStack(spacing: 6) {
                Text("Open a PDF to get started")
                    .font(.title3)
                    .foregroundColor(.primary)

                Text("Drop a file here, open from the sidebar, or use Cmd+T")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }

            HStack(spacing: 12) {
                Button {
                    NotificationCenter.default.post(name: NSNotification.Name("OpenNewDocument"), object: nil)
                } label: {
                    Label("Open PDF", systemImage: "doc.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    showingCreateProject = true
                } label: {
                    Label("New Project", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
        .enhancedDropZone(maxFiles: 10) { urls in
            documentManager.openDocuments(urls, projectID: projectsManager.selectedProjectID)
        }
    }
    
    // MARK: - Computed Properties
    private var filteredProjects: [Project] {
        if projectsQuery.isEmpty {
            return projectsManager.projects
        } else {
            return projectsManager.projects.filter { project in
                project.name.localizedCaseInsensitiveContains(projectsQuery)
            }
        }
    }
    
    private var filteredProjectFiles: [URL] {
        guard let projectID = projectsManager.selectedProjectID else { return [] }
        
        let files = projectsManager.files(for: projectID, query: filesQuery)
        return files.compactMap { file in
            // Try to resolve from bookmark first, fallback to lastKnownPath
            if let url = projectsManager.resolveURL(for: projectID, fileID: file.id) {
                return url
            } else {
                // Fallback to lastKnownPath
                return URL(fileURLWithPath: file.lastKnownPath)
            }
        }
    }
}

//
//  PDFViewerApp.swift
//  PDFViewer
//
//  Created on macOS
//

import SwiftUI
import AppKit
import os.log

@main
struct PDFViewerApp: App {
    @StateObject private var recentFilesManager: RecentFilesManager
    @StateObject private var projectsManager = ProjectsManager()
    @StateObject private var documentManager: DocumentManager
    @State private var knowledgeGraph = KnowledgeGraph()
    @State private var aiServiceManager = AIServiceManager()
    /// Guards against re-sweeping if `didLoadInitialState` re-fires for any reason.
    @State private var didSweepOrphans = false

    init() {
        let recent = RecentFilesManager()
        _recentFilesManager = StateObject(wrappedValue: recent)
        _documentManager = StateObject(wrappedValue: DocumentManager(recentFilesManager: recent))
    }

    var body: some Scene {
        WindowGroup {
            MultiDocumentView()
                .environmentObject(recentFilesManager)
                .environmentObject(projectsManager)
                .environmentObject(documentManager)
                .environment(knowledgeGraph)
                .environment(aiServiceManager)
                .frame(minWidth: AppConstants.minWindowWidth, minHeight: AppConstants.minWindowHeight)
                .onAppear {
                    documentManager.restoreOpenSession()
                    configureWindow()
                    // If projects loaded synchronously (e.g. cached state), trigger
                    // the sweep right now; otherwise the onChange below will catch it.
                    if projectsManager.didLoadInitialState {
                        runGraphOrphanSweep()
                    }
                }
                .onChange(of: projectsManager.didLoadInitialState) { _, loaded in
                    if loaded {
                        runGraphOrphanSweep()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    AtlasLogger.ui.info("[App] willTerminate: flushing session + graph save")
                    documentManager.saveOpenSession()
                    GraphStore.shared.flushPendingSave()
                }
        }
        .defaultSize(width: NSScreen.main?.frame.width ?? AppConstants.minWindowWidth,
                    height: NSScreen.main?.frame.height ?? AppConstants.minWindowHeight)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Tab") {
                    NotificationCenter.default.post(name: .openNewDocument, object: nil)
                }
                .keyboardShortcut("t", modifiers: [.command])
                
                Button("Close Tab") {
                    NotificationCenter.default.post(name: .closeCurrentTab, object: nil)
                }
                .keyboardShortcut("w", modifiers: [.command])
                
                Divider()
                
                Button("Enter Comparison Mode") {
                    documentManager.startComparison(
                        left: documentManager.documents.first,
                        right: documentManager.documents.dropFirst().first
                    )
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            }

            CommandMenu("View") {
                Button("PDF Only") {
                    NotificationCenter.default.post(name: .setPaneMode, object: PaneMode.pdfOnly)
                }
                .keyboardShortcut("1", modifiers: [.command])

                Button("Map Only") {
                    NotificationCenter.default.post(name: .setPaneMode, object: PaneMode.mapOnly)
                }
                .keyboardShortcut("2", modifiers: [.command])

                Button("Split View") {
                    NotificationCenter.default.post(name: .setPaneMode, object: PaneMode.split)
                }
                .keyboardShortcut("3", modifiers: [.command])
            }
        }
        .windowStyle(.hiddenTitleBar)

        Settings {
            PreferencesView()
                .environment(aiServiceManager)
        }
    }
    
    /// Scan the on-disk graph store and delete per-document graphs that no
    /// longer correspond to any open tab, recent file, or project file.
    /// Runs once per launch, after `ProjectsManager` finishes its async load
    /// so we don't accidentally GC graphs whose owning project hasn't been
    /// hydrated yet.
    private func runGraphOrphanSweep() {
        guard !didSweepOrphans else { return }
        didSweepOrphans = true

        var alive: Set<URL> = []
        alive.formUnion(documentManager.documents.map { $0.url })
        alive.formUnion(recentFilesManager.recentFiles)
        alive.formUnion(projectsManager.allFileURLsForSweep())

        AtlasLogger.ui.info("[App] runGraphOrphanSweep: alive set = \(documentManager.documents.count) open + \(recentFilesManager.recentFiles.count) recent + \(projectsManager.projects.reduce(0) { $0 + $1.files.count }) project file(s) → \(alive.count) unique URL(s)")
        let deleted = GraphStore.shared.sweepOrphans(aliveURLs: alive)
        AtlasLogger.ui.info("[App] runGraphOrphanSweep: deleted \(deleted) orphan graph(s)")
    }

    /// Configure window to open maximized/fullscreen by default
    private func configureWindow() {
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first {
                // Set window to fill screen (maximized)
                if let screen = NSScreen.main {
                    window.setFrame(screen.visibleFrame, display: true)
                }
                
                // Center window if smaller than screen
                window.center()
                
                // Make window resizable with content extending into title bar
                window.styleMask.insert(.resizable)
                window.styleMask.insert(.fullSizeContentView)
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden

                let shouldStartFullscreen = UserDefaults.standard.bool(forKey: AppConstants.windowStateKey)
                if shouldStartFullscreen {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        window.toggleFullScreen(nil)
                    }
                }
            }
        }
    }
}


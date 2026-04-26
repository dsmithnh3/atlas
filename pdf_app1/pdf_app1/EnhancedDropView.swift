//
//  EnhancedDropView.swift
//  PDFViewer
//
//  Enhanced drag-and-drop support for multiple files
//
//  Supports dropping multiple PDF files with visual feedback
//  and intelligent file handling.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Enhanced Drop Delegate
struct EnhancedDropDelegate: DropDelegate {
    let onFilesDropped: ([URL]) -> Void
    let isValidDrop: ([URL]) -> Bool
    let maxFiles: Int
    
    func validateDrop(info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: [UTType.fileURL])
        
        var urls: [URL] = []
        let group = DispatchGroup()
        
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
                
                let url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else {
                    url = item as? URL
                }
                
                if let fileURL = url, fileURL.pathExtension.lowercased() == "pdf" {
                    urls.append(fileURL)
                }
            }
        }
        
        group.notify(queue: .main) {
            // Validation result will be handled by the drop system
        }
        
        return urls.count <= maxFiles && urls.allSatisfy { $0.pathExtension.lowercased() == "pdf" }
    }
    
    func performDrop(info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: [UTType.fileURL])
        
        var urls: [URL] = []
        let group = DispatchGroup()
        
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
                
                let url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else {
                    url = item as? URL
                }
                
                if let fileURL = url, fileURL.pathExtension.lowercased() == "pdf" {
                    urls.append(fileURL)
                }
            }
        }
        
        group.notify(queue: .main) {
            if !urls.isEmpty && isValidDrop(urls) {
                onFilesDropped(urls)
            }
        }
        
        return true
    }
}

// MARK: - Enhanced Drop View
struct EnhancedDropView<Content: View>: View {
    let content: Content
    let onFilesDropped: ([URL]) -> Void
    let maxFiles: Int
    @State private var isDropTargeted = false
    @State private var dropFeedback = ""
    @State private var pendingFiles: [URL] = []
    
    init(maxFiles: Int = 10, onFilesDropped: @escaping ([URL]) -> Void, @ViewBuilder content: () -> Content) {
        self.maxFiles = maxFiles
        self.onFilesDropped = onFilesDropped
        self.content = content()
    }
    
    private var dropDelegate: EnhancedDropDelegate {
        EnhancedDropDelegate(
            onFilesDropped: { urls in
                handleDroppedFiles(urls)
            },
            isValidDrop: { urls in
                return urls.count <= maxFiles && urls.allSatisfy { $0.pathExtension.lowercased() == "pdf" }
            },
            maxFiles: maxFiles
        )
    }
    
    var body: some View {
        content
            .background(
                dropOverlay
                    .opacity(isDropTargeted ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: isDropTargeted)
            )
            .onDrop(of: [UTType.fileURL], delegate: dropDelegate)
            .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
                isDropTargeted = true
                processPendingFiles(providers)
                return true
            }
    }
    
    @ViewBuilder
    private var dropOverlay: some View {
        ZStack {
            Color.black.opacity(0.1)
            
            VStack(spacing: 16) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
                
                VStack(spacing: 8) {
                    Text(dropFeedback.isEmpty ? "Drop PDF Files Here" : dropFeedback)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if !pendingFiles.isEmpty {
                        Text("Found \(pendingFiles.count) PDF file\(pendingFiles.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(pendingFiles.map { $0.lastPathComponent }.joined(separator: "\n"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            )
            .padding(40)
        }
    }
    
    private func processPendingFiles(_ providers: [NSItemProvider]) {
        let group = DispatchGroup()
        
        for provider in providers.prefix(maxFiles) {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
                
                let url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else {
                    url = item as? URL
                }
                
                if let fileURL = url, fileURL.pathExtension.lowercased() == "pdf" {
                    DispatchQueue.main.async {
                        pendingFiles.append(fileURL)
                    }
                }
            }
        }
        
        group.notify(queue: .main) {
            if pendingFiles.count > maxFiles {
                dropFeedback = "Too many files. Maximum \(maxFiles) allowed."
            } else if pendingFiles.isEmpty {
                dropFeedback = "No valid PDF files found."
            } else {
                dropFeedback = ""
            }
        }
    }
    
    private func handleDroppedFiles(_ urls: [URL]) {
        let validPDFs = urls.filter { $0.pathExtension.lowercased() == "pdf" }
        
        if validPDFs.isEmpty {
            dropFeedback = "No valid PDF files found."
            return
        }
        
        if validPDFs.count > maxFiles {
            dropFeedback = "Too many files. Opening first \(maxFiles)."
            onFilesDropped(Array(validPDFs.prefix(maxFiles)))
        } else {
            onFilesDropped(validPDFs)
        }
        
        // Reset after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isDropTargeted = false
            pendingFiles.removeAll()
            dropFeedback = ""
        }
    }
}

// MARK: - Drop Zone Modifier
extension View {
    func enhancedDropZone(maxFiles: Int = 10, onFilesDropped: @escaping ([URL]) -> Void) -> some View {
        EnhancedDropView(maxFiles: maxFiles, onFilesDropped: onFilesDropped) {
            self
        }
    }
}

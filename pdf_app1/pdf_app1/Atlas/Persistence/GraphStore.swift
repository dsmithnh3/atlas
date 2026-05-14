//
//  GraphStore.swift
//  Atlas
//
//  Persistent storage for knowledge graphs
//  Stores one graph file per document, keyed by URL hash
//

import Foundation
import os.log

private let log = AtlasLogger.graph

class GraphStore {
    static let shared = GraphStore()

    private let fileManager = FileManager.default
    private var saveWorkItem: DispatchWorkItem?
    private let saveDebounceInterval: TimeInterval = 1.0

    private var graphsDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Atlas/graphs", isDirectory: true)
    }

    init() {
        try? fileManager.createDirectory(at: graphsDirectory, withIntermediateDirectories: true)
    }

    // MARK: - File Path Helpers

    private func graphFileURL(for documentURL: URL) -> URL {
        graphsDirectory.appendingPathComponent("\(documentURL.absoluteString.sha256HexPrefix16).json")
    }

    private func projectGraphFileURL(for projectID: UUID) -> URL {
        graphsDirectory.appendingPathComponent("project_\(projectID.uuidString).json")
    }

    // MARK: - Save / Load per Document

    private struct StoredGraph: Codable {
        let mtime: TimeInterval?
        let size: Int?
        let payload: Data
    }

    private func currentMtimeAndSize(for documentURL: URL) -> (TimeInterval?, Int?) {
        guard let attrs = try? fileManager.attributesOfItem(atPath: documentURL.path) else {
            return (nil, nil)
        }
        let mtime = (attrs[.modificationDate] as? Date)?.timeIntervalSince1970
        let size = attrs[.size] as? Int
        return (mtime, size)
    }

    // Writes already-encoded graph bytes to disk. Used by the debounced
    // save path so the work item can run on a background queue without
    // touching `KnowledgeGraph` state (which is not thread-safe).
    private func writeStoredGraph(payload: Data, nodeCount: Int, edgeCount: Int, for documentURL: URL) {
        do {
            let (mtime, size) = currentMtimeAndSize(for: documentURL)
            let stored = StoredGraph(mtime: mtime, size: size, payload: payload)
            let data = try JSONEncoder().encode(stored)
            let fileURL = graphFileURL(for: documentURL)
            try data.write(to: fileURL, options: .atomic)
            log.info("[GraphStore] Saved graph for \(documentURL.lastPathComponent): \(nodeCount) nodes, \(edgeCount) edges (\(data.count) bytes)")
        } catch {
            log.error("[GraphStore] Failed to save graph for \(documentURL.lastPathComponent): \(error)")
        }
    }

    func load(for documentURL: URL) -> KnowledgeGraph? {
        let fileURL = graphFileURL(for: documentURL)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            log.info("[GraphStore] No saved graph for \(documentURL.lastPathComponent)")
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)

            // New format: invalidate when source mtime or size changed since save.
            if let stored = try? JSONDecoder().decode(StoredGraph.self, from: data) {
                let (currentMtime, currentSize) = currentMtimeAndSize(for: documentURL)
                if let saved = stored.mtime, let cur = currentMtime, abs(saved - cur) > 1.0 {
                    log.info("[GraphStore] Stale graph (mtime changed) for \(documentURL.lastPathComponent), invalidating")
                    return nil
                }
                if let saved = stored.size, let cur = currentSize, saved != cur {
                    log.info("[GraphStore] Stale graph (size changed) for \(documentURL.lastPathComponent), invalidating")
                    return nil
                }
                let graph = KnowledgeGraph()
                try graph.decode(from: stored.payload)
                log.info("[GraphStore] Loaded graph for \(documentURL.lastPathComponent): \(graph.nodeCount) nodes, \(graph.edgeCount) edges")
                return graph
            }

            // Legacy format (pre-StoredGraph): no mtime check available.
            let graph = KnowledgeGraph()
            try graph.decode(from: data)
            log.info("[GraphStore] Loaded legacy graph for \(documentURL.lastPathComponent) (no mtime check)")
            return graph
        } catch {
            log.error("[GraphStore] Failed to load graph for \(documentURL.lastPathComponent): \(error)")
            return nil
        }
    }

    // MARK: - Save / Load per Project

    func saveProjectGraph(_ graph: KnowledgeGraph, projectID: UUID) {
        do {
            let data = try graph.encode()
            let fileURL = projectGraphFileURL(for: projectID)
            try data.write(to: fileURL, options: .atomic)
            log.info("[GraphStore] Saved project graph \(projectID.uuidString.prefix(8)): \(graph.nodeCount) nodes, \(graph.edgeCount) edges (\(data.count) bytes)")
        } catch {
            log.error("[GraphStore] Failed to save project graph \(projectID): \(error)")
        }
    }

    func loadProjectGraph(projectID: UUID) -> KnowledgeGraph? {
        let fileURL = projectGraphFileURL(for: projectID)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            log.info("[GraphStore] No saved project graph for \(projectID.uuidString.prefix(8))")
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let graph = KnowledgeGraph()
            try graph.decode(from: data)
            log.info("[GraphStore] Loaded project graph \(projectID.uuidString.prefix(8)): \(graph.nodeCount) nodes, \(graph.edgeCount) edges")
            return graph
        } catch {
            log.error("[GraphStore] Failed to load project graph \(projectID): \(error)")
            return nil
        }
    }

    // MARK: - Debounced Save

    func scheduleSave(_ graph: KnowledgeGraph, for documentURL: URL) {
        // Encode synchronously on the caller's thread so the work item
        // only captures a value-type payload (Data). Previously the work
        // item held the KnowledgeGraph reference and called encode() on
        // the background queue, racing against ongoing mutations to
        // nodes/edges from the actor that owns the graph.
        let payload: Data
        let nodeCount = graph.nodeCount
        let edgeCount = graph.edgeCount
        do {
            payload = try graph.encode()
        } catch {
            log.error("[GraphStore] Failed to encode graph for \(documentURL.lastPathComponent): \(error)")
            return
        }

        saveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.writeStoredGraph(
                payload: payload,
                nodeCount: nodeCount,
                edgeCount: edgeCount,
                for: documentURL
            )
        }
        saveWorkItem = workItem
        DispatchQueue.global(qos: .utility).asyncAfter(
            deadline: .now() + saveDebounceInterval,
            execute: workItem
        )
    }

    // MARK: - Flush

    /// Immediately executes any pending debounced save. Call on app termination.
    func flushPendingSave() {
        saveWorkItem?.perform()
        saveWorkItem?.cancel()
        saveWorkItem = nil
    }

    // MARK: - Delete

    func deleteGraph(for documentURL: URL) {
        let fileURL = graphFileURL(for: documentURL)
        try? fileManager.removeItem(at: fileURL)
    }

    func deleteProjectGraph(projectID: UUID) {
        let fileURL = projectGraphFileURL(for: projectID)
        try? fileManager.removeItem(at: fileURL)
    }

    // MARK: - Query

    func hasGraph(for documentURL: URL) -> Bool {
        fileManager.fileExists(atPath: graphFileURL(for: documentURL).path)
    }
}

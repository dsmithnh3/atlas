//
//  UndoRedoManager.swift
//  PDFViewer
//
//  Manages undo/redo operations for annotations
//

import Foundation
import PDFKit
import AppKit
import Combine

/// Represents an annotation operation for undo/redo
enum AnnotationOperation {
    case add(annotation: PDFAnnotation, page: PDFPage)
    case remove(annotation: PDFAnnotation, page: PDFPage)
    case modify(annotation: PDFAnnotation, oldBounds: CGRect, newBounds: CGRect, page: PDFPage)
    case modifyContents(annotation: PDFAnnotation, oldContents: String?, newContents: String?, page: PDFPage)
    case modifyColor(annotation: PDFAnnotation, oldColor: NSColor, newColor: NSColor, page: PDFPage)
    case rotatePage(page: PDFPage, oldRotation: Int, newRotation: Int)
}

/// Manages undo/redo stack for annotation operations
class UndoRedoManager: ObservableObject {
    private var undoStack: [AnnotationOperation] = []
    private var redoStack: [AnnotationOperation] = []
    private let maxStackSize = 50
    
    @Published var canUndo: Bool = false
    @Published var canRedo: Bool = false
    
    private func updatePublishedProperties() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
    
    /// Add an operation to the undo stack
    func addOperation(_ operation: AnnotationOperation) {
        undoStack.append(operation)
        
        // Clear redo stack when new operation is added
        redoStack.removeAll()
        
        // Limit stack size
        if undoStack.count > maxStackSize {
            undoStack.removeFirst()
        }
        
        updatePublishedProperties()
    }
    
    /// Undo the last operation
    func undo() -> AnnotationOperation? {
        guard let operation = undoStack.popLast() else {
            updatePublishedProperties()
            return nil
        }
        
        redoStack.append(operation)
        updatePublishedProperties()
        return operation
    }
    
    /// Redo the last undone operation
    func redo() -> AnnotationOperation? {
        guard let operation = redoStack.popLast() else {
            updatePublishedProperties()
            return nil
        }
        
        undoStack.append(operation)
        updatePublishedProperties()
        return operation
    }
    
    /// Clear all undo/redo history
    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
        updatePublishedProperties()
    }
    
    /// Execute undo operation
    func executeUndo(_ operation: AnnotationOperation) {
        switch operation {
        case .add(let annotation, let page):
            page.removeAnnotation(annotation)
        case .remove(let annotation, let page):
            page.addAnnotation(annotation)
        case .modify(let annotation, let oldBounds, _, _):
            annotation.bounds = oldBounds
        case .modifyContents(let annotation, let oldContents, _, _):
            annotation.contents = oldContents
        case .modifyColor(let annotation, let oldColor, _, _):
            annotation.color = oldColor
        case .rotatePage(let page, let oldRotation, _):
            page.rotation = oldRotation
        }
    }

    /// Execute redo operation
    func executeRedo(_ operation: AnnotationOperation) {
        switch operation {
        case .add(let annotation, let page):
            page.addAnnotation(annotation)
        case .remove(let annotation, let page):
            page.removeAnnotation(annotation)
        case .modify(let annotation, _, let newBounds, _):
            annotation.bounds = newBounds
        case .modifyContents(let annotation, _, let newContents, _):
            annotation.contents = newContents
        case .modifyColor(let annotation, _, let newColor, _):
            annotation.color = newColor
        case .rotatePage(let page, _, let newRotation):
            page.rotation = newRotation
        }
    }
}

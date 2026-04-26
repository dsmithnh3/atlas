//
//  UnifiedSearchManager.swift
//  Atlas
//
//  Context-aware search: Cmd+F for focused pane, Cmd+Shift+F for both
//

import Foundation
import Observation

@Observable
class UnifiedSearchManager {
    enum FocusedPane {
        case pdf
        case map
    }

    var focusedPane: FocusedPane = .pdf
    var isSearchingMap: Bool = false
    var isSearchingPDF: Bool = false
    var isSearchingBoth: Bool = false

    /// Cmd+F — search whichever pane has focus
    func activateContextSearch() {
        switch focusedPane {
        case .pdf:
            isSearchingPDF = true
            isSearchingMap = false
        case .map:
            isSearchingMap = true
            isSearchingPDF = false
        }
        isSearchingBoth = false
    }

    /// Cmd+Shift+F — search both panes
    func activateUnifiedSearch() {
        isSearchingPDF = true
        isSearchingMap = true
        isSearchingBoth = true
    }

    func dismissSearch() {
        isSearchingPDF = false
        isSearchingMap = false
        isSearchingBoth = false
    }
}

import Foundation

// Lenient conversion from raw String to typed enum, with caller-chosen
// fallback. LLM responses sometimes invent values outside our enum
// (e.g. "hypothesis" instead of one of the 10 ConceptType cases), so
// a strict Codable decode on the enum directly would fail the whole
// extraction. The fallback is context-dependent — a top-level concept
// defaults to `.concept`, a nested entity to `.definition` — which is
// why this lives at the call site rather than on the enum itself.
extension String {
    func asConceptType(default fallback: ConceptType = .concept) -> ConceptType {
        ConceptType(rawValue: self) ?? fallback
    }

    func asEdgeType(default fallback: EdgeType = .sameTopic) -> EdgeType {
        EdgeType(rawValue: self) ?? fallback
    }
}

//
//  PromptTemplates.swift
//  Atlas
//
//  All LLM prompts for concept extraction, edge proposal, summarization, and Q&A
//

import Foundation

enum PromptTemplates {

    // MARK: - Hierarchical Concept Extraction

    static func conceptExtraction(text: String, context: ExtractionContext) -> String {
        let existingList = context.existingConcepts.isEmpty
            ? "None yet."
            : context.existingConcepts.joined(separator: ", ")

        let outlineHints = context.outlineHints.isEmpty
            ? ""
            : "\nDocument outline hints: \(context.outlineHints.joined(separator: " > "))"

        return """
        You are a concept map extraction system following Novak's methodology. Analyze the following text from "\(context.documentTitle)" (pages \(context.pageRange.lowerBound + 1)-\(context.pageRange.upperBound)) and extract a hierarchical concept map.
        \(outlineHints)

        Already extracted concepts (do not duplicate): \(existingList)

        ## Core Principle

        A concept map is a network of PROPOSITIONS. Each proposition is a triple: Concept A —[linking phrase]→ Concept B that reads as a meaningful sentence. For example: "Glycolysis" —[produces]→ "Pyruvate" reads as "Glycolysis produces Pyruvate."

        ## Extraction Rules

        1. Identify 5-6 TOP THEMES (hierarchyLevel 0) — these are the broadest ideas or processes in the text. Label them as short readable noun phrases (2-6 words).

        2. For each theme, identify 3-8 SUB-CONCEPTS (hierarchyLevel 1+) — these are more specific ideas that fall under a theme. Each sub-concept must specify its parent theme via subtopicOf.

        3. Every concept (theme or sub-concept) MUST have a textSpan that is an EXACT verbatim quote from the text. If you cannot find an exact quote, do not include that concept.

        4. Propose edges between concepts. Each edge MUST have a linkingPhrase — a short verb phrase (1-4 words MAX) that makes "sourceLabel [linkingPhrase] targetLabel" read as a grammatical sentence. Good: "produces", "requires", "inhibits", "is a type of". Bad: "is far less efficient than aerobic respiration in producing" (too long — rephrase as "yields less than").

        5. Do not invent concepts not present in the text. Prefer specific, concrete concepts over vague abstractions.

        6. Concept labels should be readable noun phrases, NOT full sentences. Good: "ATP production", "Krebs cycle enzymes". Bad: "ATP is produced by oxidative phosphorylation".

        ## JSON Schema

        EVERY field below is REQUIRED. Do not omit any field. Return ONLY a JSON object with this exact structure:
        {
          "concepts": [
            {
              "label": "Readable Noun Phrase (2-6 words)",
              "type": "concept",
              "summary": "One sentence explaining this concept",
              "textSpan": "exact verbatim quote from text",
              "confidence": 0.95,
              "hierarchyLevel": 0,
              "subtopicOf": null
            },
            {
              "label": "More Specific Sub-concept",
              "type": "concept",
              "summary": "One sentence explanation",
              "textSpan": "exact verbatim quote from text",
              "confidence": 0.9,
              "hierarchyLevel": 1,
              "subtopicOf": "Parent Theme Label"
            }
          ],
          "edges": [
            {
              "sourceLabel": "Concept A",
              "targetLabel": "Concept B",
              "type": "dependsOn",
              "confidence": 0.85,
              "linkingPhrase": "requires"
            }
          ]
        }

        REQUIRED concept fields: label, type, summary, textSpan, confidence, hierarchyLevel, subtopicOf
        REQUIRED edge fields: sourceLabel, targetLabel, type, confidence, linkingPhrase
        hierarchyLevel: 0 = top theme, 1 = direct sub-concept, 2 = sub-sub-concept (rarely needed)
        Edge types: dependsOn, contradicts, exampleOf, defines, extends, cites, sameTopic, partOf, uses
        linkingPhrase: 1-4 word verb phrase making "A [phrase] B" a readable sentence

        Return valid JSON only, no markdown formatting.

        TEXT:
        \(text)
        """
    }

    // MARK: - Edge Proposal

    static func edgeProposal(concepts: [String], context: String) -> String {
        return """
        Given these concepts: \(concepts.joined(separator: ", "))

        And this context text:
        \(context)

        Propose relationships (edges) between the concepts. Do NOT propose edges between a concept and its own child entities — those containment relationships are already captured.

        Only propose edges between:
        - Two concepts (cross-topic relationships)
        - Two entities that belong to different concepts
        - An entity and a concept it relates to (other than its parent)

        Return ONLY a JSON array:
        [
          {
            "sourceLabel": "...",
            "targetLabel": "...",
            "type": "...",
            "confidence": 0.9
          }
        ]

        Edge types: dependsOn, contradicts, exampleOf, defines, extends, cites, sameTopic, partOf, uses

        Only propose edges you are confident about. Return valid JSON only.
        """
    }

    // MARK: - Semantic Merge Proposal

    static func semanticMergeProposal(
        documentATitle: String,
        documentAConcepts: [(label: String, summary: String?)],
        documentBTitle: String,
        documentBConcepts: [(label: String, summary: String?)]
    ) -> String {
        let formatConcepts: ([(label: String, summary: String?)]) -> String = { concepts in
            concepts.map { c in
                if let s = c.summary { return "- \(c.label): \(s)" }
                return "- \(c.label)"
            }.joined(separator: "\n")
        }

        return """
        You are analyzing two documents to find overlapping concepts between them.

        Document A: "\(documentATitle)"
        Concepts:
        \(formatConcepts(documentAConcepts))

        Document B: "\(documentBTitle)"
        Concepts:
        \(formatConcepts(documentBConcepts))

        Identify which concepts from Document A and Document B refer to the same or closely related topic, even if they use different terminology, abbreviations, or phrasings. Consider:
        - Synonyms and alternative names (e.g., "Neural Networks" ↔ "Deep Learning Architectures")
        - Abbreviations (e.g., "NN" ↔ "Neural Network")
        - Specificity differences (e.g., "Optimization" ↔ "Gradient Descent" — partial overlap)
        - Domain-equivalent terms (e.g., "Loss Function" ↔ "Cost Function")

        Return ONLY a JSON array of matches:
        [
          {
            "labelA": "concept label from Document A",
            "labelB": "concept label from Document B",
            "confidence": 0.85,
            "reason": "Brief explanation of why these are the same/related",
            "mergeType": "exactMatch|semanticEquivalent|partialOverlap"
          }
        ]

        - exactMatch: clearly the same concept, just different wording
        - semanticEquivalent: same underlying idea, different framing
        - partialOverlap: one is a subset or special case of the other

        Only propose matches you are confident about (confidence > 0.6). Return valid JSON only.
        """
    }

    // MARK: - Summarization

    static func summarize(conceptLabel: String, sourceText: String) -> String {
        return """
        Summarize the concept "\(conceptLabel)" based on this source text in 1-2 clear sentences suitable for a knowledge map node. Be concise and precise.

        Source text:
        \(sourceText)
        """
    }

    // MARK: - Question Answering

    static func questionAnswer(question: String, context: String) -> String {
        return """
        Answer the following question based on the provided document context. Cite specific passages.

        Return a JSON object:
        {
          "answer": "Your answer here",
          "citations": [
            {"text": "exact quote from context", "pageIndex": 5}
          ]
        }

        Question: \(question)

        Context:
        \(context)

        Return valid JSON only.
        """
    }
}

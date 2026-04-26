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
        You are a knowledge extraction system. Analyze the following text from "\(context.documentTitle)" (pages \(context.pageRange.lowerBound + 1)-\(context.pageRange.upperBound)) and extract a two-level hierarchy of knowledge.
        \(outlineHints)

        Already extracted concepts (do not duplicate): \(existingList)

        ## Extraction Rules

        1. First, identify 3-8 high-level CONCEPTS — these are the major themes, topics, or ideas discussed in the text. Think of these as the chapter headings of understanding.

        2. For each concept, identify 1-5 ENTITIES — these are specific things within that concept: definitions, techniques, people, formulas, examples, datasets, or results that belong under that concept.

        3. Every concept and entity MUST have a textSpan that is an EXACT verbatim quote from the text — copy it character-for-character. If you cannot find an exact quote, do not include that item.

        4. Do not invent items not present in the text. Prefer specific, meaningful items over vague ones.

        5. Also propose edges (relationships) between concepts and between entities of different concepts. Do NOT propose edges between a concept and its own entities — those containment relationships are implicit.

        ## JSON Schema

        Return ONLY a JSON object with this exact structure:
        {
          "concepts": [
            {
              "label": "Short Name (2-5 words)",
              "level": "concept",
              "type": "concept|theorem|method|claim",
              "summary": "One sentence description",
              "textSpan": "exact verbatim quote from text where this topic is discussed",
              "confidence": 0.95,
              "entities": [
                {
                  "label": "Specific Entity Name",
                  "level": "entity",
                  "type": "definition|example|person|dataset|result|equation",
                  "parentLabel": "Short Name (2-5 words)",
                  "summary": "One sentence description",
                  "textSpan": "exact verbatim quote from text",
                  "confidence": 0.9
                }
              ]
            }
          ],
          "edges": [
            {
              "sourceLabel": "...",
              "targetLabel": "...",
              "type": "dependsOn|contradicts|exampleOf|defines|extends|cites|sameTopic|partOf|uses",
              "confidence": 0.85
            }
          ]
        }

        Concept types: concept, theorem, method, claim
        Entity types: definition, example, person, dataset, result, equation
        Edge types: dependsOn, contradicts, exampleOf, defines, extends, cites, sameTopic, partOf, uses

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

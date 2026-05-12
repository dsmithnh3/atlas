//
//  ClaudeBackend.swift
//  Atlas
//
//  Anthropic Claude API backend via URLSession
//

import Foundation
import os.log

private let log = AtlasLogger.ai

final class ClaudeBackend: AtlasModel, @unchecked Sendable {
    let displayName = "Anthropic Claude"
    let modelIdentifier: String
    private let apiKey: String
    private let baseURL: String
    private let session: URLSession

    var isAvailable: Bool { !apiKey.isEmpty }

    init(apiKey: String, model: String = "claude-sonnet-4-5-20250514", baseURL: String = "https://api.anthropic.com") {
        self.apiKey = apiKey
        self.modelIdentifier = model
        self.baseURL = baseURL
        self.session = URLSession.shared
    }

    // MARK: - AtlasModel

    func extractConcepts(from text: String, context: ExtractionContext) async throws -> [RawConcept] {
        log.info("[Claude] extractConcepts: prompt \(text.count) chars")
        let prompt = PromptTemplates.conceptExtraction(text: text, context: context)
        let response = try await sendMessage(prompt)
        do {
            let parsed = try parseExtractionResponse(response)
            log.info("[Claude] Parsed \(parsed.concepts.count) concepts, \(parsed.edges.count) edges from response")
            return parsed.concepts
        } catch {
            log.error("[Claude] Failed to parse extraction response: \(error)")
            log.error("[Claude] Raw response (first 500 chars): \(String(response.prefix(500)))")
            throw error
        }
    }

    func proposeEdges(between concepts: [String], context: String) async throws -> [RawEdge] {
        log.info("[Claude] proposeEdges for \(concepts.count) concepts")
        let prompt = PromptTemplates.edgeProposal(concepts: concepts, context: context)
        let response = try await sendMessage(prompt)
        do {
            let edges = try parseEdgesResponse(response)
            log.info("[Claude] Parsed \(edges.count) edges")
            return edges
        } catch {
            log.error("[Claude] Failed to parse edges response: \(error)")
            log.error("[Claude] Raw response (first 500 chars): \(String(response.prefix(500)))")
            throw error
        }
    }

    func summarizeConcept(_ label: String, sourceText: String) async throws -> String {
        log.info("[Claude] summarizeConcept: \(label)")
        let prompt = PromptTemplates.summarize(conceptLabel: label, sourceText: sourceText)
        return try await sendMessage(prompt)
    }

    func answerQuestion(_ question: String, context: String) async throws -> AnswerWithCitations {
        log.info("[Claude] answerQuestion: \(question.prefix(80))")
        let prompt = PromptTemplates.questionAnswer(question: question, context: context)
        let response = try await sendMessage(prompt)
        return try parseAnswerResponse(response)
    }

    func proposeMerges(
        documentAConcepts: [(label: String, summary: String?)],
        documentBConcepts: [(label: String, summary: String?)]
    ) async throws -> [RawMergeProposal] {
        log.info("[Claude] proposeMerges: \(documentAConcepts.count) vs \(documentBConcepts.count) concepts")
        let prompt = PromptTemplates.semanticMergeProposal(
            documentATitle: "Document A",
            documentAConcepts: documentAConcepts,
            documentBTitle: "Document B",
            documentBConcepts: documentBConcepts
        )
        let response = try await sendMessage(prompt)
        let cleaned = extractJSON(from: response)
        guard let data = cleaned.data(using: .utf8) else {
            log.warning("[Claude] proposeMerges: empty data after JSON extraction")
            return []
        }
        let merges = (try? JSONDecoder().decode([RawMergeProposal].self, from: data)) ?? []
        log.info("[Claude] proposeMerges: \(merges.count) merge proposals")
        return merges
    }

    func generateRawResponse(prompt: String) async throws -> String {
        try await sendMessage(prompt)
    }

    // MARK: - HTTP

    private func sendMessage(_ content: String) async throws -> String {
        guard isAvailable else {
            log.error("[Claude] No API key configured")
            throw AIError.noAPIKey
        }

        log.info("[Claude] POST \(self.baseURL)/v1/messages (prompt: \(content.count) chars, model: \(self.modelIdentifier))")

        let url = URL(string: "\(baseURL)/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": modelIdentifier,
            "max_tokens": 4096,
            "messages": [
                ["role": "user", "content": content]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            log.error("[Claude] Response is not HTTPURLResponse")
            throw AIError.invalidResponse
        }

        log.info("[Claude] HTTP \(httpResponse.statusCode), \(data.count) bytes")

        guard httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            log.error("[Claude] HTTP error \(httpResponse.statusCode): \(String(message.prefix(300)))")
            throw AIError.httpError(statusCode: httpResponse.statusCode, message: message)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let contentArray = json?["content"] as? [[String: Any]],
              let firstBlock = contentArray.first,
              let text = firstBlock["text"] as? String else {
            let raw = String(data: data, encoding: .utf8) ?? "<binary>"
            log.error("[Claude] Could not parse response structure. Raw (first 500): \(String(raw.prefix(500)))")
            throw AIError.invalidResponse
        }

        log.info("[Claude] Got text response: \(text.count) chars")
        log.debug("[Claude] Response preview: \(String(text.prefix(200)))")
        return text
    }

    // MARK: - Parsing

    private func parseExtractionResponse(_ text: String) throws -> ExtractionResponse {
        let cleaned = extractJSON(from: text)
        guard let data = cleaned.data(using: .utf8) else { throw AIError.decodingError("Invalid UTF8") }
        do {
            return try JSONDecoder().decode(ExtractionResponse.self, from: data)
        } catch {
            throw AIError.decodingError(error.localizedDescription)
        }
    }

    private func parseEdgesResponse(_ text: String) throws -> [RawEdge] {
        let cleaned = extractJSON(from: text)
        guard let data = cleaned.data(using: .utf8) else { throw AIError.decodingError("Invalid UTF8") }
        do {
            return try JSONDecoder().decode([RawEdge].self, from: data)
        } catch {
            // Try wrapping in extraction response
            if let response = try? JSONDecoder().decode(ExtractionResponse.self, from: data) {
                return response.edges
            }
            throw AIError.decodingError(error.localizedDescription)
        }
    }

    private func parseAnswerResponse(_ text: String) throws -> AnswerWithCitations {
        let cleaned = extractJSON(from: text)
        guard let data = cleaned.data(using: .utf8) else { throw AIError.decodingError("Invalid UTF8") }
        do {
            return try JSONDecoder().decode(AnswerWithCitations.self, from: data)
        } catch {
            // Fallback: return raw text as answer with no citations
            return AnswerWithCitations(answer: text, citations: [])
        }
    }

    private func extractJSON(from text: String) -> String {
        JSONRepair.cleanAndRepair(text)
    }
}

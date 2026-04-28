//
//  OpenAIBackend.swift
//  Atlas
//
//  OpenAI-compatible API backend (works with OpenAI, Ollama, LM Studio)
//

import Foundation
import os.log

private let log = AtlasLogger.ai

final class OpenAIBackend: AtlasModel, @unchecked Sendable {
    let displayName: String
    let modelIdentifier: String
    private let apiKey: String
    private let baseURL: String
    private let session: URLSession

    var isAvailable: Bool { !apiKey.isEmpty || baseURL.contains("localhost") }

    init(
        apiKey: String,
        model: String = "gpt-4o",
        baseURL: String = "https://api.openai.com",
        displayName: String = "OpenAI"
    ) {
        self.apiKey = apiKey
        self.modelIdentifier = model
        self.baseURL = baseURL
        self.displayName = displayName
        self.session = URLSession.shared
    }

    // MARK: - AtlasModel

    func extractConcepts(from text: String, context: ExtractionContext) async throws -> [RawConcept] {
        log.info("[OpenAI] extractConcepts: prompt \(text.count) chars")
        let prompt = PromptTemplates.conceptExtraction(text: text, context: context)
        let response = try await sendChatCompletion(prompt)
        do {
            let parsed = try parseExtractionResponse(response)
            log.info("[OpenAI] Parsed \(parsed.concepts.count) concepts, \(parsed.edges.count) edges from response")
            return parsed.concepts
        } catch {
            log.error("[OpenAI] Failed to parse extraction response: \(error)")
            log.error("[OpenAI] Raw response (first 500 chars): \(String(response.prefix(500)))")
            throw error
        }
    }

    func proposeEdges(between concepts: [String], context: String) async throws -> [RawEdge] {
        log.info("[OpenAI] proposeEdges for \(concepts.count) concepts")
        let prompt = PromptTemplates.edgeProposal(concepts: concepts, context: context)
        let response = try await sendChatCompletion(prompt)
        do {
            let edges = try parseEdgesResponse(response)
            log.info("[OpenAI] Parsed \(edges.count) edges")
            return edges
        } catch {
            log.error("[OpenAI] Failed to parse edges response: \(error)")
            log.error("[OpenAI] Raw response (first 500 chars): \(String(response.prefix(500)))")
            throw error
        }
    }

    func summarizeConcept(_ label: String, sourceText: String) async throws -> String {
        log.info("[OpenAI] summarizeConcept: \(label)")
        let prompt = PromptTemplates.summarize(conceptLabel: label, sourceText: sourceText)
        return try await sendChatCompletion(prompt)
    }

    func answerQuestion(_ question: String, context: String) async throws -> AnswerWithCitations {
        log.info("[OpenAI] answerQuestion: \(question.prefix(80))")
        let prompt = PromptTemplates.questionAnswer(question: question, context: context)
        let response = try await sendChatCompletion(prompt)
        return try parseAnswerResponse(response)
    }

    func proposeMerges(
        documentAConcepts: [(label: String, summary: String?)],
        documentBConcepts: [(label: String, summary: String?)]
    ) async throws -> [RawMergeProposal] {
        log.info("[OpenAI] proposeMerges: \(documentAConcepts.count) vs \(documentBConcepts.count) concepts")
        let prompt = PromptTemplates.semanticMergeProposal(
            documentATitle: "Document A",
            documentAConcepts: documentAConcepts,
            documentBTitle: "Document B",
            documentBConcepts: documentBConcepts
        )
        let response = try await sendChatCompletion(prompt)
        let cleaned = extractJSON(from: response)
        guard let data = cleaned.data(using: .utf8) else {
            log.warning("[OpenAI] proposeMerges: empty data after JSON extraction")
            return []
        }
        let merges = (try? JSONDecoder().decode([RawMergeProposal].self, from: data)) ?? []
        log.info("[OpenAI] proposeMerges: \(merges.count) merge proposals")
        return merges
    }

    // MARK: - HTTP

    private func sendChatCompletion(_ content: String) async throws -> String {
        log.info("[OpenAI] POST \(self.baseURL)/v1/chat/completions (prompt: \(content.count) chars, model: \(self.modelIdentifier))")

        let url = URL(string: "\(baseURL)/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = [
            "model": modelIdentifier,
            "messages": [
                ["role": "user", "content": content]
            ],
            "max_tokens": 4096,
            "temperature": 0.1
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            log.error("[OpenAI] Response is not HTTPURLResponse")
            throw AIError.invalidResponse
        }

        log.info("[OpenAI] HTTP \(httpResponse.statusCode), \(data.count) bytes")

        guard httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            log.error("[OpenAI] HTTP error \(httpResponse.statusCode): \(String(message.prefix(300)))")
            throw AIError.httpError(statusCode: httpResponse.statusCode, message: message)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let text = message["content"] as? String else {
            let raw = String(data: data, encoding: .utf8) ?? "<binary>"
            log.error("[OpenAI] Could not parse response structure. Raw (first 500): \(String(raw.prefix(500)))")
            throw AIError.invalidResponse
        }

        log.info("[OpenAI] Got text response: \(text.count) chars")
        log.debug("[OpenAI] Response preview: \(String(text.prefix(200)))")
        return text
    }

    // MARK: - Parsing (shared with ClaudeBackend pattern)

    private func parseExtractionResponse(_ text: String) throws -> ExtractionResponse {
        let cleaned = extractJSON(from: text)
        guard let data = cleaned.data(using: .utf8) else { throw AIError.decodingError("Invalid UTF8") }
        return try JSONDecoder().decode(ExtractionResponse.self, from: data)
    }

    private func parseEdgesResponse(_ text: String) throws -> [RawEdge] {
        let cleaned = extractJSON(from: text)
        guard let data = cleaned.data(using: .utf8) else { throw AIError.decodingError("Invalid UTF8") }
        do {
            return try JSONDecoder().decode([RawEdge].self, from: data)
        } catch {
            if let response = try? JSONDecoder().decode(ExtractionResponse.self, from: data) {
                return response.edges
            }
            throw AIError.decodingError(error.localizedDescription)
        }
    }

    private func parseAnswerResponse(_ text: String) throws -> AnswerWithCitations {
        let cleaned = extractJSON(from: text)
        guard let data = cleaned.data(using: .utf8) else {
            return AnswerWithCitations(answer: text, citations: [])
        }
        do {
            return try JSONDecoder().decode(AnswerWithCitations.self, from: data)
        } catch {
            return AnswerWithCitations(answer: text, citations: [])
        }
    }

    private func extractJSON(from text: String) -> String {
        JSONRepair.cleanAndRepair(text)
    }
}

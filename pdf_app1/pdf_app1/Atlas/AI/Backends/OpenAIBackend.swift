//
//  OpenAIBackend.swift
//  Atlas
//
//  OpenAI-compatible API backend (works with OpenAI, Ollama, LM Studio)
//

import Foundation
import os.log

private let log = AtlasLogger.ai

final class OpenAIBackend: LLMBackend, @unchecked Sendable {
    let displayName: String
    let modelIdentifier: String
    let logTag = "OpenAI"
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

    func transport(prompt: String) async throws -> String {
        guard isAvailable else {
            log.error("[OpenAI] No API key configured (and not localhost)")
            throw AIError.noAPIKey
        }

        log.info("[OpenAI] POST \(self.baseURL)/v1/chat/completions (prompt: \(prompt.count) chars, model: \(self.modelIdentifier))")

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
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 8192,
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

        let parsed: OpenAIResponse
        do {
            parsed = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        } catch {
            let raw = String(data: data, encoding: .utf8) ?? "<binary>"
            log.error("[OpenAI] Could not parse response structure: \(error). Raw (first 500): \(String(raw.prefix(500)))")
            throw AIError.invalidResponse
        }
        guard let text = parsed.choices.first?.message.content else {
            let raw = String(data: data, encoding: .utf8) ?? "<binary>"
            log.error("[OpenAI] Empty choices. Raw (first 500): \(String(raw.prefix(500)))")
            throw AIError.invalidResponse
        }

        log.info("[OpenAI] Got text response: \(text.count) chars")
        log.debug("[OpenAI] Response preview: \(String(text.prefix(200)))")
        return text
    }
}

private struct OpenAIResponse: Decodable {
    let choices: [Choice]
    struct Choice: Decodable {
        let message: Message
    }
    struct Message: Decodable {
        let content: String
    }
}

//
//  ClaudeBackend.swift
//  Atlas
//
//  Anthropic Claude API backend via URLSession
//

import Foundation
import os.log

private let log = AtlasLogger.ai

final class ClaudeBackend: LLMBackend, @unchecked Sendable {
    let displayName = "Anthropic Claude"
    let modelIdentifier: String
    let logTag = "Claude"
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

    func transport(prompt: String) async throws -> String {
        guard isAvailable else {
            log.error("[Claude] No API key configured")
            throw AIError.noAPIKey
        }

        log.info("[Claude] POST \(self.baseURL)/v1/messages (prompt: \(prompt.count) chars, model: \(self.modelIdentifier))")

        let url = URL(string: "\(baseURL)/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": modelIdentifier,
            "max_tokens": 8192,
            "temperature": 0.1,
            "messages": [
                ["role": "user", "content": prompt]
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

        let parsed: ClaudeResponse
        do {
            parsed = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        } catch {
            let raw = String(data: data, encoding: .utf8) ?? "<binary>"
            log.error("[Claude] Could not parse response structure: \(error). Raw (first 500): \(String(raw.prefix(500)))")
            throw AIError.invalidResponse
        }
        guard let text = parsed.content.first?.text else {
            let raw = String(data: data, encoding: .utf8) ?? "<binary>"
            log.error("[Claude] Empty content array. Raw (first 500): \(String(raw.prefix(500)))")
            throw AIError.invalidResponse
        }

        log.info("[Claude] Got text response: \(text.count) chars")
        log.debug("[Claude] Response preview: \(String(text.prefix(200)))")
        return text
    }
}

private struct ClaudeResponse: Decodable {
    let content: [ContentBlock]
    struct ContentBlock: Decodable {
        let text: String
    }
}

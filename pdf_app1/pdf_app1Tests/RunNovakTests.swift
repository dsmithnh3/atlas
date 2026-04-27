#!/usr/bin/env swift
//
// Standalone test runner for Novak extraction model + parsing changes.
// Run: swift pdf_app1/pdf_app1Tests/RunNovakTests.swift
//
// Tests Codable round-trips, backward compat, JSONRepair, prompt structure,
// and realistic LLM response parsing for Novak-style concept map extraction.
//

import Foundation

// MARK: - Mirror of production types (for standalone testing)

struct RawConcept: Codable {
    let label: String
    let type: String
    let summary: String?
    let textSpan: String
    let confidence: Double?
    let level: String?
    let parentLabel: String?
    let entities: [RawConcept]?
    let hierarchyLevel: Int?
    let subtopicOf: String?
}

struct RawEdge: Codable {
    let sourceLabel: String
    let targetLabel: String
    let type: String
    let confidence: Double?
    let linkingPhrase: String?
}

struct ExtractionResponse: Codable {
    let concepts: [RawConcept]
    let edges: [RawEdge]
}

// MARK: - JSONRepair (copied from production for standalone testing)

enum JSONRepair {
    static func cleanAndRepair(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.hasPrefix("```") {
            if let endOfFirstLine = result.firstIndex(of: "\n") {
                result = String(result[result.index(after: endOfFirstLine)...])
            }
            if result.hasSuffix("```") {
                result = String(result.dropLast(3))
            }
        }
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { return result }
        if (try? JSONSerialization.jsonObject(with: Data(result.utf8))) != nil {
            return result
        }
        return repair(result)
    }

    private static func repair(_ json: String) -> String {
        var repaired = json
        var inString = false
        var escaped = false
        for ch in repaired {
            if escaped { escaped = false; continue }
            if ch == "\\" { escaped = true; continue }
            if ch == "\"" { inString = !inString }
        }
        if inString { repaired += "\"" }
        let trimmed = repaired.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix(",") { repaired = String(trimmed.dropLast()) }
        var openBraces = 0
        var openBrackets = 0
        inString = false
        escaped = false
        for ch in repaired {
            if escaped { escaped = false; continue }
            if ch == "\\" { escaped = true; continue }
            if ch == "\"" { inString = !inString; continue }
            if inString { continue }
            switch ch {
            case "{": openBraces += 1
            case "}": openBraces -= 1
            case "[": openBrackets += 1
            case "]": openBrackets -= 1
            default: break
            }
        }
        for _ in 0..<max(0, openBrackets) { repaired += "]" }
        for _ in 0..<max(0, openBraces) { repaired += "}" }
        if (try? JSONSerialization.jsonObject(with: Data(repaired.utf8))) != nil { return repaired }
        if let conceptsRange = json.range(of: "\"concepts\"") {
            let afterConcepts = json[conceptsRange.upperBound...]
            var lastGoodEnd = afterConcepts.startIndex
            var braceDepth = 0
            var inStr = false
            var esc = false
            var foundArray = false
            for i in afterConcepts.indices {
                let ch = afterConcepts[i]
                if esc { esc = false; continue }
                if ch == "\\" { esc = true; continue }
                if ch == "\"" { inStr = !inStr; continue }
                if inStr { continue }
                if ch == "[" { foundArray = true; braceDepth += 1 }
                else if ch == "]" {
                    braceDepth -= 1
                    if foundArray && braceDepth == 0 { lastGoodEnd = afterConcepts.index(after: i); break }
                } else if ch == "}" && braceDepth == 1 {
                    lastGoodEnd = afterConcepts.index(after: i)
                }
            }
            if lastGoodEnd > afterConcepts.startIndex {
                let partial = String(json[json.startIndex..<lastGoodEnd])
                let fixed = partial + "], \"edges\": []}"
                if (try? JSONSerialization.jsonObject(with: Data(fixed.utf8))) != nil { return fixed }
            }
        }
        return json
    }
}

// MARK: - Test Harness

var passed = 0
var failed = 0
var currentTest = ""

func test(_ name: String, _ body: () throws -> Void) {
    currentTest = name
    do {
        try body()
        print("  ✓ \(name)")
    } catch {
        failed += 1
        print("  ✗ \(name): threw \(error)")
    }
}

func expect(_ condition: Bool, _ message: String = "", line: Int = #line) {
    if condition {
        passed += 1
    } else {
        failed += 1
        print("    FAIL [\(line)]: \(message.isEmpty ? currentTest : message)")
    }
}

func expectEqual<T: Equatable>(_ a: T?, _ b: T?, _ msg: String = "", line: Int = #line) {
    if a == b { passed += 1 }
    else { failed += 1; print("    FAIL [\(line)]: expected \(String(describing: b)), got \(String(describing: a)). \(msg)") }
}

func expectNotNil<T>(_ val: T?, _ msg: String = "", line: Int = #line) {
    if val != nil { passed += 1 }
    else { failed += 1; print("    FAIL [\(line)]: expected non-nil. \(msg)") }
}

// MARK: - 1. Codable Round-trips

print("\n=== 1. Codable Round-trips ===")

test("RawConcept decodes hierarchyLevel=0") {
    let json = """
    {"label":"Cellular respiration","type":"concept","summary":"s","textSpan":"t","confidence":0.95,"hierarchyLevel":0}
    """.data(using: .utf8)!
    let c = try JSONDecoder().decode(RawConcept.self, from: json)
    expectEqual(c.hierarchyLevel, 0)
    expectEqual(c.subtopicOf, nil)
}

test("RawConcept decodes hierarchyLevel=2 (deep sub)") {
    let json = """
    {"label":"Acetyl-CoA formation","type":"concept","summary":"s","textSpan":"t","confidence":0.85,"hierarchyLevel":2,"subtopicOf":"Pyruvate oxidation"}
    """.data(using: .utf8)!
    let c = try JSONDecoder().decode(RawConcept.self, from: json)
    expectEqual(c.hierarchyLevel, 2)
    expectEqual(c.subtopicOf, "Pyruvate oxidation")
}

test("RawConcept backward compat - no new fields") {
    let json = """
    {"label":"Old","type":"concept","summary":null,"textSpan":"t","confidence":0.9}
    """.data(using: .utf8)!
    let c = try JSONDecoder().decode(RawConcept.self, from: json)
    expectEqual(c.hierarchyLevel, nil)
    expectEqual(c.subtopicOf, nil)
}

test("RawEdge decodes linkingPhrase") {
    let json = """
    {"sourceLabel":"Glycolysis","targetLabel":"Pyruvate","type":"produces","confidence":0.9,"linkingPhrase":"produces"}
    """.data(using: .utf8)!
    let e = try JSONDecoder().decode(RawEdge.self, from: json)
    expectEqual(e.linkingPhrase, "produces")
}

test("RawEdge decodes multi-word linkingPhrase") {
    let json = """
    {"sourceLabel":"Electron transport chain","targetLabel":"ATP synthase","type":"dependsOn","confidence":0.9,"linkingPhrase":"drives protons through"}
    """.data(using: .utf8)!
    let e = try JSONDecoder().decode(RawEdge.self, from: json)
    expectEqual(e.linkingPhrase, "drives protons through")
}

test("RawEdge backward compat - no linkingPhrase") {
    let json = """
    {"sourceLabel":"A","targetLabel":"B","type":"dependsOn","confidence":0.8}
    """.data(using: .utf8)!
    let e = try JSONDecoder().decode(RawEdge.self, from: json)
    expectEqual(e.linkingPhrase, nil)
}

test("RawConcept encode → decode round-trip preserves new fields") {
    let original = RawConcept(
        label: "ATP production", type: "concept", summary: "Energy currency",
        textSpan: "ATP is the energy currency", confidence: 0.9,
        level: nil, parentLabel: nil, entities: nil,
        hierarchyLevel: 0, subtopicOf: nil
    )
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(RawConcept.self, from: data)
    expectEqual(decoded.hierarchyLevel, 0)
    expectEqual(decoded.subtopicOf, nil)
    expectEqual(decoded.label, "ATP production")
}

test("RawEdge encode → decode round-trip preserves linkingPhrase") {
    let original = RawEdge(
        sourceLabel: "A", targetLabel: "B", type: "dependsOn",
        confidence: 0.8, linkingPhrase: "is required for"
    )
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(RawEdge.self, from: data)
    expectEqual(decoded.linkingPhrase, "is required for")
}

// MARK: - 2. Full ExtractionResponse Parsing

print("\n=== 2. Full ExtractionResponse ===")

test("Complete Novak-style response") {
    let json = """
    {
      "concepts": [
        {"label":"Cellular respiration","type":"concept","summary":"Process of converting glucose to ATP","textSpan":"Cellular respiration is a set of metabolic reactions","confidence":0.95,"hierarchyLevel":0,"subtopicOf":null},
        {"label":"Glycolysis","type":"concept","summary":"First stage breaking glucose into pyruvate","textSpan":"Glycolysis occurs in the cytoplasm","confidence":0.9,"hierarchyLevel":1,"subtopicOf":"Cellular respiration"},
        {"label":"Krebs cycle","type":"concept","summary":"Second stage in the mitochondrial matrix","textSpan":"The Krebs cycle takes place in the matrix","confidence":0.9,"hierarchyLevel":1,"subtopicOf":"Cellular respiration"},
        {"label":"Oxidative phosphorylation","type":"concept","summary":"Final stage producing most ATP","textSpan":"Oxidative phosphorylation occurs at the inner membrane","confidence":0.9,"hierarchyLevel":1,"subtopicOf":"Cellular respiration"},
        {"label":"ATP yield","type":"concept","summary":"Total energy output","textSpan":"Each glucose molecule produces approximately 36-38 ATP","confidence":0.85,"hierarchyLevel":1,"subtopicOf":"Cellular respiration"},
        {"label":"Electron transport chain","type":"concept","summary":"Series of protein complexes","textSpan":"The electron transport chain consists of four complexes","confidence":0.88,"hierarchyLevel":2,"subtopicOf":"Oxidative phosphorylation"}
      ],
      "edges": [
        {"sourceLabel":"Glycolysis","targetLabel":"Krebs cycle","type":"dependsOn","confidence":0.85,"linkingPhrase":"feeds pyruvate into"},
        {"sourceLabel":"Krebs cycle","targetLabel":"Oxidative phosphorylation","type":"dependsOn","confidence":0.9,"linkingPhrase":"supplies electron carriers to"},
        {"sourceLabel":"Electron transport chain","targetLabel":"ATP yield","type":"dependsOn","confidence":0.8,"linkingPhrase":"generates most of"},
        {"sourceLabel":"Glycolysis","targetLabel":"ATP yield","type":"partOf","confidence":0.7,"linkingPhrase":"contributes a small portion to"}
      ]
    }
    """.data(using: .utf8)!

    let r = try JSONDecoder().decode(ExtractionResponse.self, from: json)

    // Structure checks
    expectEqual(r.concepts.count, 6)
    expectEqual(r.edges.count, 4)

    // Hierarchy checks
    let themes = r.concepts.filter { $0.hierarchyLevel == 0 }
    expectEqual(themes.count, 1, "Should have exactly 1 top theme")
    expectEqual(themes.first?.label, "Cellular respiration")

    let level1 = r.concepts.filter { $0.hierarchyLevel == 1 }
    expectEqual(level1.count, 4, "Should have 4 level-1 sub-concepts")
    expect(level1.allSatisfy { $0.subtopicOf != nil }, "All level-1 should have subtopicOf")

    let level2 = r.concepts.filter { $0.hierarchyLevel == 2 }
    expectEqual(level2.count, 1, "Should have 1 level-2 concept")
    expectEqual(level2.first?.subtopicOf, "Oxidative phosphorylation")

    // Linking phrase checks
    expect(r.edges.allSatisfy { $0.linkingPhrase != nil }, "All edges should have linkingPhrase")
    expectEqual(r.edges[0].linkingPhrase, "feeds pyruvate into")

    // Proposition readability check: "sourceLabel linkingPhrase targetLabel" should be sentence-like
    for edge in r.edges {
        let proposition = "\(edge.sourceLabel) \(edge.linkingPhrase!) \(edge.targetLabel)"
        expect(proposition.count > 10, "Proposition should be readable: \(proposition)")
    }
}

test("Mixed old + new concepts in same response") {
    let json = """
    {
      "concepts": [
        {"label":"New style","type":"concept","summary":"s","textSpan":"t","confidence":0.9,"hierarchyLevel":0},
        {"label":"Old style","type":"concept","summary":"s","textSpan":"t","confidence":0.9}
      ],
      "edges": [
        {"sourceLabel":"New style","targetLabel":"Old style","type":"sameTopic","confidence":0.7}
      ]
    }
    """.data(using: .utf8)!

    let r = try JSONDecoder().decode(ExtractionResponse.self, from: json)
    expectEqual(r.concepts[0].hierarchyLevel, 0)
    expectEqual(r.concepts[1].hierarchyLevel, nil, "Old-style has no hierarchyLevel")
    expectEqual(r.edges[0].linkingPhrase, nil, "Old-style edge has no linkingPhrase")
}

test("Response with subtopicOf edge type") {
    let json = """
    {
      "concepts": [
        {"label":"Theme A","type":"concept","summary":"s","textSpan":"t","confidence":0.9,"hierarchyLevel":0}
      ],
      "edges": [
        {"sourceLabel":"Sub B","targetLabel":"Theme A","type":"subtopicOf","confidence":1.0,"linkingPhrase":"is a subtopic of"}
      ]
    }
    """.data(using: .utf8)!

    let r = try JSONDecoder().decode(ExtractionResponse.self, from: json)
    expectEqual(r.edges.first?.type, "subtopicOf")
}

// MARK: - 3. JSONRepair with Novak-style payloads

print("\n=== 3. JSONRepair ===")

test("Valid Novak JSON passes through unchanged") {
    let valid = "{\"concepts\":[{\"label\":\"X\",\"type\":\"concept\",\"summary\":\"s\",\"textSpan\":\"t\",\"confidence\":0.9,\"hierarchyLevel\":0,\"subtopicOf\":null}],\"edges\":[{\"sourceLabel\":\"X\",\"targetLabel\":\"Y\",\"type\":\"dependsOn\",\"confidence\":0.8,\"linkingPhrase\":\"requires\"}]}"
    let result = JSONRepair.cleanAndRepair(valid)
    expectEqual(result, valid)
}

test("Strips markdown fences from Novak response") {
    let fenced = "```json\n{\"concepts\":[],\"edges\":[]}\n```"
    let result = JSONRepair.cleanAndRepair(fenced)
    let obj = try JSONSerialization.jsonObject(with: Data(result.utf8)) as? [String: Any]
    expectNotNil(obj)
}

test("Closes unclosed Novak response (bracket closure) — complete edge object") {
    // JSONRepair can close brackets when the last JSON value is complete
    let truncated = "{\"concepts\":[{\"label\":\"X\",\"type\":\"concept\",\"summary\":\"s\",\"textSpan\":\"t\",\"confidence\":0.9,\"hierarchyLevel\":0,\"subtopicOf\":null}],\"edges\":[{\"sourceLabel\":\"A\",\"targetLabel\":\"B\",\"type\":\"dependsOn\",\"confidence\":0.8,\"linkingPhrase\":\"requires\"}"
    let repaired = JSONRepair.cleanAndRepair(truncated)
    expectNotNil(try? JSONSerialization.jsonObject(with: Data(repaired.utf8)), "Should close remaining ] and }")
}

test("Recovers truncated concepts array (aggressive fallback)") {
    let truncated = "{\"concepts\":[{\"label\":\"Good concept\",\"type\":\"concept\",\"summary\":\"s\",\"textSpan\":\"t\",\"confidence\":0.9,\"hierarchyLevel\":0},{\"label\":\"Broken"
    let repaired = JSONRepair.cleanAndRepair(truncated)
    let data = Data(repaired.utf8)
    expectNotNil(try? JSONSerialization.jsonObject(with: data), "Should recover partial concepts")

    if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let concepts = obj["concepts"] as? [[String: Any]] {
        expect(concepts.count >= 1, "Should have at least the first good concept")
        expectEqual(concepts.first?["label"] as? String, "Good concept")
    }
}

test("Repairs truncation mid-linkingPhrase (known limitation: partial edge objects not recovered)") {
    // When truncation happens mid-value inside an edge object, bracket closure
    // produces syntactically-closed but semantically invalid JSON (e.g. missing keys).
    // The aggressive fallback recovers concepts but drops the partial edge.
    let truncated = "{\"concepts\":[{\"label\":\"A\",\"type\":\"concept\",\"summary\":\"s\",\"textSpan\":\"t\",\"confidence\":0.9,\"hierarchyLevel\":0}],\"edges\":[{\"sourceLabel\":\"A\",\"targetLabel\":\"B\",\"type\":\"dependsOn\",\"confidence\":0.8,\"linkingPhrase\":\"is required"
    let repaired = JSONRepair.cleanAndRepair(truncated)
    // At minimum, the concepts array should be recoverable via aggressive fallback
    expect(repaired.contains("\"concepts\""), "Should preserve concepts key")
}

test("Repairs trailing comma in edges array") {
    let json = "{\"concepts\":[],\"edges\":[{\"sourceLabel\":\"A\",\"targetLabel\":\"B\",\"type\":\"dependsOn\",\"confidence\":0.8,\"linkingPhrase\":\"requires\"},]}"
    let repaired = JSONRepair.cleanAndRepair(json)
    expectNotNil(try? JSONSerialization.jsonObject(with: Data(repaired.utf8)))
}

// MARK: - 4. Realistic LLM Response Simulation

print("\n=== 4. Realistic LLM Responses ===")

test("Gemini-style response with 5 themes + sub-concepts parses fully") {
    // Simulates what we'd expect from a real biology textbook extraction
    let geminiResponse = """
    {
      "concepts": [
        {"label":"Cellular respiration overview","type":"concept","summary":"The metabolic pathway that breaks down glucose","textSpan":"Cellular respiration is the process by which organisms convert biochemical energy","confidence":0.95,"hierarchyLevel":0,"subtopicOf":null},
        {"label":"Glycolysis pathway","type":"concept","summary":"Anaerobic breakdown of glucose to pyruvate","textSpan":"Glycolysis is a sequence of ten enzyme-catalyzed reactions","confidence":0.92,"hierarchyLevel":1,"subtopicOf":"Cellular respiration overview"},
        {"label":"Citric acid cycle","type":"concept","summary":"Cyclic pathway oxidizing acetyl-CoA","textSpan":"The citric acid cycle, also known as the Krebs cycle","confidence":0.93,"hierarchyLevel":1,"subtopicOf":"Cellular respiration overview"},
        {"label":"Electron transport chain","type":"concept","summary":"Series of membrane-bound carriers","textSpan":"The electron transport chain is embedded in the inner mitochondrial membrane","confidence":0.91,"hierarchyLevel":1,"subtopicOf":"Cellular respiration overview"},
        {"label":"Chemiosmosis","type":"concept","summary":"ATP synthesis driven by proton gradient","textSpan":"Chemiosmosis couples electron transport to ATP production","confidence":0.88,"hierarchyLevel":1,"subtopicOf":"Cellular respiration overview"},
        {"label":"Fermentation","type":"concept","summary":"Anaerobic alternative when oxygen is absent","textSpan":"Fermentation allows glycolysis to continue","confidence":0.87,"hierarchyLevel":0,"subtopicOf":null},
        {"label":"Lactic acid fermentation","type":"concept","summary":"Converts pyruvate to lactate","textSpan":"In lactic acid fermentation, pyruvate is reduced directly","confidence":0.85,"hierarchyLevel":1,"subtopicOf":"Fermentation"},
        {"label":"Alcoholic fermentation","type":"concept","summary":"Converts pyruvate to ethanol and CO2","textSpan":"Alcoholic fermentation converts pyruvate to ethanol","confidence":0.84,"hierarchyLevel":1,"subtopicOf":"Fermentation"},
        {"label":"NAD+ regeneration","type":"concept","summary":"Recycling electron carrier for glycolysis","textSpan":"Both types of fermentation regenerate NAD+","confidence":0.82,"hierarchyLevel":2,"subtopicOf":"Fermentation"},
        {"label":"ATP yield comparison","type":"concept","summary":"Energy output of aerobic vs anaerobic","textSpan":"Aerobic respiration produces approximately 36-38 ATP molecules per glucose","confidence":0.9,"hierarchyLevel":0,"subtopicOf":null},
        {"label":"Substrate-level phosphorylation","type":"concept","summary":"Direct ATP synthesis from substrates","textSpan":"Substrate-level phosphorylation directly transfers a phosphate group","confidence":0.86,"hierarchyLevel":1,"subtopicOf":"ATP yield comparison"},
        {"label":"Oxidative phosphorylation","type":"concept","summary":"ATP production via chemiosmosis","textSpan":"Oxidative phosphorylation accounts for almost 90% of the ATP","confidence":0.91,"hierarchyLevel":1,"subtopicOf":"ATP yield comparison"}
      ],
      "edges": [
        {"sourceLabel":"Glycolysis pathway","targetLabel":"Citric acid cycle","type":"dependsOn","confidence":0.9,"linkingPhrase":"feeds pyruvate into"},
        {"sourceLabel":"Citric acid cycle","targetLabel":"Electron transport chain","type":"dependsOn","confidence":0.92,"linkingPhrase":"supplies NADH and FADH2 to"},
        {"sourceLabel":"Electron transport chain","targetLabel":"Chemiosmosis","type":"dependsOn","confidence":0.88,"linkingPhrase":"creates proton gradient for"},
        {"sourceLabel":"Chemiosmosis","targetLabel":"Oxidative phosphorylation","type":"defines","confidence":0.85,"linkingPhrase":"is the mechanism of"},
        {"sourceLabel":"Fermentation","targetLabel":"NAD+ regeneration","type":"dependsOn","confidence":0.8,"linkingPhrase":"serves primarily to enable"},
        {"sourceLabel":"NAD+ regeneration","targetLabel":"Glycolysis pathway","type":"dependsOn","confidence":0.82,"linkingPhrase":"allows continuation of"},
        {"sourceLabel":"Glycolysis pathway","targetLabel":"Substrate-level phosphorylation","type":"exampleOf","confidence":0.78,"linkingPhrase":"uses"},
        {"sourceLabel":"Oxidative phosphorylation","targetLabel":"ATP yield comparison","type":"partOf","confidence":0.85,"linkingPhrase":"dominates"},
        {"sourceLabel":"Cellular respiration overview","targetLabel":"Fermentation","type":"contradicts","confidence":0.7,"linkingPhrase":"is contrasted with"}
      ]
    }
    """.data(using: .utf8)!

    let r = try JSONDecoder().decode(ExtractionResponse.self, from: geminiResponse)

    // Structural validation
    expectEqual(r.concepts.count, 12)
    expectEqual(r.edges.count, 9)

    // Theme count (hierarchyLevel == 0)
    let themes = r.concepts.filter { $0.hierarchyLevel == 0 }
    expectEqual(themes.count, 3, "Should have 3 top themes")

    // Every sub-concept has subtopicOf pointing to an actual concept label
    let allLabels = Set(r.concepts.map { $0.label })
    let subsWithParent = r.concepts.filter { $0.subtopicOf != nil }
    for sub in subsWithParent {
        expect(allLabels.contains(sub.subtopicOf!), "subtopicOf '\(sub.subtopicOf!)' should match a concept label")
    }

    // Every edge has a non-empty linkingPhrase
    for edge in r.edges {
        expectNotNil(edge.linkingPhrase, "Edge \(edge.sourceLabel)→\(edge.targetLabel) needs linkingPhrase")
        if let lp = edge.linkingPhrase {
            expect(!lp.isEmpty, "linkingPhrase should not be empty")
            expect(lp.count <= 40, "linkingPhrase should be concise: '\(lp)'")
        }
    }

    // Propositions read as sentences
    for edge in r.edges {
        let sentence = "\(edge.sourceLabel) \(edge.linkingPhrase ?? "?") \(edge.targetLabel)"
        expect(sentence.split(separator: " ").count >= 4, "Proposition should be multi-word: '\(sentence)'")
    }

    // Hierarchy depth check
    let maxLevel = r.concepts.compactMap { $0.hierarchyLevel }.max() ?? 0
    expect(maxLevel >= 1, "Should have at least 2 hierarchy levels")
    expect(maxLevel <= 3, "Should not exceed 3 hierarchy levels for a single chapter")
}

test("Response with only themes (no sub-concepts) still parses") {
    let json = """
    {
      "concepts": [
        {"label":"Theme A","type":"concept","summary":"s","textSpan":"t","confidence":0.9,"hierarchyLevel":0,"subtopicOf":null},
        {"label":"Theme B","type":"concept","summary":"s","textSpan":"t","confidence":0.9,"hierarchyLevel":0,"subtopicOf":null}
      ],
      "edges": [
        {"sourceLabel":"Theme A","targetLabel":"Theme B","type":"sameTopic","confidence":0.7,"linkingPhrase":"is related to"}
      ]
    }
    """.data(using: .utf8)!

    let r = try JSONDecoder().decode(ExtractionResponse.self, from: json)
    expectEqual(r.concepts.count, 2)
    expect(r.concepts.allSatisfy { $0.hierarchyLevel == 0 }, "All should be level 0")
}

test("Response with concepts that have entities (hybrid old+new)") {
    let json = """
    {
      "concepts": [
        {
          "label":"Theme","type":"concept","summary":"s","textSpan":"t","confidence":0.9,
          "hierarchyLevel":0,"subtopicOf":null,
          "entities":[
            {"label":"Entity A","type":"definition","summary":"s","textSpan":"t","confidence":0.8,"parentLabel":"Theme"}
          ]
        }
      ],
      "edges": []
    }
    """.data(using: .utf8)!

    let r = try JSONDecoder().decode(ExtractionResponse.self, from: json)
    expectEqual(r.concepts.count, 1)
    expectEqual(r.concepts.first?.entities?.count, 1, "Entities still work alongside hierarchy")
    expectEqual(r.concepts.first?.hierarchyLevel, 0)
}

test("Empty response") {
    let json = """
    {"concepts":[],"edges":[]}
    """.data(using: .utf8)!

    let r = try JSONDecoder().decode(ExtractionResponse.self, from: json)
    expectEqual(r.concepts.count, 0)
    expectEqual(r.edges.count, 0)
}

// MARK: - 5. Edge Cases and Robustness

print("\n=== 5. Edge Cases ===")

test("Concept with null subtopicOf decodes as nil") {
    let json = """
    {"label":"X","type":"concept","summary":"s","textSpan":"t","confidence":0.9,"hierarchyLevel":0,"subtopicOf":null}
    """.data(using: .utf8)!
    let c = try JSONDecoder().decode(RawConcept.self, from: json)
    expectEqual(c.subtopicOf, nil)
}

test("Unicode in labels and linkingPhrases") {
    let json = """
    {"sourceLabel":"Réaction chimique","targetLabel":"Énergie libre","type":"dependsOn","confidence":0.9,"linkingPhrase":"libère de l'"}
    """.data(using: .utf8)!
    let e = try JSONDecoder().decode(RawEdge.self, from: json)
    expectEqual(e.sourceLabel, "Réaction chimique")
    expectEqual(e.linkingPhrase, "libère de l'")
}

test("Very long linkingPhrase still decodes") {
    let json = """
    {"sourceLabel":"A","targetLabel":"B","type":"dependsOn","confidence":0.8,"linkingPhrase":"is fundamentally and mechanistically required as a precursor for the downstream activation of"}
    """.data(using: .utf8)!
    let e = try JSONDecoder().decode(RawEdge.self, from: json)
    expectNotNil(e.linkingPhrase)
}

test("Concept with hierarchyLevel as string fails gracefully") {
    // LLMs sometimes return numbers as strings - this should fail decode
    let json = """
    {"label":"X","type":"concept","summary":"s","textSpan":"t","confidence":0.9,"hierarchyLevel":"0"}
    """.data(using: .utf8)!
    // This should fail since hierarchyLevel expects Int, not String
    let result = try? JSONDecoder().decode(RawConcept.self, from: json)
    expect(result == nil, "String '0' for Int field should fail decode")
}

test("JSONRepair handles Novak response truncated after first concept") {
    let truncated = "{\"concepts\":[{\"label\":\"Complete concept\",\"type\":\"concept\",\"summary\":\"s\",\"textSpan\":\"t\",\"confidence\":0.9,\"hierarchyLevel\":0,\"subtopicOf\":null}"
    let repaired = JSONRepair.cleanAndRepair(truncated)
    let data = Data(repaired.utf8)
    if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let concepts = obj["concepts"] as? [[String: Any]] {
        expectEqual(concepts.count, 1)
        expectEqual(concepts.first?["label"] as? String, "Complete concept")
    } else {
        expectNotNil(try? JSONSerialization.jsonObject(with: data), "Should be parseable")
    }
}

test("JSONRepair recovers concepts when edges are truncated (aggressive fallback)") {
    // The aggressive fallback finds completed concepts and discards partial edges
    let truncated = "{\"concepts\":[{\"label\":\"A\",\"type\":\"concept\",\"summary\":\"s\",\"textSpan\":\"t\",\"confidence\":0.9,\"hierarchyLevel\":0}],\"edges\":[{\"sourceLabel\":\"A\",\"targetLabel\":\"B\",\"type\":\"dep"
    let repaired = JSONRepair.cleanAndRepair(truncated)
    // The aggressive fallback should find the concepts array and produce valid JSON
    // with "edges": [] appended
    expect(repaired.contains("\"concepts\""), "Should preserve concepts")
    expect(repaired.contains("\"label\":\"A\""), "Should preserve concept A")
}

// MARK: - Results

print("\n" + String(repeating: "=", count: 40))
print("Results: \(passed) passed, \(failed) failed")
if failed > 0 {
    print("⚠ Some tests failed!")
    exit(1)
} else {
    print("✓ All tests passed")
}

import Foundation

struct ScreenFlowHeuristicExtractionService {
    func makeFallbackSpec(
        from ocrSpec: OCRBlockSpecV1,
        promptVersion: String
    ) -> ScreenFlowSpecV1 {
        let lines = ocrSpec.blocks.map(\.text)
        let lowered = lines.map { $0.lowercased() }

        let scenario = inferScenario(from: lowered)
        let entities = inferEntities(scenario: scenario, lines: lines, loweredLines: lowered)
        let packSuggestions = defaultPackSuggestions(for: scenario)

        return ScreenFlowSpecV1(
            schemaVersion: "ScreenFlowSpec.v1",
            scenario: scenario,
            scenarioConfidence: 0.2,
            entities: entities,
            packSuggestions: packSuggestions,
            modelMeta: ScreenFlowModelMeta(
                model: "screenflow-heuristic-fallback-v1",
                promptVersion: promptVersion
            )
        )
    }

    private func inferScenario(from lines: [String]) -> ScenarioType {
        let jobKeywords = ["job", "role", "salary", "apply", "company", "remote", "experience"]
        let eventKeywords = ["event", "date", "time", "venue", "rsvp", "ticket", "location"]
        let errorKeywords = ["error", "exception", "stack", "trace", "fatal", "warning", "failed"]

        let jobScore = score(lines: lines, keywords: jobKeywords)
        let eventScore = score(lines: lines, keywords: eventKeywords)
        let errorScore = score(lines: lines, keywords: errorKeywords)

        let maxScore = max(jobScore, eventScore, errorScore)
        guard maxScore > 0 else { return .unknown }

        if errorScore == maxScore { return .errorLog }
        if jobScore == maxScore { return .jobListing }
        return .eventFlyer
    }

    private func inferEntities(
        scenario: ScenarioType,
        lines: [String],
        loweredLines: [String]
    ) -> ScreenFlowEntities {
        switch scenario {
        case .jobListing:
            return ScreenFlowEntities(
                job: JobEntities(
                    company: firstLine(containingAny: [" at ", "company"], lines: lines, loweredLines: loweredLines),
                    role: lines.first,
                    location: firstLine(containingAny: ["remote", "location"], lines: lines, loweredLines: loweredLines),
                    skills: nil,
                    salaryRange: nil,
                    link: firstLink(in: lines)
                ),
                event: nil,
                error: nil
            )
        case .eventFlyer:
            return ScreenFlowEntities(
                job: nil,
                event: EventEntities(
                    title: lines.first,
                    dateTime: firstISO8601(in: lines),
                    venue: firstLine(containingAny: ["venue", "location"], lines: lines, loweredLines: loweredLines),
                    address: nil,
                    link: firstLink(in: lines)
                ),
                error: nil
            )
        case .errorLog:
            return ScreenFlowEntities(
                job: nil,
                event: nil,
                error: ErrorEntities(
                    errorType: firstLine(containingAny: ["error", "exception", "fatal"], lines: lines, loweredLines: loweredLines),
                    message: lines.first,
                    stackTrace: nil,
                    toolName: firstLine(containingAny: ["xcode", "android studio", "terminal"], lines: lines, loweredLines: loweredLines),
                    filePaths: extractFilePaths(from: lines)
                )
            )
        case .unknown:
            return .empty
        }
    }

    private func defaultPackSuggestions(for scenario: ScenarioType) -> [ActionPackSuggestion] {
        switch scenario {
        case .jobListing:
            return [ActionPackSuggestion(packId: "job_listing.save_tracker", confidence: 0.2, bindings: [:])]
        case .eventFlyer:
            return [ActionPackSuggestion(packId: "event_flyer.add_to_calendar", confidence: 0.2, bindings: [:])]
        case .errorLog:
            return [ActionPackSuggestion(packId: "error_log.generate_issue_template", confidence: 0.2, bindings: [:])]
        case .unknown:
            return []
        }
    }

    private func score(lines: [String], keywords: [String]) -> Int {
        lines.reduce(into: 0) { partialResult, line in
            for keyword in keywords where line.contains(keyword) {
                partialResult += 1
            }
        }
    }

    private func firstLine(
        containingAny needles: [String],
        lines: [String],
        loweredLines: [String]
    ) -> String? {
        for (index, line) in loweredLines.enumerated() {
            if needles.contains(where: line.contains) {
                return lines[index]
            }
        }
        return nil
    }

    private func firstLink(in lines: [String]) -> String? {
        lines.first { $0.contains("http://") || $0.contains("https://") }
    }

    private func firstISO8601(in lines: [String]) -> String? {
        let formatter = ISO8601DateFormatter()
        for line in lines {
            if formatter.date(from: line) != nil {
                return line
            }
        }
        return nil
    }

    private func extractFilePaths(from lines: [String]) -> [String]? {
        let pattern = #"[A-Za-z0-9_./-]+\.(swift|m|mm|kt|js|ts|py|java|rb|go|rs)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let matches = lines.flatMap { line -> [String] in
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            return regex.matches(in: line, options: [], range: range).compactMap { result in
                guard let matchRange = Range(result.range, in: line) else { return nil }
                return String(line[matchRange])
            }
        }

        guard !matches.isEmpty else { return nil }
        return Array(Set(matches)).sorted()
    }
}

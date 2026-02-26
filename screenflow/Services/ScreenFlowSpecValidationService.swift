import Foundation

enum ScreenFlowSpecValidationError: Error, Equatable {
    case invalidSchemaVersion(String)
    case invalidScenarioConfidence(Double)
    case invalidPackSuggestion(String)
    case invalidPackSuggestionConfidence(Double)
}

struct ScreenFlowSpecValidationService {
    private let iso8601WithFractionalSeconds: ISO8601DateFormatter
    private let iso8601: ISO8601DateFormatter

    init() {
        let withFractionalSeconds = ISO8601DateFormatter()
        withFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.iso8601WithFractionalSeconds = withFractionalSeconds

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        self.iso8601 = plain
    }

    func validateAndCanonicalize(_ spec: ScreenFlowSpecV1) throws -> ScreenFlowSpecV1 {
        guard spec.schemaVersion == "ScreenFlowSpec.v1" else {
            throw ScreenFlowSpecValidationError.invalidSchemaVersion(spec.schemaVersion)
        }

        let scenarioConfidence = clampConfidence(spec.scenarioConfidence)
        guard scenarioConfidence == spec.scenarioConfidence else {
            throw ScreenFlowSpecValidationError.invalidScenarioConfidence(spec.scenarioConfidence)
        }

        let normalizedEntities = ScreenFlowEntities(
            job: normalizeJob(spec.entities.job),
            event: normalizeEvent(spec.entities.event),
            error: normalizeError(spec.entities.error)
        )

        let normalizedPackSuggestions = try spec.packSuggestions
            .map(normalizePackSuggestion)
            .sorted(by: comparePackSuggestions)

        return ScreenFlowSpecV1(
            schemaVersion: spec.schemaVersion,
            scenario: spec.scenario,
            scenarioConfidence: scenarioConfidence,
            entities: normalizedEntities,
            packSuggestions: normalizedPackSuggestions,
            modelMeta: ScreenFlowModelMeta(
                model: normalizeString(spec.modelMeta.model),
                promptVersion: normalizeString(spec.modelMeta.promptVersion)
            )
        )
    }

    private func normalizeJob(_ job: JobEntities?) -> JobEntities? {
        guard let job else { return nil }

        return JobEntities(
            company: normalizeOptionalString(job.company),
            role: normalizeOptionalString(job.role),
            location: normalizeOptionalString(job.location),
            skills: normalizeStringArray(job.skills),
            salaryRange: normalizeSalaryRange(job.salaryRange),
            link: normalizeOptionalString(job.link)
        )
    }

    private func normalizeEvent(_ event: EventEntities?) -> EventEntities? {
        guard let event else { return nil }

        return EventEntities(
            title: normalizeOptionalString(event.title),
            dateTime: normalizeDateTime(event.dateTime),
            venue: normalizeOptionalString(event.venue),
            address: normalizeOptionalString(event.address),
            link: normalizeOptionalString(event.link)
        )
    }

    private func normalizeError(_ error: ErrorEntities?) -> ErrorEntities? {
        guard let error else { return nil }

        return ErrorEntities(
            errorType: normalizeOptionalString(error.errorType),
            message: normalizeOptionalString(error.message),
            stackTrace: normalizeOptionalString(error.stackTrace),
            toolName: normalizeOptionalString(error.toolName),
            filePaths: normalizeStringArray(error.filePaths)
        )
    }

    private func normalizeSalaryRange(_ range: SalaryRange?) -> SalaryRange? {
        guard let range else { return nil }

        let minValue = range.min.map(roundMoney)
        let maxValue = range.max.map(roundMoney)

        let normalizedMin: Double?
        let normalizedMax: Double?

        if let minValue, let maxValue, minValue > maxValue {
            normalizedMin = maxValue
            normalizedMax = minValue
        } else {
            normalizedMin = minValue
            normalizedMax = maxValue
        }

        return SalaryRange(
            min: normalizedMin,
            max: normalizedMax,
            currency: normalizeCurrency(range.currency)
        )
    }

    private func normalizePackSuggestion(_ suggestion: ActionPackSuggestion) throws -> ActionPackSuggestion {
        let packID = normalizeString(suggestion.packId)
        guard !packID.isEmpty else {
            throw ScreenFlowSpecValidationError.invalidPackSuggestion(suggestion.packId)
        }

        let confidence = clampConfidence(suggestion.confidence)
        guard confidence == suggestion.confidence else {
            throw ScreenFlowSpecValidationError.invalidPackSuggestionConfidence(suggestion.confidence)
        }

        let bindings = suggestion.bindings.reduce(into: [String: String]()) { partialResult, item in
            let key = normalizeString(item.key)
            let value = normalizeString(item.value)
            if !key.isEmpty {
                partialResult[key] = value
            }
        }

        return ActionPackSuggestion(
            packId: packID,
            confidence: confidence,
            bindings: bindings
        )
    }

    private func comparePackSuggestions(lhs: ActionPackSuggestion, rhs: ActionPackSuggestion) -> Bool {
        if lhs.packId != rhs.packId {
            return lhs.packId < rhs.packId
        }
        if lhs.confidence != rhs.confidence {
            return lhs.confidence > rhs.confidence
        }
        return lhs.bindings.count < rhs.bindings.count
    }

    private func clampConfidence(_ value: Double) -> Double {
        min(1.0, max(0.0, value))
    }

    private func normalizeDateTime(_ value: String?) -> String? {
        guard let value else { return nil }
        let cleaned = normalizeString(value)
        guard !cleaned.isEmpty else { return nil }

        if let date = iso8601WithFractionalSeconds.date(from: cleaned) ?? iso8601.date(from: cleaned) {
            return iso8601.string(from: date)
        }

        return cleaned
    }

    private func normalizeCurrency(_ value: String?) -> String? {
        guard let value else { return nil }
        let cleaned = normalizeString(value)
        guard !cleaned.isEmpty else { return nil }
        return cleaned.uppercased()
    }

    private func roundMoney(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }

    private func normalizeStringArray(_ values: [String]?) -> [String]? {
        guard let values else { return nil }

        let normalized = values
            .map(normalizeString)
            .filter { !$0.isEmpty }

        guard !normalized.isEmpty else { return nil }
        return Array(Set(normalized)).sorted()
    }

    private func normalizeOptionalString(_ value: String?) -> String? {
        guard let value else { return nil }
        let cleaned = normalizeString(value)
        return cleaned.isEmpty ? nil : cleaned
    }

    private func normalizeString(_ value: String) -> String {
        value
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

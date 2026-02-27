import Foundation

enum ActionPackValidationError: Error, Equatable {
    case scenarioMismatch(expected: ScenarioType, actual: ScenarioType)
    case missingRequiredBinding(String)
    case invalidBindingType(key: String, expected: ActionPackBindingValueType)
    case failedPrecondition(key: String, expectedContains: String)
}

struct ActionPackValidationResult: Equatable, Sendable {
    let validatedBindings: [String: String]
}

struct ActionPackValidationService {
    func validate(
        selection: ActionPackSelection,
        spec: ScreenFlowSpecV1
    ) throws -> ActionPackValidationResult {
        guard selection.pack.scenario == spec.scenario else {
            throw ActionPackValidationError.scenarioMismatch(
                expected: selection.pack.scenario,
                actual: spec.scenario
            )
        }

        let extractedBindings = resolveBindings(from: spec)
        var mergedBindings = extractedBindings
        for entry in selection.suggestedBindings {
            mergedBindings[entry.key] = normalize(entry.value)
        }

        for requirement in selection.pack.requiredBindings {
            guard let value = mergedBindings[requirement.key], !value.isEmpty else {
                throw ActionPackValidationError.missingRequiredBinding(requirement.key)
            }

            switch requirement.valueType {
            case .string:
                break
            case .number:
                if Double(value) == nil {
                    throw ActionPackValidationError.invalidBindingType(
                        key: requirement.key,
                        expected: .number
                    )
                }
            }
        }

        for precondition in selection.pack.preconditions {
            guard let expectedContains = precondition.contains else { continue }
            let actual = mergedBindings[precondition.key] ?? ""
            if !actual.localizedCaseInsensitiveContains(expectedContains) {
                throw ActionPackValidationError.failedPrecondition(
                    key: precondition.key,
                    expectedContains: expectedContains
                )
            }
        }

        let filteredKeys = Set(selection.pack.requiredBindings.map(\.key) + selection.pack.optionalBindingKeys)
        let canonicalBindings = mergedBindings
            .filter { filteredKeys.contains($0.key) && !$0.value.isEmpty }
            .reduce(into: [String: String]()) { partialResult, entry in
                partialResult[entry.key] = normalize(entry.value)
            }

        return ActionPackValidationResult(validatedBindings: canonicalBindings)
    }

    private func resolveBindings(from spec: ScreenFlowSpecV1) -> [String: String] {
        var bindings: [String: String] = [:]

        if let job = spec.entities.job {
            bindings["job.company"] = normalizeOptional(job.company)
            bindings["job.role"] = normalizeOptional(job.role)
            bindings["job.location"] = normalizeOptional(job.location)
            bindings["job.skills"] = normalizeArray(job.skills)
            bindings["job.link"] = normalizeOptional(job.link)
            if let salary = job.salaryRange {
                bindings["job.salaryRange.min"] = salary.min.map { String($0) } ?? ""
                bindings["job.salaryRange.max"] = salary.max.map { String($0) } ?? ""
                bindings["job.salaryRange.currency"] = normalizeOptional(salary.currency)
            }
        }

        if let event = spec.entities.event {
            bindings["event.title"] = normalizeOptional(event.title)
            bindings["event.dateTime"] = normalizeOptional(event.dateTime)
            bindings["event.venue"] = normalizeOptional(event.venue)
            bindings["event.address"] = normalizeOptional(event.address)
            bindings["event.link"] = normalizeOptional(event.link)
        }

        if let error = spec.entities.error {
            bindings["error.errorType"] = normalizeOptional(error.errorType)
            bindings["error.message"] = normalizeOptional(error.message)
            bindings["error.stackTrace"] = normalizeOptional(error.stackTrace)
            bindings["error.toolName"] = normalizeOptional(error.toolName)
            bindings["error.filePaths"] = normalizeArray(error.filePaths)
        }

        return bindings
    }

    private func normalizeOptional(_ value: String?) -> String {
        normalize(value ?? "")
    }

    private func normalizeArray(_ values: [String]?) -> String {
        guard let values else { return "" }
        return values.map(normalize).filter { !$0.isEmpty }.joined(separator: ", ")
    }

    private func normalize(_ value: String) -> String {
        value
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

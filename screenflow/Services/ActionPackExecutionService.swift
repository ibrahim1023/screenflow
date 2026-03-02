import CryptoKit
import Foundation

enum ActionPackExecutionError: Error, Equatable {
    case stepTemplateMissing(String)
    case invalidEventDateTime(String)
    case missingSourceStepOutput(String)
}

private struct JobTrackerSalaryRange: Codable, Equatable {
    let min: Double?
    let max: Double?
    let currency: String?
}

private struct JobTrackerEntryV1: Codable, Equatable {
    let schemaVersion: String
    let company: String
    let role: String
    let location: String?
    let link: String?
    let skills: [String]
    let salaryRange: JobTrackerSalaryRange?
}

private struct CalendarEventResultV1: Codable, Equatable {
    let schemaVersion: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let notes: String?
    let url: String?
    let createdEventIdentifier: String?
}

private struct ClipboardWriteResultV1: Codable, Equatable {
    let schemaVersion: String
    let text: String
    let didCopy: Bool
}

private struct URLOpenResultV1: Codable, Equatable {
    let schemaVersion: String
    let url: String?
    let didOpen: Bool
}

@MainActor
struct ActionPackExecutionService {
    private let storagePathService: StoragePathService
    private let validationService: ActionPackValidationService
    private let calendarService: any CalendarEventCreating
    private let clipboardService: any ClipboardWriting
    private let urlOpeningService: any URLOpening

    init(
        storagePathService: StoragePathService? = nil,
        validationService: ActionPackValidationService? = nil,
        calendarService: (any CalendarEventCreating)? = nil,
        clipboardService: (any ClipboardWriting)? = nil,
        urlOpeningService: (any URLOpening)? = nil
    ) {
        self.storagePathService = storagePathService ?? StoragePathService()
        self.validationService = validationService ?? ActionPackValidationService()
        self.calendarService = calendarService ?? EventKitCalendarEventService()
        self.clipboardService = clipboardService ?? SystemClipboardService()
        self.urlOpeningService = urlOpeningService ?? NoopURLOpeningService()
    }

    @discardableResult
    func execute(
        selection: ActionPackSelection,
        spec: ScreenFlowSpecV1,
        screenID: String,
        repository: ScreenFlowRepository,
        createdAt: Date = Date()
    ) throws -> ActionPackRun {
        let validated = try validationService.validate(selection: selection, spec: spec)

        let runsDirectory = try storagePathService.applicationSupportPath(for: .runs)
        try storagePathService.fileManager.createDirectory(at: runsDirectory, withIntermediateDirectories: true)

        let runID = try makeRunID(
            screenID: screenID,
            packID: selection.pack.id,
            packVersion: selection.pack.version,
            bindings: validated.validatedBindings,
            createdAt: createdAt
        )

        let inputParamsURL = runsDirectory.appendingPathComponent("\(runID).input.json", isDirectory: false)
        let traceURL = runsDirectory.appendingPathComponent("\(runID).trace.json", isDirectory: false)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601

        try encoder.encode(validated.validatedBindings).write(to: inputParamsURL, options: .atomic)

        let startedAt = createdAt
        var stepTraces: [ActionPackStepTrace] = []
        var finalStatus: ActionRunStatus = .success
        var stepOutputsByID: [String: String] = [:]

        for step in selection.pack.steps {
            do {
                let outputPath = try executeStep(
                    step,
                    bindings: validated.validatedBindings,
                    runID: runID,
                    runsDirectory: runsDirectory,
                    encoder: encoder,
                    stepOutputsByID: stepOutputsByID
                )
                stepOutputsByID[step.id] = outputPath
                stepTraces.append(
                    ActionPackStepTrace(
                        stepID: step.id,
                        status: .success,
                        outputPath: outputPath,
                        message: nil
                    )
                )
            } catch {
                finalStatus = .failed
                stepTraces.append(
                    ActionPackStepTrace(
                        stepID: step.id,
                        status: .failed,
                        outputPath: nil,
                        message: error.localizedDescription
                    )
                )
                break
            }
        }

        let trace = ActionPackExecutionTraceV1(
            schemaVersion: "action-pack-trace.v1",
            runID: runID,
            screenID: screenID,
            packID: selection.pack.id,
            packVersion: selection.pack.version,
            startedAt: startedAt,
            finishedAt: Date(),
            status: finalStatus,
            steps: stepTraces
        )
        try encoder.encode(trace).write(to: traceURL, options: .atomic)

        return try repository.upsertActionPackRun(
            ActionPackRunInput(
                id: runID,
                screenId: screenID,
                packId: selection.pack.id,
                packVersion: selection.pack.version,
                inputParamsJSONPath: inputParamsURL.path,
                traceJSONPath: traceURL.path,
                status: finalStatus,
                createdAt: createdAt
            )
        )
    }

    private func executeStep(
        _ step: ActionPackStepDefinition,
        bindings: [String: String],
        runID: String,
        runsDirectory: URL,
        encoder: JSONEncoder,
        stepOutputsByID: [String: String]
    ) throws -> String {
        let outputURL = runsDirectory.appendingPathComponent("\(runID).\(step.outputFileName)", isDirectory: false)

        switch step.type {
        case .renderTextTemplate:
            guard let template = step.template else {
                throw ActionPackExecutionError.stepTemplateMissing(step.id)
            }
            let rendered = renderTemplate(template, bindings: bindings)
            try Data(rendered.utf8).write(to: outputURL, options: .atomic)
            return outputURL.path

        case .exportBindingsJSON:
            try encoder.encode(bindings).write(to: outputURL, options: .atomic)
            return outputURL.path

        case .exportJobTrackerJSON:
            let entry = buildJobTrackerEntry(from: bindings)
            try encoder.encode(entry).write(to: outputURL, options: .atomic)
            return outputURL.path

        case .createCalendarEvent:
            let request = try buildCalendarEventRequest(from: bindings)
            let identifier = try calendarService.createEvent(request)
            let result = CalendarEventResultV1(
                schemaVersion: "calendar-event-result.v1",
                title: request.title,
                startDate: request.startDate,
                endDate: request.endDate,
                location: request.location,
                notes: request.notes,
                url: request.url?.absoluteString,
                createdEventIdentifier: identifier
            )
            try encoder.encode(result).write(to: outputURL, options: .atomic)
            return outputURL.path

        case .exportFile:
            guard let sourceStepID = step.sourceStepID else {
                throw ActionPackExecutionError.missingSourceStepOutput(step.id)
            }
            guard let sourceOutputPath = stepOutputsByID[sourceStepID] else {
                throw ActionPackExecutionError.missingSourceStepOutput(sourceStepID)
            }
            let sourceURL = URL(fileURLWithPath: sourceOutputPath)
            let exportsDirectory = try storagePathService.applicationSupportPath(for: .exports)
            try storagePathService.fileManager.createDirectory(at: exportsDirectory, withIntermediateDirectories: true)
            let exportURL = exportsDirectory.appendingPathComponent("\(runID).\(step.outputFileName)", isDirectory: false)
            let data = try Data(contentsOf: sourceURL)
            try data.write(to: exportURL, options: .atomic)
            return exportURL.path

        case .copyTextToClipboard:
            guard let sourceStepID = step.sourceStepID else {
                throw ActionPackExecutionError.missingSourceStepOutput(step.id)
            }
            guard let sourceOutputPath = stepOutputsByID[sourceStepID] else {
                throw ActionPackExecutionError.missingSourceStepOutput(sourceStepID)
            }
            let sourceText = try String(contentsOfFile: sourceOutputPath, encoding: .utf8)
            let didCopy = clipboardService.writeText(sourceText)
            let result = ClipboardWriteResultV1(
                schemaVersion: "clipboard-write-result.v1",
                text: sourceText,
                didCopy: didCopy
            )
            try encoder.encode(result).write(to: outputURL, options: .atomic)
            return outputURL.path

        case .openURL:
            guard let template = step.template else {
                throw ActionPackExecutionError.stepTemplateMissing(step.id)
            }
            let rendered = normalizedOptional(renderTemplate(template, bindings: bindings))
            let opened: Bool
            if let rendered, let url = URL(string: rendered) {
                opened = urlOpeningService.open(url)
            } else {
                opened = false
            }
            let result = URLOpenResultV1(
                schemaVersion: "open-url-result.v1",
                url: rendered,
                didOpen: opened
            )
            try encoder.encode(result).write(to: outputURL, options: .atomic)
            return outputURL.path
        }
    }

    private func buildJobTrackerEntry(from bindings: [String: String]) -> JobTrackerEntryV1 {
        let company = normalizedOrFallback(bindings["job.company"], fallback: "unknown")
        let role = normalizedOrFallback(bindings["job.role"], fallback: "unknown")
        let location = normalizedOptional(bindings["job.location"])
        let link = normalizedOptional(bindings["job.link"])
        let skills = parseList(bindings["job.skills"])

        let minSalary = bindings["job.salaryRange.min"].flatMap(Double.init)
        let maxSalary = bindings["job.salaryRange.max"].flatMap(Double.init)
        let currency = normalizedOptional(bindings["job.salaryRange.currency"])

        let salaryRange: JobTrackerSalaryRange?
        if minSalary != nil || maxSalary != nil || currency != nil {
            salaryRange = JobTrackerSalaryRange(min: minSalary, max: maxSalary, currency: currency)
        } else {
            salaryRange = nil
        }

        return JobTrackerEntryV1(
            schemaVersion: "job-tracker-entry.v1",
            company: company,
            role: role,
            location: location,
            link: link,
            skills: skills,
            salaryRange: salaryRange
        )
    }

    private func renderTemplate(_ template: String, bindings: [String: String]) -> String {
        var rendered = template
        for key in bindings.keys.sorted() {
            rendered = rendered.replacingOccurrences(of: "{{\(key)}}", with: bindings[key] ?? "")
        }
        return rendered
    }

    private func normalizedOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let cleaned = value
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    private func normalizedOrFallback(_ value: String?, fallback: String) -> String {
        normalizedOptional(value) ?? fallback
    }

    private func parseList(_ value: String?) -> [String] {
        guard let normalized = normalizedOptional(value) else { return [] }
        return normalized
            .split(separator: ",")
            .map {
                String($0)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
    }

    private func buildCalendarEventRequest(from bindings: [String: String]) throws -> CalendarEventRequest {
        let title = normalizedOrFallback(bindings["event.title"], fallback: "Untitled Event")
        let dateTimeRaw = normalizedOrFallback(bindings["event.dateTime"], fallback: "")

        guard let startDate = parseISO8601(dateTimeRaw) else {
            throw ActionPackExecutionError.invalidEventDateTime(dateTimeRaw)
        }

        let locationParts = [normalizedOptional(bindings["event.venue"]), normalizedOptional(bindings["event.address"])]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        let location = locationParts.isEmpty ? nil : locationParts.joined(separator: ", ")

        let link = normalizedOptional(bindings["event.link"])
        let notes = link.map { "Source Link: \($0)" }

        return CalendarEventRequest(
            title: title,
            startDate: startDate,
            endDate: startDate.addingTimeInterval(60 * 60),
            location: location,
            notes: notes,
            url: link.flatMap(URL.init(string:))
        )
    }

    private func parseISO8601(_ value: String) -> Date? {
        guard !value.isEmpty else { return nil }
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return withFractional.date(from: value) ?? plain.date(from: value)
    }

    private func makeRunID(
        screenID: String,
        packID: String,
        packVersion: String,
        bindings: [String: String],
        createdAt: Date
    ) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601

        var payload = Data("action-pack-run-v1".utf8)
        payload.append(0x1F)
        payload.append(Data(screenID.utf8))
        payload.append(0x1F)
        payload.append(Data(packID.utf8))
        payload.append(0x1F)
        payload.append(Data(packVersion.utf8))
        payload.append(0x1F)
        payload.append(try encoder.encode(bindings))
        payload.append(0x1F)
        payload.append(try encoder.encode(createdAt))

        let digest = SHA256.hash(data: payload)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

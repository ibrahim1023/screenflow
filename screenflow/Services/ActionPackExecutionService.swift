import CryptoKit
import Foundation

enum ActionPackExecutionError: Error, Equatable {
    case stepTemplateMissing(String)
}

@MainActor
struct ActionPackExecutionService {
    private let storagePathService: StoragePathService
    private let validationService: ActionPackValidationService

    init(
        storagePathService: StoragePathService? = nil,
        validationService: ActionPackValidationService? = nil
    ) {
        self.storagePathService = storagePathService ?? StoragePathService()
        self.validationService = validationService ?? ActionPackValidationService()
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

        for step in selection.pack.steps {
            do {
                let outputPath = try executeStep(
                    step,
                    bindings: validated.validatedBindings,
                    runID: runID,
                    runsDirectory: runsDirectory,
                    encoder: encoder
                )
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
        encoder: JSONEncoder
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
        }
    }

    private func renderTemplate(_ template: String, bindings: [String: String]) -> String {
        var rendered = template
        for key in bindings.keys.sorted() {
            rendered = rendered.replacingOccurrences(of: "{{\(key)}}", with: bindings[key] ?? "")
        }
        return rendered
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

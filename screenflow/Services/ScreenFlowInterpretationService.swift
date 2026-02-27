import Foundation

enum ScreenFlowInterpretationServiceError: Error, Equatable {
    case invalidSpec
}

protocol ScreenFlowModelRunning: Sendable {
    func run(request: ScreenFlowModelRequest) async throws -> ScreenFlowModelOutput
}

extension ScreenFlowModelRuntime: ScreenFlowModelRunning {}

struct ScreenFlowInterpretationOutcome {
    let screen: ScreenRecord
    let llmResult: LLMResult
    let extractionResult: ExtractionResult
    let spec: ScreenFlowSpecV1
}

@MainActor
struct ScreenFlowInterpretationService {
    private let mapper: ScreenFlowPromptMappingService
    private let runtime: any ScreenFlowModelRunning
    private let artifactPersistence: LLMArtifactPersistenceService
    private let extractionPersistence: ExtractionArtifactPersistenceService
    private let validator: ScreenFlowSpecValidationService
    private let heuristicExtraction: ScreenFlowHeuristicExtractionService

    init(
        mapper: ScreenFlowPromptMappingService? = nil,
        runtime: (any ScreenFlowModelRunning)? = nil,
        artifactPersistence: LLMArtifactPersistenceService? = nil,
        extractionPersistence: ExtractionArtifactPersistenceService? = nil,
        validator: ScreenFlowSpecValidationService? = nil,
        heuristicExtraction: ScreenFlowHeuristicExtractionService? = nil
    ) {
        self.mapper = mapper ?? ScreenFlowPromptMappingService()
        self.runtime = runtime ?? ScreenFlowModelRuntime()
        self.artifactPersistence = artifactPersistence ?? LLMArtifactPersistenceService()
        self.extractionPersistence = extractionPersistence ?? ExtractionArtifactPersistenceService()
        self.validator = validator ?? ScreenFlowSpecValidationService()
        self.heuristicExtraction = heuristicExtraction ?? ScreenFlowHeuristicExtractionService()
    }

    func interpret(
        ocrSpec: OCRBlockSpecV1,
        screen: ScreenRecord,
        repository: ScreenFlowRepository
    ) async throws -> ScreenFlowInterpretationOutcome {
        let request = try mapper.makeRequest(from: ocrSpec)
        let output = try await runtime.run(request: request)

        let resolved = try await resolveSpec(
            request: request,
            initialOutput: output,
            ocrSpec: ocrSpec
        )
        let spec = resolved.spec
        let artifactOutput = resolved.output

        let llmResult = try artifactPersistence.persistArtifacts(
            screenID: screen.id,
            model: artifactOutput.model,
            promptVersion: request.promptVersion,
            rawResponseText: artifactOutput.rawResponseText,
            validatedSpec: spec,
            repository: repository
        )
        let extractionResult = try extractionPersistence.persistCanonicalExtraction(
            screenID: screen.id,
            spec: spec,
            repository: repository
        )

        let updatedScreen = try repository.upsertScreenRecord(
            ScreenRecordInput(
                id: screen.id,
                createdAt: screen.createdAt,
                source: screen.source,
                imagePath: screen.imagePath,
                imageWidth: screen.imageWidth,
                imageHeight: screen.imageHeight,
                scenario: spec.scenario,
                scenarioConfidence: spec.scenarioConfidence,
                processingVersion: screen.processingVersion,
                lastOpenedAt: screen.lastOpenedAt
            )
        )

        return ScreenFlowInterpretationOutcome(
            screen: updatedScreen,
            llmResult: llmResult,
            extractionResult: extractionResult,
            spec: spec
        )
    }

    private func resolveSpec(
        request: ScreenFlowModelRequest,
        initialOutput: ScreenFlowModelOutput,
        ocrSpec: OCRBlockSpecV1
    ) async throws -> (spec: ScreenFlowSpecV1, output: ScreenFlowModelOutput) {
        if let initialSpec = decodeAndValidate(rawResponseText: initialOutput.rawResponseText) {
            return (initialSpec, initialOutput)
        }

        if let repairedOutput = try await attemptRepair(request: request, rawResponseText: initialOutput.rawResponseText),
           let repairedSpec = decodeAndValidate(rawResponseText: repairedOutput.rawResponseText) {
            return (repairedSpec, repairedOutput)
        }

        let fallback = heuristicExtraction.makeFallbackSpec(from: ocrSpec, promptVersion: request.promptVersion)
        guard let canonicalFallback = try? validator.validateAndCanonicalize(fallback) else {
            throw ScreenFlowInterpretationServiceError.invalidSpec
        }
        return (
            canonicalFallback,
            ScreenFlowModelOutput(
                provider: initialOutput.provider,
                model: "screenflow-heuristic-fallback-v1",
                rawResponseText: initialOutput.rawResponseText
            )
        )
    }

    private func decodeAndValidate(rawResponseText: String) -> ScreenFlowSpecV1? {
        guard let rawData = rawResponseText.data(using: .utf8),
              let decodedSpec = try? JSONDecoder().decode(ScreenFlowSpecV1.self, from: rawData),
              let validatedSpec = try? validator.validateAndCanonicalize(decodedSpec) else {
            return nil
        }
        return validatedSpec
    }

    private func attemptRepair(
        request: ScreenFlowModelRequest,
        rawResponseText: String
    ) async throws -> ScreenFlowModelOutput? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let ocrJSON = String(decoding: try encoder.encode(request.ocrSpec), as: UTF8.self)

        let repairRequest = ScreenFlowModelRequest(
            schemaVersion: request.schemaVersion,
            promptVersion: request.promptVersion,
            ocrSpec: request.ocrSpec,
            systemPrompt: """
            You repair invalid JSON into valid ScreenFlowSpec.v1 JSON.
            Return only valid JSON.
            Do not include markdown.
            """,
            userPrompt: """
            Repair the invalid model response into valid ScreenFlowSpec.v1 JSON.
            Keep extracted values when possible.
            Use null when uncertain.

            OCR input:
            \(ocrJSON)

            Invalid response:
            \(rawResponseText)
            """
        )

        guard let repaired = try? await runtime.run(request: repairRequest) else {
            return nil
        }
        return repaired
    }
}

import Foundation

enum ScreenFlowInterpretationServiceError: Error, Equatable {
    case invalidModelJSON
    case invalidSpec
}

protocol ScreenFlowModelRunning: Sendable {
    func run(request: ScreenFlowModelRequest) async throws -> ScreenFlowModelOutput
}

extension ScreenFlowModelRuntime: ScreenFlowModelRunning {}

struct ScreenFlowInterpretationOutcome {
    let screen: ScreenRecord
    let llmResult: LLMResult
    let spec: ScreenFlowSpecV1
}

@MainActor
struct ScreenFlowInterpretationService {
    private let mapper: ScreenFlowPromptMappingService
    private let runtime: any ScreenFlowModelRunning
    private let artifactPersistence: LLMArtifactPersistenceService
    private let validator: ScreenFlowSpecValidationService

    init(
        mapper: ScreenFlowPromptMappingService? = nil,
        runtime: (any ScreenFlowModelRunning)? = nil,
        artifactPersistence: LLMArtifactPersistenceService? = nil,
        validator: ScreenFlowSpecValidationService? = nil
    ) {
        self.mapper = mapper ?? ScreenFlowPromptMappingService()
        self.runtime = runtime ?? ScreenFlowModelRuntime()
        self.artifactPersistence = artifactPersistence ?? LLMArtifactPersistenceService()
        self.validator = validator ?? ScreenFlowSpecValidationService()
    }

    func interpret(
        ocrSpec: OCRBlockSpecV1,
        screen: ScreenRecord,
        repository: ScreenFlowRepository
    ) async throws -> ScreenFlowInterpretationOutcome {
        let request = try mapper.makeRequest(from: ocrSpec)
        let output = try await runtime.run(request: request)

        guard let rawData = output.rawResponseText.data(using: .utf8) else {
            throw ScreenFlowInterpretationServiceError.invalidModelJSON
        }

        let decodedSpec: ScreenFlowSpecV1
        do {
            decodedSpec = try JSONDecoder().decode(ScreenFlowSpecV1.self, from: rawData)
        } catch {
            throw ScreenFlowInterpretationServiceError.invalidModelJSON
        }
        let spec: ScreenFlowSpecV1
        do {
            spec = try validator.validateAndCanonicalize(decodedSpec)
        } catch {
            throw ScreenFlowInterpretationServiceError.invalidSpec
        }

        let llmResult = try artifactPersistence.persistArtifacts(
            screenID: screen.id,
            model: output.model,
            promptVersion: request.promptVersion,
            rawResponseText: output.rawResponseText,
            validatedSpec: spec,
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
            spec: spec
        )
    }
}

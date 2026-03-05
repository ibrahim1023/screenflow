import Foundation

enum ScreenFlowReplayError: Error, Equatable {
    case ocrArtifactNotFound(String)
    case screenRecordNotFound(String)
    case invalidOCRPayload(String)
    case recordedModelResultNotFound(String)
    case invalidRecordedModelPayload(String)
}

enum ScreenFlowReplayMode {
    case liveModel
    case recordedModel
}

struct ScreenFlowReplayOutcome {
    let ocrArtifact: OCRArtifact
    let interpretation: ScreenFlowInterpretationOutcome
}

@MainActor
struct ScreenFlowReplayService {
    private let liveRuntime: any ScreenFlowModelRunning

    init(liveRuntime: (any ScreenFlowModelRunning)? = nil) {
        self.liveRuntime = liveRuntime ?? ScreenFlowModelRuntime()
    }

    func replayOCRArtifact(
        artifactID: String,
        mode: ScreenFlowReplayMode = .liveModel,
        repository: ScreenFlowRepository
    ) async throws -> ScreenFlowReplayOutcome {
        guard let artifact = try repository.ocrArtifact(id: artifactID) else {
            throw ScreenFlowReplayError.ocrArtifactNotFound(artifactID)
        }

        return try await replay(
            artifact: artifact,
            mode: mode,
            repository: repository
        )
    }

    func replayLatestOCRArtifact(
        screenID: String,
        mode: ScreenFlowReplayMode = .liveModel,
        repository: ScreenFlowRepository
    ) async throws -> ScreenFlowReplayOutcome {
        guard let artifact = try repository.latestOCRArtifact(screenId: screenID) else {
            throw ScreenFlowReplayError.ocrArtifactNotFound(screenID)
        }

        return try await replay(
            artifact: artifact,
            mode: mode,
            repository: repository
        )
    }

    private func replay(
        artifact: OCRArtifact,
        mode: ScreenFlowReplayMode,
        repository: ScreenFlowRepository
    ) async throws -> ScreenFlowReplayOutcome {
        let artifactURL = URL(fileURLWithPath: artifact.blocksJSONPath)
        let data = try Data(contentsOf: artifactURL)
        guard let ocrSpec = try? JSONDecoder().decode(OCRBlockSpecV1.self, from: data) else {
            throw ScreenFlowReplayError.invalidOCRPayload(artifact.blocksJSONPath)
        }

        guard let screen = try repository.screenRecord(id: artifact.screenId) else {
            throw ScreenFlowReplayError.screenRecordNotFound(artifact.screenId)
        }

        let runtime = try runtimeForReplay(
            mode: mode,
            screenID: artifact.screenId,
            repository: repository
        )

        let interpretation = try await ScreenFlowInterpretationService(runtime: runtime).interpret(
            ocrSpec: ocrSpec,
            screen: screen,
            repository: repository
        )

        return ScreenFlowReplayOutcome(
            ocrArtifact: artifact,
            interpretation: interpretation
        )
    }

    private func runtimeForReplay(
        mode: ScreenFlowReplayMode,
        screenID: String,
        repository: ScreenFlowRepository
    ) throws -> any ScreenFlowModelRunning {
        switch mode {
        case .liveModel:
            return liveRuntime
        case .recordedModel:
            guard let llmResult = try repository.latestLLMResult(screenId: screenID) else {
                throw ScreenFlowReplayError.recordedModelResultNotFound(screenID)
            }
            let rawData = try Data(contentsOf: URL(fileURLWithPath: llmResult.rawResponseJSONPath))
            guard let rawResponseText = String(data: rawData, encoding: .utf8) else {
                throw ScreenFlowReplayError.invalidRecordedModelPayload(llmResult.rawResponseJSONPath)
            }
            return RecordedScreenFlowModelRuntime(
                model: llmResult.model,
                rawResponseText: rawResponseText
            )
        }
    }
}

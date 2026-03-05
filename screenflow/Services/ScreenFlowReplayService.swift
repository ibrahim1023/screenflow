import Foundation

enum ScreenFlowReplayError: Error, Equatable {
    case ocrArtifactNotFound(String)
    case screenRecordNotFound(String)
    case invalidOCRPayload(String)
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
        repository: ScreenFlowRepository
    ) async throws -> ScreenFlowReplayOutcome {
        guard let artifact = try repository.ocrArtifact(id: artifactID) else {
            throw ScreenFlowReplayError.ocrArtifactNotFound(artifactID)
        }

        return try await replay(
            artifact: artifact,
            repository: repository
        )
    }

    func replayLatestOCRArtifact(
        screenID: String,
        repository: ScreenFlowRepository
    ) async throws -> ScreenFlowReplayOutcome {
        guard let artifact = try repository.latestOCRArtifact(screenId: screenID) else {
            throw ScreenFlowReplayError.ocrArtifactNotFound(screenID)
        }

        return try await replay(
            artifact: artifact,
            repository: repository
        )
    }

    private func replay(
        artifact: OCRArtifact,
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

        let interpretation = try await ScreenFlowInterpretationService(runtime: liveRuntime).interpret(
            ocrSpec: ocrSpec,
            screen: screen,
            repository: repository
        )

        return ScreenFlowReplayOutcome(
            ocrArtifact: artifact,
            interpretation: interpretation
        )
    }
}

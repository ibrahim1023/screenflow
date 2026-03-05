import Foundation

struct RecordedScreenFlowModelRuntime: ScreenFlowModelRunning {
    let model: String
    let rawResponseText: String

    func run(request: ScreenFlowModelRequest) async throws -> ScreenFlowModelOutput {
        _ = request
        return ScreenFlowModelOutput(
            provider: .selfHostedOpenModel,
            model: model,
            rawResponseText: rawResponseText
        )
    }
}

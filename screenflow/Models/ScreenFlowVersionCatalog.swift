import Foundation

enum ScreenFlowSchemaVersion {
    nonisolated(unsafe) static let screenshotArtifact = "screenshot-artifact.v1"
    nonisolated(unsafe) static let ocrBlockSpec = "OCRBlockSpec.v1"
    nonisolated(unsafe) static let extractionSpec = "ScreenFlowSpec.v1"
    nonisolated(unsafe) static let intentGraph = "IntentGraph.v1"
}

enum ScreenFlowPromptVersion {
    nonisolated(unsafe) static let extractionV1 = "screenflow-spec-v1"
}

enum ScreenFlowModelVersion {
    nonisolated(unsafe) static let onDeviceDefault = "apple-on-device"
    nonisolated(unsafe) static let selfHostedDefault = "llama3.1:8b-instruct-q4_K_M"
    nonisolated(unsafe) static let heuristicFallback = "screenflow-heuristic-fallback-v1"
}

enum ScreenFlowPipelineVersion {
    nonisolated(unsafe) static let imageProcessing = "1.0.0"
    nonisolated(unsafe) static let ocrEngine = "vision-ocr-v1"
}

enum ScreenFlowPackVersion {
    nonisolated(unsafe) static let mvp = "1.0.0"
}

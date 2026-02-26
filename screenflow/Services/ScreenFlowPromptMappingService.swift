import Foundation

struct ScreenFlowModelRequest: Sendable {
    let schemaVersion: String
    let promptVersion: String
    let ocrSpec: OCRBlockSpecV1
    let systemPrompt: String
    let userPrompt: String
}

struct ScreenFlowPromptMappingService {
    init() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        self.encoder = encoder
    }
    private let encoder: JSONEncoder

    func makeRequest(
        from ocrSpec: OCRBlockSpecV1,
        promptVersion: String = "screenflow-spec-v1"
    ) throws -> ScreenFlowModelRequest {
        let ocrJSON = String(decoding: try encoder.encode(ocrSpec), as: UTF8.self)

        let systemPrompt = """
        You are ScreenFlow's deterministic extraction model.
        Return only valid JSON matching ScreenFlowSpec.v1.
        Do not include markdown.
        Keep unknown values as null.
        """

        let userPrompt = """
        Convert this OCRBlockSpec.v1 JSON into ScreenFlowSpec.v1 JSON.

        Required top-level fields:
        - schemaVersion (must be \"ScreenFlowSpec.v1\")
        - scenario (unknown|job_listing|event_flyer|error_log)
        - scenarioConfidence (0...1)
        - entities
        - packSuggestions
        - modelMeta

        OCR input:
        \(ocrJSON)
        """

        return ScreenFlowModelRequest(
            schemaVersion: "ScreenFlowSpec.v1",
            promptVersion: promptVersion,
            ocrSpec: ocrSpec,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt
        )
    }
}

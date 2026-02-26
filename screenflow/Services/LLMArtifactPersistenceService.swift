import CryptoKit
import Foundation

@MainActor
struct LLMArtifactPersistenceService {
    private let storagePathService: StoragePathService

    init(storagePathService: StoragePathService? = nil) {
        self.storagePathService = storagePathService ?? StoragePathService()
    }

    @discardableResult
    func persistArtifacts(
        screenID: String,
        model: String,
        promptVersion: String,
        rawResponseText: String,
        validatedSpec: ScreenFlowSpecV1,
        repository: ScreenFlowRepository,
        createdAt: Date = Date()
    ) throws -> LLMResult {
        let llmDirectory = try storagePathService.applicationSupportPath(for: .llm)
        try storagePathService.fileManager.createDirectory(at: llmDirectory, withIntermediateDirectories: true)

        let resultID = makeResultID(
            screenID: screenID,
            model: model,
            promptVersion: promptVersion,
            rawResponseText: rawResponseText
        )

        let rawURL = llmDirectory.appendingPathComponent("\(resultID).raw.json", isDirectory: false)
        let validatedURL = llmDirectory.appendingPathComponent("\(resultID).validated.json", isDirectory: false)

        try Data(rawResponseText.utf8).write(to: rawURL, options: .atomic)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let validatedData = try encoder.encode(validatedSpec)
        try validatedData.write(to: validatedURL, options: .atomic)

        return try repository.upsertLLMResult(
            LLMResultInput(
                id: resultID,
                screenId: screenID,
                model: model,
                promptVersion: promptVersion,
                rawResponseJSONPath: rawURL.path,
                validatedJSONPath: validatedURL.path,
                createdAt: createdAt
            )
        )
    }

    private func makeResultID(
        screenID: String,
        model: String,
        promptVersion: String,
        rawResponseText: String
    ) -> String {
        var payload = Data("llm-result-v1".utf8)
        payload.append(0x1F)
        payload.append(Data(screenID.utf8))
        payload.append(0x1F)
        payload.append(Data(model.utf8))
        payload.append(0x1F)
        payload.append(Data(promptVersion.utf8))
        payload.append(0x1F)
        payload.append(Data(rawResponseText.utf8))

        let digest = SHA256.hash(data: payload)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

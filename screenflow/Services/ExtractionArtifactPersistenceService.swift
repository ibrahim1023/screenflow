import CryptoKit
import Foundation

@MainActor
struct ExtractionArtifactPersistenceService {
    private let storagePathService: StoragePathService
    private let intentGraphService: ScreenFlowIntentGraphService

    init(
        storagePathService: StoragePathService? = nil,
        intentGraphService: ScreenFlowIntentGraphService? = nil
    ) {
        self.storagePathService = storagePathService ?? StoragePathService()
        self.intentGraphService = intentGraphService ?? ScreenFlowIntentGraphService()
    }

    @discardableResult
    func persistCanonicalExtraction(
        screenID: String,
        spec: ScreenFlowSpecV1,
        repository: ScreenFlowRepository,
        createdAt: Date = Date()
    ) throws -> ExtractionResult {
        let extractedDirectory = try storagePathService.applicationSupportPath(for: .extracted)
        try storagePathService.fileManager.createDirectory(at: extractedDirectory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let canonicalData = try encoder.encode(spec)
        let intentGraph = intentGraphService.buildGraph(from: spec)
        let graphData = try encoder.encode(intentGraph)

        let extractionID = makeExtractionID(
            screenID: screenID,
            schemaVersion: spec.schemaVersion,
            canonicalData: canonicalData
        )

        let entitiesURL = extractedDirectory.appendingPathComponent("\(extractionID).entities.json", isDirectory: false)
        let graphURL = extractedDirectory.appendingPathComponent("\(extractionID).graph.json", isDirectory: false)

        try canonicalData.write(to: entitiesURL, options: .atomic)
        try graphData.write(to: graphURL, options: .atomic)

        return try repository.upsertExtractionResult(
            ExtractionResultInput(
                id: extractionID,
                screenId: screenID,
                schemaVersion: spec.schemaVersion,
                entitiesJSONPath: entitiesURL.path,
                intentGraphJSONPath: graphURL.path,
                createdAt: createdAt,
                userOverridesJSONPath: nil
            )
        )
    }

    private func makeExtractionID(
        screenID: String,
        schemaVersion: String,
        canonicalData: Data
    ) -> String {
        var payload = Data("extraction-result-v1".utf8)
        payload.append(0x1F)
        payload.append(Data(screenID.utf8))
        payload.append(0x1F)
        payload.append(Data(schemaVersion.utf8))
        payload.append(0x1F)
        payload.append(canonicalData)

        let digest = SHA256.hash(data: payload)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

import CryptoKit
import Foundation

enum OCRArtifactPipelineError: Error, Equatable {
    case imageNotFound
}

@MainActor
struct OCRArtifactPipelineService {
    private let extractionService: any OCRExtracting
    private let storagePathService: StoragePathService
    private let processingVersion: String
    private let engineVersion: String

    init(
        extractionService: (any OCRExtracting)? = nil,
        storagePathService: StoragePathService? = nil,
        processingVersion: String = "1.0.0",
        engineVersion: String = "vision-ocr-v1"
    ) {
        self.extractionService = extractionService ?? VisionOCRService()
        self.storagePathService = storagePathService ?? StoragePathService()
        self.processingVersion = processingVersion
        self.engineVersion = engineVersion
    }

    @discardableResult
    func runOCRAndPersist(
        for screen: ScreenRecord,
        repository: ScreenFlowRepository
    ) throws -> OCRArtifact {
        let imageURL = URL(fileURLWithPath: screen.imagePath)
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            throw OCRArtifactPipelineError.imageNotFound
        }

        let imageData = try Data(contentsOf: imageURL)
        let spec = try extractionService.extractOCRBlockSpec(
            imageData: imageData,
            source: screen.source,
            processingVersion: processingVersion
        )

        let artifactID = makeArtifactID(screenID: screen.id, spec: spec)
        let ocrDirectory = try storagePathService.applicationSupportPath(for: .ocr)
        try storagePathService.fileManager.createDirectory(at: ocrDirectory, withIntermediateDirectories: true)

        let jsonURL = ocrDirectory.appendingPathComponent("\(artifactID).json", isDirectory: false)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]

        let payload = try encoder.encode(spec)
        try payload.write(to: jsonURL, options: .atomic)

        return try repository.upsertOCRArtifact(
            OCRArtifactInput(
                id: artifactID,
                screenId: screen.id,
                engineVersion: engineVersion,
                blocksJSONPath: jsonURL.path,
                languageHint: spec.languageHint,
                createdAt: Date()
            )
        )
    }

    private func makeArtifactID(screenID: String, spec: OCRBlockSpecV1) -> String {
        var payload = Data("ocr-artifact-v1".utf8)
        payload.append(0x1F)
        payload.append(Data(screenID.utf8))
        payload.append(0x1F)
        payload.append(Data(engineVersion.utf8))
        payload.append(0x1F)
        payload.append(Data(processingVersion.utf8))
        payload.append(0x1F)

        if let encoded = try? JSONEncoder().encode(spec) {
            payload.append(encoded)
        }

        let digest = SHA256.hash(data: payload)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

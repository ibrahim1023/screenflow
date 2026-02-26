//
//  InAppPhotoImportService.swift
//  screenflow
//
//  Created by Codex on 2/25/26.
//

import Foundation

enum InAppPhotoImportError: Error, Equatable {
    case invalidImageData
}

struct ImportedImageMetadata: Codable, Equatable, Sendable {
    let schemaVersion: String
    let screenId: String
    let source: String
    let importedAt: Date
    let processingVersion: String
    let originalImagePath: String
    let normalizedImagePath: String
    let originalByteCount: Int
    let normalizedByteCount: Int
    let imageWidth: Int
    let imageHeight: Int
}

@MainActor
struct InAppPhotoImportService {
    private let processingVersion: String
    private let metadataSchemaVersion: String
    private let storagePathService: StoragePathService
    private let idGenerator: StableScreenIdentifierGenerator
    private let normalizer: DeterministicImageNormalizationService

    init(
        processingVersion: String = "1.0.0",
        metadataSchemaVersion: String = "screenshot-artifact.v1",
        storagePathService: StoragePathService? = nil,
        idGenerator: StableScreenIdentifierGenerator? = nil,
        normalizer: DeterministicImageNormalizationService? = nil
    ) {
        self.processingVersion = processingVersion
        self.metadataSchemaVersion = metadataSchemaVersion
        self.storagePathService = storagePathService ?? StoragePathService()
        self.idGenerator = idGenerator ?? StableScreenIdentifierGenerator()
        self.normalizer = normalizer ?? DeterministicImageNormalizationService()
    }

    func importPhotoData(
        _ data: Data,
        source: ScreenSource,
        repository: ScreenFlowRepository
    ) throws -> ScreenRecord {
        let normalized = try normalizer.normalizeForHashingAndOCR(data)
        let screenId = try idGenerator.makeIdentifier(
            normalizedImageBytes: normalized.pngData,
            processingVersion: processingVersion
        )

        let screensDirectory = try storagePathService.applicationSupportPath(for: .screens)
        try storagePathService.fileManager.createDirectory(
            at: screensDirectory,
            withIntermediateDirectories: true
        )

        let originalImageURL = screensDirectory.appendingPathComponent("\(screenId).original.img", isDirectory: false)
        let normalizedImageURL = screensDirectory.appendingPathComponent("\(screenId).normalized.png", isDirectory: false)
        let metadataURL = screensDirectory.appendingPathComponent("\(screenId).metadata.json", isDirectory: false)

        try data.write(to: originalImageURL, options: .atomic)
        try normalized.pngData.write(to: normalizedImageURL, options: .atomic)

        let metadata = ImportedImageMetadata(
            schemaVersion: metadataSchemaVersion,
            screenId: screenId,
            source: source.rawValue,
            importedAt: Date(),
            processingVersion: processingVersion,
            originalImagePath: originalImageURL.path,
            normalizedImagePath: normalizedImageURL.path,
            originalByteCount: data.count,
            normalizedByteCount: normalized.pngData.count,
            imageWidth: normalized.width,
            imageHeight: normalized.height
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let metadataData = try encoder.encode(metadata)
        try metadataData.write(to: metadataURL, options: .atomic)

        return try repository.upsertScreenRecord(
            ScreenRecordInput(
                id: screenId,
                createdAt: metadata.importedAt,
                source: source,
                imagePath: originalImageURL.path,
                imageWidth: normalized.width,
                imageHeight: normalized.height,
                scenario: .unknown,
                scenarioConfidence: 0.0,
                processingVersion: processingVersion,
                lastOpenedAt: nil
            )
        )
    }
}

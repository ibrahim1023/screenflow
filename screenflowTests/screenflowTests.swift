//
//  screenflowTests.swift
//  screenflowTests
//
//  Created by Ibrahim Arshad on 2/25/26.
//

import Foundation
import Testing
import SwiftData
@testable import screenflow

struct screenflowTests {
    private struct FakeOCRExtractor: OCRExtracting {
        let spec: OCRBlockSpecV1

        func extractOCRBlockSpec(
            imageData: Data,
            source: ScreenSource,
            processingVersion: String
        ) throws -> OCRBlockSpecV1 {
            spec
        }
    }

    @MainActor
    private func makeRepository() throws -> ScreenFlowRepository {
        let schema = Schema([
            ScreenRecord.self,
            OCRArtifact.self,
            LLMResult.self,
            ExtractionResult.self,
            ActionPackRun.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let modelContext = ModelContext(container)
        return ScreenFlowRepository(modelContext: modelContext)
    }

    @Test func screenRecordStoresDeterministicFields() async throws {
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let record = ScreenRecord(
            id: "abc123",
            createdAt: fixedDate,
            source: .shareSheet,
            imagePath: "Screens/abc123.jpg",
            imageWidth: 1284,
            imageHeight: 2778,
            scenario: .jobListing,
            scenarioConfidence: 0.96,
            processingVersion: "1.0.0",
            lastOpenedAt: nil
        )

        #expect(record.id == "abc123")
        #expect(record.createdAt == fixedDate)
        #expect(record.source == ScreenSource.shareSheet)
        #expect(record.scenario == ScenarioType.jobListing)
        #expect(record.processingVersion == "1.0.0")
    }

    @Test func actionPackRunInitializesWithTypedStatus() async throws {
        let run = ActionPackRun(
            id: "run-1",
            screenId: "abc123",
            packId: "event_flyer.add_to_calendar",
            packVersion: "1.0.0",
            inputParamsJSONPath: "Runs/run-1.input.json",
            traceJSONPath: "Runs/run-1.trace.json",
            status: .success
        )

        #expect(run.status == .success)
        #expect(run.packId == "event_flyer.add_to_calendar")
        #expect(run.traceJSONPath == "Runs/run-1.trace.json")
    }

    @Test func llmResultCapturesModelAndPromptVersions() async throws {
        let result = LLMResult(
            id: "llm-1",
            screenId: "abc123",
            model: "gpt-4.1-mini",
            promptVersion: "screenflow-spec-v1",
            rawResponseJSONPath: "LLM/llm-1.raw.json",
            validatedJSONPath: "LLM/llm-1.validated.json"
        )

        #expect(result.id == "llm-1")
        #expect(result.model == "gpt-4.1-mini")
        #expect(result.promptVersion == "screenflow-spec-v1")
        #expect(result.validatedJSONPath == "LLM/llm-1.validated.json")
    }

    @MainActor
    @Test func storagePathServiceBuildsAppSupportSubdirectoryPath() async throws {
        let service = StoragePathService(rootFolderName: "ScreenFlowTest")
        let path = try service.applicationSupportPath(for: .ocr)

        #expect(path.path.contains("Application Support"))
        #expect(path.path.hasSuffix("/ScreenFlowTest/OCR"))
    }

    @MainActor
    @Test func storagePathServiceThrowsWhenAppGroupUnavailable() async throws {
        let service = StoragePathService(appGroupIdentifier: "group.invalid.screenflow")

        do {
            _ = try service.appGroupRoot()
            #expect(Bool(false))
        } catch let error as StoragePathError {
            #expect(error == .appGroupUnavailable("group.invalid.screenflow"))
        }
    }

    @MainActor
    @Test func stableScreenIdentifierIsDeterministicForSameInputs() async throws {
        let generator = StableScreenIdentifierGenerator()
        let normalizedBytes = Data([0xAA, 0xBB, 0xCC, 0xDD])

        let first = try generator.makeIdentifier(
            normalizedImageBytes: normalizedBytes,
            processingVersion: "1.0.0"
        )
        let second = try generator.makeIdentifier(
            normalizedImageBytes: normalizedBytes,
            processingVersion: "1.0.0"
        )

        #expect(first == second)
        #expect(first.count == 64)
    }

    @MainActor
    @Test func stableScreenIdentifierChangesWhenProcessingVersionChanges() async throws {
        let generator = StableScreenIdentifierGenerator()
        let normalizedBytes = Data([0xAA, 0xBB, 0xCC, 0xDD])

        let v1 = try generator.makeIdentifier(
            normalizedImageBytes: normalizedBytes,
            processingVersion: "1.0.0"
        )
        let v2 = try generator.makeIdentifier(
            normalizedImageBytes: normalizedBytes,
            processingVersion: "1.1.0"
        )

        #expect(v1 != v2)
    }

    @MainActor
    @Test func stableScreenIdentifierRejectsEmptyInputs() async throws {
        let generator = StableScreenIdentifierGenerator()

        do {
            _ = try generator.makeIdentifier(normalizedImageBytes: Data(), processingVersion: "1.0.0")
            #expect(Bool(false))
        } catch let error as StableScreenIdentifierError {
            #expect(error == .emptyNormalizedImageBytes)
        }

        do {
            _ = try generator.makeIdentifier(normalizedImageBytes: Data([0x01]), processingVersion: "")
            #expect(Bool(false))
        } catch let error as StableScreenIdentifierError {
            #expect(error == .emptyProcessingVersion)
        }
    }

    @MainActor
    @Test func repositoryUpsertsScreenRecordWithoutDuplicatingPrimaryKey() async throws {
        let repository = try makeRepository()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_100)

        _ = try repository.upsertScreenRecord(
            ScreenRecordInput(
                id: "screen-1",
                createdAt: createdAt,
                source: .photoPicker,
                imagePath: "Screens/screen-1.jpg",
                imageWidth: 1179,
                imageHeight: 2556,
                scenario: .unknown,
                scenarioConfidence: 0.0,
                processingVersion: "1.0.0",
                lastOpenedAt: nil
            )
        )

        _ = try repository.upsertScreenRecord(
            ScreenRecordInput(
                id: "screen-1",
                createdAt: createdAt,
                source: .shareSheet,
                imagePath: "Screens/screen-1.updated.jpg",
                imageWidth: 1179,
                imageHeight: 2556,
                scenario: .jobListing,
                scenarioConfidence: 0.92,
                processingVersion: "1.1.0",
                lastOpenedAt: Date(timeIntervalSince1970: 1_700_000_200)
            )
        )

        let records = try repository.listScreenRecords()
        #expect(records.count == 1)
        #expect(records[0].scenario == .jobListing)
        #expect(records[0].processingVersion == "1.1.0")
        #expect(records[0].source == .shareSheet)
    }

    @MainActor
    @Test func repositoryPersistsCorePipelineArtifacts() async throws {
        let repository = try makeRepository()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_300)

        _ = try repository.upsertOCRArtifact(
            OCRArtifactInput(
                id: "ocr-1",
                screenId: "screen-1",
                engineVersion: "vision-1",
                blocksJSONPath: "OCR/ocr-1.json",
                languageHint: "en-US",
                createdAt: createdAt
            )
        )
        _ = try repository.upsertLLMResult(
            LLMResultInput(
                id: "llm-1",
                screenId: "screen-1",
                model: "local-model",
                promptVersion: "screenflow-spec-v1",
                rawResponseJSONPath: "LLM/llm-1.raw.json",
                validatedJSONPath: "LLM/llm-1.validated.json",
                createdAt: createdAt
            )
        )
        _ = try repository.upsertExtractionResult(
            ExtractionResultInput(
                id: "extract-1",
                screenId: "screen-1",
                schemaVersion: "screenflow-spec-v1",
                entitiesJSONPath: "Extracted/extract-1.entities.json",
                intentGraphJSONPath: "Graph/extract-1.graph.json",
                createdAt: createdAt,
                userOverridesJSONPath: nil
            )
        )
        _ = try repository.upsertActionPackRun(
            ActionPackRunInput(
                id: "run-1",
                screenId: "screen-1",
                packId: "event_flyer.add_to_calendar",
                packVersion: "1.0.0",
                inputParamsJSONPath: "Runs/run-1.input.json",
                traceJSONPath: "Runs/run-1.trace.json",
                status: .success,
                createdAt: createdAt
            )
        )

        #expect(try repository.ocrArtifact(id: "ocr-1") != nil)
        #expect(try repository.llmResult(id: "llm-1")?.model == "local-model")
        #expect(try repository.extractionResult(id: "extract-1")?.schemaVersion == "screenflow-spec-v1")
        #expect(try repository.actionPackRun(id: "run-1")?.status == .success)
    }

    @MainActor
    @Test func inAppPhotoImportServiceImportsImageAndPersistsScreenRecord() async throws {
        let repository = try makeRepository()
        let rootFolderName = "ScreenFlowImportTest-\(UUID().uuidString)"
        let storage = StoragePathService(rootFolderName: rootFolderName)
        let importer = InAppPhotoImportService(
            processingVersion: "1.0.0",
            storagePathService: storage
        )

        let pngData = try #require(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7Zq4kAAAAASUVORK5CYII="))
        let record = try importer.importPhotoData(
            pngData,
            source: .photoPicker,
            repository: repository
        )

        #expect(record.imageWidth == 1)
        #expect(record.imageHeight == 1)
        #expect(record.source == .photoPicker)
        #expect(FileManager.default.fileExists(atPath: record.imagePath))

        let metadataPath = record.imagePath.replacingOccurrences(
            of: ".original.img",
            with: ".metadata.json"
        )
        let normalizedPath = record.imagePath.replacingOccurrences(
            of: ".original.img",
            with: ".normalized.png"
        )

        #expect(FileManager.default.fileExists(atPath: metadataPath))
        #expect(FileManager.default.fileExists(atPath: normalizedPath))

        let metadataData = try Data(contentsOf: URL(fileURLWithPath: metadataPath))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let metadata = try decoder.decode(ImportedImageMetadata.self, from: metadataData)

        #expect(metadata.schemaVersion == "screenshot-artifact.v1")
        #expect(metadata.screenId == record.id)
        #expect(metadata.source == ScreenSource.photoPicker.rawValue)
        #expect(metadata.originalImagePath == record.imagePath)
        #expect(metadata.imageWidth == 1)
        #expect(metadata.imageHeight == 1)
    }

    @MainActor
    @Test func deterministicImageNormalizationIsStableForSameInput() async throws {
        let normalizer = DeterministicImageNormalizationService()
        let pngData = try #require(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7Zq4kAAAAASUVORK5CYII="))

        let first = try normalizer.normalizeForHashingAndOCR(pngData)
        let second = try normalizer.normalizeForHashingAndOCR(pngData)

        #expect(first.pngData == second.pngData)
        #expect(first.width == second.width)
        #expect(first.height == second.height)
    }

    @MainActor
    @Test func ocrBlockNormalizerCanonicalizesWhitespaceAndSortOrder() async throws {
        let normalizer = OCRBlockNormalizer()
        let pageSize = OCRPageSize(width: 1179, height: 2556)
        let candidates = [
            OCRCandidate(
                text: "  role  \n title ",
                bbox: OCRBoundingBox(x: 0.3, y: 0.2, width: 0.2, height: 0.05),
                confidence: 0.923456
            ),
            OCRCandidate(
                text: "company",
                bbox: OCRBoundingBox(x: 0.1, y: 0.1, width: 0.2, height: 0.05),
                confidence: 0.812345
            )
        ]

        let spec = normalizer.makeSpec(
            candidates: candidates,
            pageSize: pageSize,
            source: .photoPicker,
            processingVersion: "1.0.0",
            languageHint: "en-US"
        )

        #expect(spec.schemaVersion == "OCRBlockSpec.v1")
        #expect(spec.blocks.count == 2)
        #expect(spec.blocks[0].text == "company")
        #expect(spec.blocks[1].text == "role title")
        #expect(spec.blocks[0].confidence == 0.8123)
    }

    @MainActor
    @Test func ocrArtifactPipelinePersistsJSONAndRepositoryArtifact() async throws {
        let repository = try makeRepository()
        let rootFolderName = "ScreenFlowOCRTest-\(UUID().uuidString)"
        let storage = StoragePathService(rootFolderName: rootFolderName)
        let importer = InAppPhotoImportService(
            processingVersion: "1.0.0",
            storagePathService: storage
        )

        let pngData = try #require(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7Zq4kAAAAASUVORK5CYII="))
        let screen = try importer.importPhotoData(
            pngData,
            source: .photoPicker,
            repository: repository
        )

        let fakeSpec = OCRBlockSpecV1(
            schemaVersion: "OCRBlockSpec.v1",
            source: ScreenSource.photoPicker.rawValue,
            processingVersion: "1.0.0",
            languageHint: "en-US",
            blocks: [
                OCRTextBlock(
                    text: "hello",
                    bbox: OCRBoundingBox(x: 0.1, y: 0.2, width: 0.3, height: 0.1),
                    pageSize: OCRPageSize(width: 1, height: 1),
                    confidence: 0.99
                )
            ]
        )

        let pipeline = OCRArtifactPipelineService(
            extractionService: FakeOCRExtractor(spec: fakeSpec),
            storagePathService: storage
        )

        let artifact = try pipeline.runOCRAndPersist(for: screen, repository: repository)
        #expect(FileManager.default.fileExists(atPath: artifact.blocksJSONPath))
        #expect(artifact.languageHint == "en-US")

        let fileData = try Data(contentsOf: URL(fileURLWithPath: artifact.blocksJSONPath))
        let decoded = try JSONDecoder().decode(OCRBlockSpecV1.self, from: fileData)
        #expect(decoded == fakeSpec)
    }

}

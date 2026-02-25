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

    @Test func storagePathServiceBuildsAppSupportSubdirectoryPath() async throws {
        let service = StoragePathService(rootFolderName: "ScreenFlowTest")
        let path = try service.applicationSupportPath(for: .ocr)

        #expect(path.path.contains("Application Support"))
        #expect(path.path.hasSuffix("/ScreenFlowTest/OCR"))
    }

    @Test func storagePathServiceThrowsWhenAppGroupUnavailable() async throws {
        let service = StoragePathService(appGroupIdentifier: "group.invalid.screenflow")

        do {
            _ = try service.appGroupRoot()
            #expect(Bool(false))
        } catch let error as StoragePathError {
            #expect(error == .appGroupUnavailable("group.invalid.screenflow"))
        }
    }

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

}

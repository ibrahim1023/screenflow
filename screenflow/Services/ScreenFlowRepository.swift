//
//  ScreenFlowRepository.swift
//  screenflow
//
//  Created by Codex on 2/25/26.
//

import Foundation
import SwiftData

struct ScreenRecordInput: Sendable {
    let id: String
    let createdAt: Date
    let source: ScreenSource
    let imagePath: String
    let imageWidth: Int
    let imageHeight: Int
    let scenario: ScenarioType
    let scenarioConfidence: Double
    let processingVersion: String
    let lastOpenedAt: Date?
}

struct OCRArtifactInput: Sendable {
    let id: String
    let screenId: String
    let engineVersion: String
    let blocksJSONPath: String
    let languageHint: String?
    let createdAt: Date
}

struct LLMResultInput: Sendable {
    let id: String
    let screenId: String
    let model: String
    let promptVersion: String
    let rawResponseJSONPath: String
    let validatedJSONPath: String
    let createdAt: Date
}

struct ExtractionResultInput: Sendable {
    let id: String
    let screenId: String
    let schemaVersion: String
    let entitiesJSONPath: String
    let intentGraphJSONPath: String
    let createdAt: Date
    let userOverridesJSONPath: String?
}

struct ActionPackRunInput: Sendable {
    let id: String
    let screenId: String
    let packId: String
    let packVersion: String
    let inputParamsJSONPath: String
    let traceJSONPath: String
    let status: ActionRunStatus
    let createdAt: Date
}

@MainActor
final class ScreenFlowRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    @discardableResult
    func upsertScreenRecord(_ input: ScreenRecordInput) throws -> ScreenRecord {
        if let existing = try screenRecord(id: input.id) {
            existing.createdAt = input.createdAt
            existing.source = input.source
            existing.imagePath = input.imagePath
            existing.imageWidth = input.imageWidth
            existing.imageHeight = input.imageHeight
            existing.scenario = input.scenario
            existing.scenarioConfidence = input.scenarioConfidence
            existing.processingVersion = input.processingVersion
            existing.lastOpenedAt = input.lastOpenedAt
            try modelContext.save()
            return existing
        }

        let record = ScreenRecord(
            id: input.id,
            createdAt: input.createdAt,
            source: input.source,
            imagePath: input.imagePath,
            imageWidth: input.imageWidth,
            imageHeight: input.imageHeight,
            scenario: input.scenario,
            scenarioConfidence: input.scenarioConfidence,
            processingVersion: input.processingVersion,
            lastOpenedAt: input.lastOpenedAt
        )
        modelContext.insert(record)
        try modelContext.save()
        return record
    }

    func screenRecord(id: String) throws -> ScreenRecord? {
        let descriptor = FetchDescriptor<ScreenRecord>(predicate: #Predicate { $0.id == id })
        return try modelContext.fetch(descriptor).first
    }

    func listScreenRecords() throws -> [ScreenRecord] {
        var descriptor = FetchDescriptor<ScreenRecord>()
        descriptor.sortBy = [SortDescriptor(\.createdAt, order: .reverse)]
        return try modelContext.fetch(descriptor)
    }

    @discardableResult
    func upsertOCRArtifact(_ input: OCRArtifactInput) throws -> OCRArtifact {
        if let existing = try ocrArtifact(id: input.id) {
            existing.screenId = input.screenId
            existing.engineVersion = input.engineVersion
            existing.blocksJSONPath = input.blocksJSONPath
            existing.languageHint = input.languageHint
            existing.createdAt = input.createdAt
            try modelContext.save()
            return existing
        }

        let artifact = OCRArtifact(
            id: input.id,
            screenId: input.screenId,
            engineVersion: input.engineVersion,
            blocksJSONPath: input.blocksJSONPath,
            languageHint: input.languageHint,
            createdAt: input.createdAt
        )
        modelContext.insert(artifact)
        try modelContext.save()
        return artifact
    }

    func ocrArtifact(id: String) throws -> OCRArtifact? {
        let descriptor = FetchDescriptor<OCRArtifact>(predicate: #Predicate { $0.id == id })
        return try modelContext.fetch(descriptor).first
    }

    @discardableResult
    func upsertLLMResult(_ input: LLMResultInput) throws -> LLMResult {
        if let existing = try llmResult(id: input.id) {
            existing.screenId = input.screenId
            existing.model = input.model
            existing.promptVersion = input.promptVersion
            existing.rawResponseJSONPath = input.rawResponseJSONPath
            existing.validatedJSONPath = input.validatedJSONPath
            existing.createdAt = input.createdAt
            try modelContext.save()
            return existing
        }

        let result = LLMResult(
            id: input.id,
            screenId: input.screenId,
            model: input.model,
            promptVersion: input.promptVersion,
            rawResponseJSONPath: input.rawResponseJSONPath,
            validatedJSONPath: input.validatedJSONPath,
            createdAt: input.createdAt
        )
        modelContext.insert(result)
        try modelContext.save()
        return result
    }

    func llmResult(id: String) throws -> LLMResult? {
        let descriptor = FetchDescriptor<LLMResult>(predicate: #Predicate { $0.id == id })
        return try modelContext.fetch(descriptor).first
    }

    @discardableResult
    func upsertExtractionResult(_ input: ExtractionResultInput) throws -> ExtractionResult {
        if let existing = try extractionResult(id: input.id) {
            existing.screenId = input.screenId
            existing.schemaVersion = input.schemaVersion
            existing.entitiesJSONPath = input.entitiesJSONPath
            existing.intentGraphJSONPath = input.intentGraphJSONPath
            existing.createdAt = input.createdAt
            existing.userOverridesJSONPath = input.userOverridesJSONPath
            try modelContext.save()
            return existing
        }

        let result = ExtractionResult(
            id: input.id,
            screenId: input.screenId,
            schemaVersion: input.schemaVersion,
            entitiesJSONPath: input.entitiesJSONPath,
            intentGraphJSONPath: input.intentGraphJSONPath,
            createdAt: input.createdAt,
            userOverridesJSONPath: input.userOverridesJSONPath
        )
        modelContext.insert(result)
        try modelContext.save()
        return result
    }

    func extractionResult(id: String) throws -> ExtractionResult? {
        let descriptor = FetchDescriptor<ExtractionResult>(predicate: #Predicate { $0.id == id })
        return try modelContext.fetch(descriptor).first
    }

    @discardableResult
    func upsertActionPackRun(_ input: ActionPackRunInput) throws -> ActionPackRun {
        if let existing = try actionPackRun(id: input.id) {
            existing.screenId = input.screenId
            existing.packId = input.packId
            existing.packVersion = input.packVersion
            existing.inputParamsJSONPath = input.inputParamsJSONPath
            existing.traceJSONPath = input.traceJSONPath
            existing.status = input.status
            existing.createdAt = input.createdAt
            try modelContext.save()
            return existing
        }

        let run = ActionPackRun(
            id: input.id,
            screenId: input.screenId,
            packId: input.packId,
            packVersion: input.packVersion,
            inputParamsJSONPath: input.inputParamsJSONPath,
            traceJSONPath: input.traceJSONPath,
            status: input.status,
            createdAt: input.createdAt
        )
        modelContext.insert(run)
        try modelContext.save()
        return run
    }

    func actionPackRun(id: String) throws -> ActionPackRun? {
        let descriptor = FetchDescriptor<ActionPackRun>(predicate: #Predicate { $0.id == id })
        return try modelContext.fetch(descriptor).first
    }
}

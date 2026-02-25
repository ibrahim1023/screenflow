//
//  ScreenRecord.swift
//  screenflow
//
//  Created by Codex on 2/25/26.
//

import Foundation
import SwiftData

enum ScreenSource: String, Codable, Sendable, CaseIterable {
    case shareSheet = "share_sheet"
    case photoPicker = "photo_picker"
}

enum ScenarioType: String, Codable, Sendable, CaseIterable {
    case unknown
    case jobListing = "job_listing"
    case eventFlyer = "event_flyer"
    case errorLog = "error_log"
}

@Model
final class ScreenRecord {
    @Attribute(.unique) var id: String
    var createdAt: Date
    var source: ScreenSource
    var imagePath: String
    var imageWidth: Int
    var imageHeight: Int
    var scenario: ScenarioType
    var scenarioConfidence: Double
    var processingVersion: String
    var lastOpenedAt: Date?

    init(
        id: String,
        createdAt: Date = Date(),
        source: ScreenSource,
        imagePath: String,
        imageWidth: Int,
        imageHeight: Int,
        scenario: ScenarioType = .unknown,
        scenarioConfidence: Double = 0.0,
        processingVersion: String,
        lastOpenedAt: Date? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.source = source
        self.imagePath = imagePath
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.scenario = scenario
        self.scenarioConfidence = scenarioConfidence
        self.processingVersion = processingVersion
        self.lastOpenedAt = lastOpenedAt
    }
}

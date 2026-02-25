//
//  ActionPackRun.swift
//  screenflow
//
//  Created by Codex on 2/25/26.
//

import Foundation
import SwiftData

enum ActionRunStatus: String, Codable, Sendable, CaseIterable {
    case success
    case failed
    case cancelled
}

@Model
final class ActionPackRun {
    @Attribute(.unique) var id: String
    var screenId: String
    var packId: String
    var packVersion: String
    var inputParamsJSONPath: String
    var traceJSONPath: String
    var status: ActionRunStatus
    var createdAt: Date

    init(
        id: String,
        screenId: String,
        packId: String,
        packVersion: String,
        inputParamsJSONPath: String,
        traceJSONPath: String,
        status: ActionRunStatus,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.screenId = screenId
        self.packId = packId
        self.packVersion = packVersion
        self.inputParamsJSONPath = inputParamsJSONPath
        self.traceJSONPath = traceJSONPath
        self.status = status
        self.createdAt = createdAt
    }
}

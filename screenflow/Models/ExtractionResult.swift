//
//  ExtractionResult.swift
//  screenflow
//
//  Created by Codex on 2/25/26.
//

import Foundation
import SwiftData

@Model
final class ExtractionResult {
    @Attribute(.unique) var id: String
    var screenId: String
    var schemaVersion: String
    var entitiesJSONPath: String
    var intentGraphJSONPath: String
    var createdAt: Date
    var userOverridesJSONPath: String?

    init(
        id: String,
        screenId: String,
        schemaVersion: String,
        entitiesJSONPath: String,
        intentGraphJSONPath: String,
        createdAt: Date = Date(),
        userOverridesJSONPath: String? = nil
    ) {
        self.id = id
        self.screenId = screenId
        self.schemaVersion = schemaVersion
        self.entitiesJSONPath = entitiesJSONPath
        self.intentGraphJSONPath = intentGraphJSONPath
        self.createdAt = createdAt
        self.userOverridesJSONPath = userOverridesJSONPath
    }
}

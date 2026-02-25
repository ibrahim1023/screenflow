//
//  OCRArtifact.swift
//  screenflow
//
//  Created by Codex on 2/25/26.
//

import Foundation
import SwiftData

@Model
final class OCRArtifact {
    @Attribute(.unique) var id: String
    var screenId: String
    var engineVersion: String
    var blocksJSONPath: String
    var languageHint: String?
    var createdAt: Date

    init(
        id: String,
        screenId: String,
        engineVersion: String,
        blocksJSONPath: String,
        languageHint: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.screenId = screenId
        self.engineVersion = engineVersion
        self.blocksJSONPath = blocksJSONPath
        self.languageHint = languageHint
        self.createdAt = createdAt
    }
}

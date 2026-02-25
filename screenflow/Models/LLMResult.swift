//
//  LLMResult.swift
//  screenflow
//
//  Created by Codex on 2/25/26.
//

import Foundation
import SwiftData

@Model
final class LLMResult {
    @Attribute(.unique) var id: String
    var screenId: String
    var model: String
    var promptVersion: String
    var rawResponseJSONPath: String
    var validatedJSONPath: String
    var createdAt: Date

    init(
        id: String,
        screenId: String,
        model: String,
        promptVersion: String,
        rawResponseJSONPath: String,
        validatedJSONPath: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.screenId = screenId
        self.model = model
        self.promptVersion = promptVersion
        self.rawResponseJSONPath = rawResponseJSONPath
        self.validatedJSONPath = validatedJSONPath
        self.createdAt = createdAt
    }
}

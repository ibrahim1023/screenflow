//
//  StoragePathService.swift
//  screenflow
//
//  Created by Codex on 2/25/26.
//

import Foundation

enum StoragePathError: Error, Equatable {
    case appGroupUnavailable(String)
}

enum StorageSubdirectory: String, CaseIterable, Sendable {
    case screens = "Screens"
    case ocr = "OCR"
    case llm = "LLM"
    case extracted = "Extracted"
    case runs = "Runs"
}

struct StoragePathService {
    let fileManager: FileManager
    let appGroupIdentifier: String
    let rootFolderName: String

    init(
        fileManager: FileManager = .default,
        appGroupIdentifier: String = "group.IbrahimArshad.screenflow.shared",
        rootFolderName: String = "ScreenFlow"
    ) {
        self.fileManager = fileManager
        self.appGroupIdentifier = appGroupIdentifier
        self.rootFolderName = rootFolderName
    }

    func applicationSupportRoot() throws -> URL {
        let directory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return directory.appendingPathComponent(rootFolderName, isDirectory: true)
    }

    func appGroupRoot() throws -> URL {
        guard let directory = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            throw StoragePathError.appGroupUnavailable(appGroupIdentifier)
        }
        return directory.appendingPathComponent(rootFolderName, isDirectory: true)
    }

    func applicationSupportPath(for subdirectory: StorageSubdirectory) throws -> URL {
        try applicationSupportRoot().appendingPathComponent(subdirectory.rawValue, isDirectory: true)
    }

    func appGroupPath(for subdirectory: StorageSubdirectory) throws -> URL {
        try appGroupRoot().appendingPathComponent(subdirectory.rawValue, isDirectory: true)
    }
}

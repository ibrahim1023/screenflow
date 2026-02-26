//
//  StableScreenIdentifierGenerator.swift
//  screenflow
//
//  Created by Codex on 2/25/26.
//

import CryptoKit
import Foundation

enum StableScreenIdentifierError: Error, Equatable {
    case emptyNormalizedImageBytes
    case emptyProcessingVersion
}

struct StableScreenIdentifierGenerator {
    private static let serializationVersion = "stable-id-v1"
    init() {}

    func makeIdentifier(
        normalizedImageBytes: Data,
        processingVersion: String
    ) throws -> String {
        guard !normalizedImageBytes.isEmpty else {
            throw StableScreenIdentifierError.emptyNormalizedImageBytes
        }
        guard !processingVersion.isEmpty else {
            throw StableScreenIdentifierError.emptyProcessingVersion
        }

        var payload = Data()
        payload.append(Data(Self.serializationVersion.utf8))
        payload.append(0x1F)
        payload.append(normalizedImageBytes)
        payload.append(0x1F)
        payload.append(Data(processingVersion.utf8))

        let digest = SHA256.hash(data: payload)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

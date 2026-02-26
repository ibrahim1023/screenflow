import CryptoKit
import Foundation
import MobileCoreServices
import UniformTypeIdentifiers
import UIKit

private enum ShareImportError: Error {
    case appGroupUnavailable
    case noImagePayload
    case encodingFailed
}

private struct ShareImportedImageMetadata: Codable {
    let schemaVersion: String
    let screenId: String
    let source: String
    let importedAt: Date
    let processingVersion: String
    let originalImagePath: String
    let originalByteCount: Int
}

final class ShareViewController: UIViewController {
    private let appGroupIdentifier = "group.IbrahimArshad.screenflow.shared"
    private let rootFolderName = "ScreenFlow"
    private let processingVersion = "1.0.0"

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        Task {
            do {
                let data = try await loadSharedImageData()
                try persistSharedImage(data)
                extensionContext?.completeRequest(returningItems: nil)
            } catch {
                let errorItem = NSError(
                    domain: "screenflow.share-extension",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Could not import shared image"]
                )
                extensionContext?.cancelRequest(withError: errorItem)
            }
        }
    }

    private func loadSharedImageData() async throws -> Data {
        guard
            let inputItems = extensionContext?.inputItems as? [NSExtensionItem]
        else {
            throw ShareImportError.noImagePayload
        }

        for item in inputItems {
            guard let attachments = item.attachments else { continue }

            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    if let url = try await loadURL(from: provider) {
                        return try Data(contentsOf: url)
                    }
                    if let data = try await loadData(from: provider) {
                        return data
                    }
                    if let image = try await loadImage(from: provider),
                       let encoded = image.pngData() {
                        return encoded
                    }
                }
            }
        }

        throw ShareImportError.noImagePayload
    }

    private func loadURL(from provider: NSItemProvider) async throws -> URL? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if let url = item as? URL {
                    continuation.resume(returning: url)
                    return
                }

                continuation.resume(returning: nil)
            }
        }
    }

    private func loadData(from provider: NSItemProvider) async throws -> Data? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: data)
            }
        }
    }

    private func loadImage(from provider: NSItemProvider) async throws -> UIImage? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadObject(ofClass: UIImage.self) { object, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: object as? UIImage)
            }
        }
    }

    private func persistSharedImage(_ data: Data) throws {
        guard !data.isEmpty else {
            throw ShareImportError.noImagePayload
        }

        guard let groupRoot = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            throw ShareImportError.appGroupUnavailable
        }

        let screensDirectory = groupRoot
            .appendingPathComponent(rootFolderName, isDirectory: true)
            .appendingPathComponent("Screens", isDirectory: true)

        try FileManager.default.createDirectory(at: screensDirectory, withIntermediateDirectories: true)

        let screenId = makeStableIdentifier(data)
        let imageURL = screensDirectory.appendingPathComponent("\(screenId).original.img", isDirectory: false)
        let metadataURL = screensDirectory.appendingPathComponent("\(screenId).metadata.json", isDirectory: false)

        try data.write(to: imageURL, options: .atomic)

        let metadata = ShareImportedImageMetadata(
            schemaVersion: "screenshot-artifact.v1",
            screenId: screenId,
            source: "share_sheet",
            importedAt: Date(),
            processingVersion: processingVersion,
            originalImagePath: imageURL.path,
            originalByteCount: data.count
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601

        guard let metadataData = try? encoder.encode(metadata) else {
            throw ShareImportError.encodingFailed
        }

        try metadataData.write(to: metadataURL, options: .atomic)
    }

    private func makeStableIdentifier(_ data: Data) -> String {
        var payload = Data("share-import-v1".utf8)
        payload.append(0x1F)
        payload.append(data)
        payload.append(0x1F)
        payload.append(Data(processingVersion.utf8))

        let digest = SHA256.hash(data: payload)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

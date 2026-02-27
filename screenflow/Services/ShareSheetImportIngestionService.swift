import Foundation

@MainActor
struct ShareSheetImportIngestionService {
    private let storagePathService: StoragePathService
    private let importer: InAppPhotoImportService

    init(
        storagePathService: StoragePathService? = nil,
        importer: InAppPhotoImportService? = nil
    ) {
        let resolvedStorage = storagePathService ?? StoragePathService()
        self.storagePathService = resolvedStorage
        self.importer = importer ?? InAppPhotoImportService(storagePathService: resolvedStorage)
    }

    func ingestPendingSharedScreens(repository: ScreenFlowRepository) throws -> Int {
        do {
            let pendingDirectory = try storagePathService.appGroupPath(for: .screens)
            return try ingestPendingSharedScreens(from: pendingDirectory, repository: repository)
        } catch let error as StoragePathError {
            if case .appGroupUnavailable = error {
                return 0
            }
            throw error
        }
    }

    func ingestPendingSharedScreens(
        from pendingDirectory: URL,
        repository: ScreenFlowRepository
    ) throws -> Int {
        let fileManager = storagePathService.fileManager
        guard fileManager.fileExists(atPath: pendingDirectory.path) else {
            return 0
        }

        let pendingFiles = try fileManager.contentsOfDirectory(
            at: pendingDirectory,
            includingPropertiesForKeys: nil
        )
        .filter { $0.lastPathComponent.hasSuffix(".original.img") }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var importedCount = 0
        for pendingFile in pendingFiles {
            let data = try Data(contentsOf: pendingFile)
            _ = try importer.importPhotoData(data, source: .shareSheet, repository: repository)
            importedCount += 1
            try cleanupPendingArtifacts(for: pendingFile, fileManager: fileManager)
        }

        return importedCount
    }

    private func cleanupPendingArtifacts(for originalFile: URL, fileManager: FileManager) throws {
        let metadataFile = URL(fileURLWithPath: originalFile.path.replacingOccurrences(of: ".original.img", with: ".metadata.json"))
        if fileManager.fileExists(atPath: metadataFile.path) {
            try fileManager.removeItem(at: metadataFile)
        }
        if fileManager.fileExists(atPath: originalFile.path) {
            try fileManager.removeItem(at: originalFile)
        }
    }
}

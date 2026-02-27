import Foundation

struct StorageBootstrapService {
    private let storagePathService: StoragePathService

    init(storagePathService: StoragePathService? = nil) {
        self.storagePathService = storagePathService ?? StoragePathService()
    }

    func prepareRequiredDirectories() throws {
        let root = try storagePathService.applicationSupportRoot()
        try storagePathService.fileManager.createDirectory(at: root, withIntermediateDirectories: true)

        for subdirectory in StorageSubdirectory.allCases {
            let path = try storagePathService.applicationSupportPath(for: subdirectory)
            try storagePathService.fileManager.createDirectory(at: path, withIntermediateDirectories: true)
        }
    }
}

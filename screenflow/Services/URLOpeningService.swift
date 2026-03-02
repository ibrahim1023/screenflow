import Foundation

protocol URLOpening: Sendable {
    func open(_ url: URL) -> Bool
}

struct NoopURLOpeningService: URLOpening {
    func open(_ url: URL) -> Bool {
        _ = url
        return false
    }
}

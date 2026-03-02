import Foundation
#if canImport(UIKit)
import UIKit
#endif

protocol ClipboardWriting: Sendable {
    func writeText(_ text: String) -> Bool
}

struct SystemClipboardService: ClipboardWriting {
    func writeText(_ text: String) -> Bool {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        return true
        #else
        _ = text
        return false
        #endif
    }
}

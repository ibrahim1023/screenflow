import Foundation
import UIKit

enum DeterministicImageNormalizationError: Error, Equatable {
    case invalidImageData
    case failedToEncodePNG
}

struct NormalizedImagePayload: Sendable {
    let pngData: Data
    let width: Int
    let height: Int
}

@MainActor
struct DeterministicImageNormalizationService {
    func normalizeForHashingAndOCR(_ data: Data) throws -> NormalizedImagePayload {
        guard let image = UIImage(data: data) else {
            throw DeterministicImageNormalizationError.invalidImageData
        }

        let pixelSize = CGSize(
            width: image.size.width * image.scale,
            height: image.size.height * image.scale
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        if #available(iOS 17.0, *) {
            format.preferredRange = .standard
        }

        let renderer = UIGraphicsImageRenderer(size: pixelSize, format: format)
        let normalizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: pixelSize))
        }

        guard
            let pngData = normalizedImage.pngData(),
            let cgImage = normalizedImage.cgImage
        else {
            throw DeterministicImageNormalizationError.failedToEncodePNG
        }

        return NormalizedImagePayload(
            pngData: pngData,
            width: cgImage.width,
            height: cgImage.height
        )
    }
}

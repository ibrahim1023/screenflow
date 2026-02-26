import Foundation
import Vision
import UIKit

enum VisionOCRServiceError: Error, Equatable {
    case invalidImageData
    case requestFailed
}

protocol OCRExtracting {
    func extractOCRBlockSpec(
        imageData: Data,
        source: ScreenSource,
        processingVersion: String
    ) throws -> OCRBlockSpecV1
}

@MainActor
struct VisionOCRService: OCRExtracting {
    let recognitionLanguages: [String]
    let automaticallyDetectsLanguage: Bool
    let engineVersion: String

    private let normalizer: OCRBlockNormalizer

    init(
        recognitionLanguages: [String] = ["en-US"],
        automaticallyDetectsLanguage: Bool = false,
        engineVersion: String = "vision-ocr-v1",
        normalizer: OCRBlockNormalizer? = nil
    ) {
        self.recognitionLanguages = recognitionLanguages
        self.automaticallyDetectsLanguage = automaticallyDetectsLanguage
        self.engineVersion = engineVersion
        self.normalizer = normalizer ?? OCRBlockNormalizer()
    }

    func extractOCRBlockSpec(
        imageData: Data,
        source: ScreenSource,
        processingVersion: String
    ) throws -> OCRBlockSpecV1 {
        guard let image = UIImage(data: imageData), let cgImage = image.cgImage else {
            throw VisionOCRServiceError.invalidImageData
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.automaticallyDetectsLanguage = automaticallyDetectsLanguage
        request.recognitionLanguages = recognitionLanguages

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            throw VisionOCRServiceError.requestFailed
        }

        let observations = request.results ?? []
        let candidates = observations.compactMap(makeCandidate(from:))
        let pageSize = OCRPageSize(width: cgImage.width, height: cgImage.height)

        return normalizer.makeSpec(
            candidates: candidates,
            pageSize: pageSize,
            source: source,
            processingVersion: processingVersion,
            languageHint: recognitionLanguages.first
        )
    }

    private func makeCandidate(from observation: VNRecognizedTextObservation) -> OCRCandidate? {
        guard let top = observation.topCandidates(1).first else {
            return nil
        }

        // Vision uses bottom-left coordinate system. Convert to top-left normalized origin.
        let x = roundTo6(Double(observation.boundingBox.minX))
        let width = roundTo6(Double(observation.boundingBox.width))
        let height = roundTo6(Double(observation.boundingBox.height))
        let yTopOrigin = roundTo6(Double(1.0 - observation.boundingBox.minY - observation.boundingBox.height))

        return OCRCandidate(
            text: top.string,
            bbox: OCRBoundingBox(x: x, y: yTopOrigin, width: width, height: height),
            confidence: Double(top.confidence)
        )
    }

    private func roundTo6(_ value: Double) -> Double {
        (value * 1_000_000).rounded() / 1_000_000
    }
}

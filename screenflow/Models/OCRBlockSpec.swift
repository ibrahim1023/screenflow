import Foundation

struct OCRBlockSpecV1: Codable, Equatable, Sendable {
    let schemaVersion: String
    let source: String
    let processingVersion: String
    let languageHint: String?
    let blocks: [OCRTextBlock]
}

struct OCRTextBlock: Codable, Equatable, Sendable {
    let text: String
    let bbox: OCRBoundingBox
    let pageSize: OCRPageSize
    let confidence: Double
}

struct OCRBoundingBox: Codable, Equatable, Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

struct OCRPageSize: Codable, Equatable, Sendable {
    let width: Int
    let height: Int
}

struct OCRCandidate: Equatable, Sendable {
    let text: String
    let bbox: OCRBoundingBox
    let confidence: Double
}

struct OCRBlockNormalizer: Sendable {
    nonisolated init() {}

    nonisolated func makeSpec(
        candidates: [OCRCandidate],
        pageSize: OCRPageSize,
        source: ScreenSource,
        processingVersion: String,
        languageHint: String?
    ) -> OCRBlockSpecV1 {
        let normalized = candidates
            .map { candidate in
                OCRCandidate(
                    text: normalizeText(candidate.text),
                    bbox: candidate.bbox,
                    confidence: roundTo4(candidate.confidence)
                )
            }
            .filter { !$0.text.isEmpty }
            .sorted { lhs, rhs in
                if lhs.bbox.y != rhs.bbox.y {
                    return lhs.bbox.y < rhs.bbox.y
                }
                if lhs.bbox.x != rhs.bbox.x {
                    return lhs.bbox.x < rhs.bbox.x
                }
                return lhs.text < rhs.text
            }

        let blocks = normalized.map { candidate in
            OCRTextBlock(
                text: candidate.text,
                bbox: candidate.bbox,
                pageSize: pageSize,
                confidence: candidate.confidence
            )
        }

        return OCRBlockSpecV1(
            schemaVersion: "OCRBlockSpec.v1",
            source: source.rawValue,
            processingVersion: processingVersion,
            languageHint: languageHint,
            blocks: blocks
        )
    }

    private nonisolated func normalizeText(_ value: String) -> String {
        value
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private nonisolated func roundTo4(_ value: Double) -> Double {
        (value * 10_000).rounded() / 10_000
    }
}

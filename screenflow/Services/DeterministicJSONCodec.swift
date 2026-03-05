import Foundation

enum DeterministicJSONCodec {
    static func makeEncoder(
        dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .deferredToDate
    ) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = dateEncodingStrategy
        return encoder
    }
}

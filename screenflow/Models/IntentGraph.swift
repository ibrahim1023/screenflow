import Foundation

struct IntentGraphV1: Codable, Equatable, Sendable {
    let schemaVersion: String
    let nodes: [IntentGraphNode]
    let edges: [IntentGraphEdge]
}

struct IntentGraphNode: Codable, Equatable, Sendable {
    let id: String
    let type: IntentGraphNodeType
    let keyPath: String
    let stringValue: String?
    let numberValue: Double?
}

enum IntentGraphNodeType: String, Codable, Equatable, Sendable {
    case scenario
    case entityGroup = "entity_group"
    case attribute
}

struct IntentGraphEdge: Codable, Equatable, Sendable {
    let id: String
    let sourceNodeID: String
    let targetNodeID: String
    let type: IntentGraphEdgeType
}

enum IntentGraphEdgeType: String, Codable, Equatable, Sendable {
    case contains
    case hasAttribute = "has_attribute"
}

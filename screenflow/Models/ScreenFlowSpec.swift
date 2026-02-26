import Foundation

struct ScreenFlowSpecV1: Codable, Equatable, Sendable {
    let schemaVersion: String
    let scenario: ScenarioType
    let scenarioConfidence: Double
    let entities: ScreenFlowEntities
    let packSuggestions: [ActionPackSuggestion]
    let modelMeta: ScreenFlowModelMeta

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case scenario
        case scenarioConfidence
        case entities
        case packSuggestions
        case modelMeta
    }

    nonisolated init(
        schemaVersion: String,
        scenario: ScenarioType,
        scenarioConfidence: Double,
        entities: ScreenFlowEntities,
        packSuggestions: [ActionPackSuggestion],
        modelMeta: ScreenFlowModelMeta
    ) {
        self.schemaVersion = schemaVersion
        self.scenario = scenario
        self.scenarioConfidence = scenarioConfidence
        self.entities = entities
        self.packSuggestions = packSuggestions
        self.modelMeta = modelMeta
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(String.self, forKey: .schemaVersion)

        let scenarioRaw = try container.decode(String.self, forKey: .scenario)
        scenario = ScenarioType(rawValue: scenarioRaw) ?? .unknown

        scenarioConfidence = try container.decode(Double.self, forKey: .scenarioConfidence)
        entities = try container.decode(ScreenFlowEntities.self, forKey: .entities)
        packSuggestions = try container.decode([ActionPackSuggestion].self, forKey: .packSuggestions)
        modelMeta = try container.decode(ScreenFlowModelMeta.self, forKey: .modelMeta)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(scenario.rawValue, forKey: .scenario)
        try container.encode(scenarioConfidence, forKey: .scenarioConfidence)
        try container.encode(entities, forKey: .entities)
        try container.encode(packSuggestions, forKey: .packSuggestions)
        try container.encode(modelMeta, forKey: .modelMeta)
    }
}

struct ScreenFlowEntities: Codable, Equatable, Sendable {
    let job: JobEntities?
    let event: EventEntities?
    let error: ErrorEntities?

    static let empty = ScreenFlowEntities(job: nil, event: nil, error: nil)
}

struct JobEntities: Codable, Equatable, Sendable {
    let company: String?
    let role: String?
    let location: String?
    let skills: [String]?
    let salaryRange: SalaryRange?
    let link: String?
}

struct SalaryRange: Codable, Equatable, Sendable {
    let min: Double?
    let max: Double?
    let currency: String?
}

struct EventEntities: Codable, Equatable, Sendable {
    let title: String?
    let dateTime: String?
    let venue: String?
    let address: String?
    let link: String?
}

struct ErrorEntities: Codable, Equatable, Sendable {
    let errorType: String?
    let message: String?
    let stackTrace: String?
    let toolName: String?
    let filePaths: [String]?
}

struct ActionPackSuggestion: Codable, Equatable, Sendable {
    let packId: String
    let confidence: Double
    let bindings: [String: String]
}

struct ScreenFlowModelMeta: Codable, Equatable, Sendable {
    let model: String
    let promptVersion: String
}

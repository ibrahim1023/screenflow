import Foundation

struct ActionPackDefinition: Codable, Equatable, Sendable {
    let id: String
    let version: String
    let scenario: ScenarioType
    let requiredBindings: [ActionPackBindingRequirement]
    let optionalBindingKeys: [String]
    let preconditions: [ActionPackPrecondition]
    let steps: [ActionPackStepDefinition]
}

struct ActionPackBindingRequirement: Codable, Equatable, Sendable {
    let key: String
    let valueType: ActionPackBindingValueType
}

enum ActionPackBindingValueType: String, Codable, Equatable, Sendable {
    case string
    case number
}

struct ActionPackPrecondition: Codable, Equatable, Sendable {
    let key: String
    let contains: String?
}

struct ActionPackStepDefinition: Codable, Equatable, Sendable {
    let id: String
    let type: ActionPackStepType
    let outputFileName: String
    let template: String?
    let sourceStepID: String?

    init(
        id: String,
        type: ActionPackStepType,
        outputFileName: String,
        template: String?,
        sourceStepID: String? = nil
    ) {
        self.id = id
        self.type = type
        self.outputFileName = outputFileName
        self.template = template
        self.sourceStepID = sourceStepID
    }
}

enum ActionPackStepType: String, Codable, Equatable, Sendable {
    case renderTextTemplate = "render_text_template"
    case exportBindingsJSON = "export_bindings_json"
    case exportJobTrackerJSON = "export_job_tracker_json"
    case createCalendarEvent = "create_calendar_event"
    case exportFile = "export_file"
    case copyTextToClipboard = "copy_text_to_clipboard"
    case openURL = "open_url"
}

struct ActionPackSelection: Equatable, Sendable {
    let pack: ActionPackDefinition
    let suggestedBindings: [String: String]
}

struct ActionPackStepTrace: Codable, Equatable, Sendable {
    let stepID: String
    let status: ActionRunStatus
    let outputPath: String?
    let message: String?
}

struct ActionPackExecutionTraceV1: Codable, Equatable, Sendable {
    let schemaVersion: String
    let runID: String
    let screenID: String
    let packID: String
    let packVersion: String
    let startedAt: Date
    let finishedAt: Date
    let status: ActionRunStatus
    let steps: [ActionPackStepTrace]
}

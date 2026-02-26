import Foundation

enum ScreenFlowModelProviderType: String, Codable, Sendable {
    case onDevice
    case selfHostedOpenModel
}

enum ScreenFlowModelRuntimeStrategy: String, Codable, Sendable {
    case onDevicePreferred
    case selfHostedOnly
}

struct ScreenFlowModelRuntimeConfiguration: Sendable {
    init(
        strategy: ScreenFlowModelRuntimeStrategy,
        onDeviceModel: String,
        selfHostedModel: String,
        selfHostedEndpoint: URL?,
        promptVersion: String
    ) {
        self.strategy = strategy
        self.onDeviceModel = onDeviceModel
        self.selfHostedModel = selfHostedModel
        self.selfHostedEndpoint = selfHostedEndpoint
        self.promptVersion = promptVersion
    }
    let strategy: ScreenFlowModelRuntimeStrategy
    let onDeviceModel: String
    let selfHostedModel: String
    let selfHostedEndpoint: URL?
    let promptVersion: String

    static func `default`() -> ScreenFlowModelRuntimeConfiguration {
        let environment = ProcessInfo.processInfo.environment
        let endpoint = environment["SCREENFLOW_LOCAL_MODEL_ENDPOINT"].flatMap(URL.init(string:))

        return ScreenFlowModelRuntimeConfiguration(
            strategy: .onDevicePreferred,
            onDeviceModel: "apple-on-device",
            selfHostedModel: environment["SCREENFLOW_LOCAL_MODEL_NAME"] ?? "llama3.1:8b-instruct-q4_K_M",
            selfHostedEndpoint: endpoint,
            promptVersion: "screenflow-spec-v1"
        )
    }
}

struct ScreenFlowModelOutput: Sendable {
    let provider: ScreenFlowModelProviderType
    let model: String
    let rawResponseText: String
}

enum ScreenFlowModelRuntimeError: Error, Equatable {
    case onDeviceUnavailable
    case selfHostedEndpointNotConfigured
    case invalidResponse
    case httpStatus(Int)
    case emptyResponse
}

protocol ScreenFlowModelProvider: Sendable {
    var type: ScreenFlowModelProviderType { get }
    var model: String { get }

    func run(request: ScreenFlowModelRequest) async throws -> String
}

struct OnDeviceScreenFlowModelProvider: ScreenFlowModelProvider {
    init(model: String) {
        self.model = model
    }
    let type: ScreenFlowModelProviderType = .onDevice
    let model: String

    func run(request: ScreenFlowModelRequest) async throws -> String {
        _ = request
        // Placeholder adapter: we still prefer this path first, and fallback to self-hosted.
        throw ScreenFlowModelRuntimeError.onDeviceUnavailable
    }
}

struct SelfHostedOpenModelProvider: ScreenFlowModelProvider {
    init(model: String, endpoint: URL) {
        self.model = model
        self.endpoint = endpoint
    }
    let type: ScreenFlowModelProviderType = .selfHostedOpenModel
    let model: String
    let endpoint: URL

    func run(request: ScreenFlowModelRequest) async throws -> String {
        var httpRequest = URLRequest(url: endpoint.appending(path: "api/chat"))
        httpRequest.httpMethod = "POST"
        httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = OllamaChatRequest(
            model: model,
            messages: [
                OllamaChatMessage(role: "system", content: request.systemPrompt),
                OllamaChatMessage(role: "user", content: request.userPrompt),
            ],
            stream: false,
            format: "json",
            options: OllamaOptions(temperature: 0)
        )
        httpRequest.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: httpRequest)
        guard let http = response as? HTTPURLResponse else {
            throw ScreenFlowModelRuntimeError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ScreenFlowModelRuntimeError.httpStatus(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
        let content = decoded.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            throw ScreenFlowModelRuntimeError.emptyResponse
        }

        return content
    }
}

struct ScreenFlowModelRuntime {
    init(configuration: ScreenFlowModelRuntimeConfiguration = .default()) {
        self.configuration = configuration
    }
    private let configuration: ScreenFlowModelRuntimeConfiguration

    func run(request: ScreenFlowModelRequest) async throws -> ScreenFlowModelOutput {
        switch configuration.strategy {
        case .selfHostedOnly:
            let provider = try selfHostedProvider()
            let output = try await provider.run(request: request)
            return ScreenFlowModelOutput(provider: provider.type, model: provider.model, rawResponseText: output)

        case .onDevicePreferred:
            let onDevice = OnDeviceScreenFlowModelProvider(model: configuration.onDeviceModel)
            do {
                let output = try await onDevice.run(request: request)
                return ScreenFlowModelOutput(provider: onDevice.type, model: onDevice.model, rawResponseText: output)
            } catch ScreenFlowModelRuntimeError.onDeviceUnavailable {
                let provider = try selfHostedProvider()
                let output = try await provider.run(request: request)
                return ScreenFlowModelOutput(provider: provider.type, model: provider.model, rawResponseText: output)
            }
        }
    }

    private func selfHostedProvider() throws -> SelfHostedOpenModelProvider {
        guard let endpoint = configuration.selfHostedEndpoint else {
            throw ScreenFlowModelRuntimeError.selfHostedEndpointNotConfigured
        }
        return SelfHostedOpenModelProvider(model: configuration.selfHostedModel, endpoint: endpoint)
    }
}

private struct OllamaChatRequest: Codable {
    let model: String
    let messages: [OllamaChatMessage]
    let stream: Bool
    let format: String
    let options: OllamaOptions
}

private struct OllamaChatMessage: Codable {
    let role: String
    let content: String
}

private struct OllamaOptions: Codable {
    let temperature: Int
}

private struct OllamaChatResponse: Codable {
    let message: OllamaChatMessage
}

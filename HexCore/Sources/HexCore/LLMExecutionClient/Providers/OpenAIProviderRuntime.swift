import Foundation

struct OpenAIProviderRuntime: LLMProviderRuntime {
    private let logger = HexLog.llm

    func run(
        config: LLMTransformationConfig,
        input: String,
        provider: LLMProvider,
        toolingPolicy: ToolingPolicy,
        toolServerEndpoint: HexToolServerEndpoint?,
        capabilities: LLMProviderCapabilities
    ) async throws -> String {
        guard let apiKey = provider.apiKey?.resolve() else {
            throw LLMExecutionError.invalidConfiguration("OpenAI provider missing API Key")
        }

        let model = provider.defaultModel ?? "gpt-4o"

        let prompt = buildLLMUserPrompt(config: config, input: input)

        // Construct request
        // Default to OpenAI API if no base URL provided
        var baseURLString = provider.baseURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        if baseURLString == nil || baseURLString?.isEmpty == true {
            baseURLString = "https://api.openai.com/v1"
        }

        guard let base = baseURLString else {
             throw LLMExecutionError.invalidConfiguration("Invalid Base URL")
        }

        // Handle path construction carefully
        let endpointURL: URL
        if base.hasSuffix("/") {
            endpointURL = URL(string: base + "chat/completions")!
        } else {
            endpointURL = URL(string: base + "/chat/completions")!
        }

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        if let org = provider.organization, !org.isEmpty {
            request.setValue(org, forHTTPHeaderField: "OpenAI-Organization")
        }

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.1
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw LLMExecutionError.invalidConfiguration("Failed to serialize request body")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
             throw LLMExecutionError.processFailed("Invalid response type")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMExecutionError.processFailed("OpenAI API error \(httpResponse.statusCode): \(errorBody)")
        }

        // Parse response
        // Response structure: { "choices": [ { "message": { "content": "..." } } ] }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMExecutionError.invalidOutput
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

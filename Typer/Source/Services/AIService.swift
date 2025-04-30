import Foundation

enum AIServiceType {
    case typer
    case openai
}

class AIService {
    static let shared = AIService()
    private init() {}

    struct TransformRequest: Codable {
        let context: String
        let instruction: String
    }

    struct TransformResponse: Codable {
        let transformed_content: String
    }

    // OpenAI chat completion request structure
    struct OpenAIChatRequest: Codable {
        let model: String
        let messages: [Message]
        let temperature: Float

        struct Message: Codable {
            let role: String
            let content: String
        }
    }

    struct OpenAIChatResponse: Codable {
        let choices: [Choice]

        struct Choice: Codable {
            let message: Message

            struct Message: Codable {
                let content: String
            }
        }
    }

    struct OpenAITranscriptionRequest: Codable {
        let file: Data
        let model: String
        let response_format: String
        let temperature: Float
    }

    struct OpenAITranscriptionResponse: Codable {
        let text: String
    }

    func transform(
        context: String,
        instruction: String,
        serviceType: AIServiceType,
        apiKey: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        switch serviceType {
        case .typer:
            transformWithTyper(context: context, instruction: instruction, apiKey: apiKey, completion: completion)
        case .openai:
            transformWithOpenAI(context: context, instruction: instruction, apiKey: apiKey, completion: completion)
        }
    }

    private func transformWithTyper(
        context: String,
        instruction: String,
        apiKey: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        var request = URLRequest(url: URL(string: "https://api.typer.to/transform")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let transformRequest = TransformRequest(
            context: context,
            instruction: instruction
        )

        request.httpBody = try? JSONEncoder().encode(transformRequest)

        let task = URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(AIError.noDataReceived))
                return
            }

            do {
                let response = try JSONDecoder().decode(TransformResponse.self, from: data)
                completion(.success(response.transformed_content))
            } catch {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response string: \(responseString)")
                }
                completion(.failure(error))
            }
        }

        task.resume()
    }

    private func transformWithOpenAI(
        context: String,
        instruction: String,
        apiKey: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let messages = [
            OpenAIChatRequest.Message(role: "system", content: "You are a helpful assistant that transforms text based on instructions."),
            OpenAIChatRequest.Message(role: "user", content: "Context:\n\(context)\n\nInstruction:\n\(instruction)"),
        ]

        let chatRequest = OpenAIChatRequest(
            model: "gpt-3.5-turbo",
            messages: messages,
            temperature: 0.0
        )

        request.httpBody = try? JSONEncoder().encode(chatRequest)

        let task = URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(AIError.noDataReceived))
                return
            }

            do {
                let response = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
                if let transformedContent = response.choices.first?.message.content {
                    completion(.success(transformedContent))
                } else {
                    completion(.failure(AIError.invalidResponse))
                }
            } catch {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response string: \(responseString)")
                }
                completion(.failure(error))
            }
        }

        task.resume()
    }

    func transcribeAudio(
        from audioURL: URL,
        serviceType: AIServiceType,
        apiKey: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        switch serviceType {
        case .typer:
            transcribeAudioWithTyper(from: audioURL, apiKey: apiKey, completion: completion)
        case .openai:
            transcribeAudioWithOpenAI(from: audioURL, apiKey: apiKey, completion: completion)
        }
    }

    private func transcribeAudioWithTyper(
        from audioURL: URL,
        apiKey: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let audioData = try? Data(contentsOf: audioURL) else {
            completion(.failure(AIError.audioFileReadError))
            return
        }

        print("Audio data size: \(audioData.count) bytes")

        let request = createTyperTranscriptionRequest(
            with: audioData,
            apiKey: apiKey
        )

        let task = URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                print("Error sending request: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(AIError.noDataReceived))
                return
            }

            do {
                let json =
                    try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                if let text = json?["text"] as? String {
                    completion(.success(text.trimmingCharacters(in: .whitespaces)))
                } else {
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("Response string: \(responseString)")
                    }
                    completion(.failure(AIError.invalidResponse))
                }
            } catch {
                completion(.failure(error))
            }
        }

        task.resume()
    }

    private func transcribeAudioWithOpenAI(
        from audioURL: URL,
        apiKey: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let audioData = try? Data(contentsOf: audioURL) else {
            completion(.failure(AIError.audioFileReadError))
            return
        }

        print("Audio data size: \(audioData.count) bytes")

        let request = createOpenAITranscriptionRequest(
            with: audioData,
            apiKey: apiKey
        )

        let task = URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                print("Error sending request: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(AIError.noDataReceived))
                return
            }

            do {
                let response = try JSONDecoder().decode(OpenAITranscriptionResponse.self, from: data)
                completion(.success(response.text.trimmingCharacters(in: .whitespaces)))
            } catch {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response string: \(responseString)")
                }
                completion(.failure(error))
            }
        }

        task.resume()
    }

    private func createTyperTranscriptionRequest(with audioData: Data, apiKey: String) -> URLRequest {
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: "https://api.typer.to/transcribe")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(
            "multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type"
        )

        var body = Data()

        // Add file data
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"recording.m4a\"\r\n")
        body.append("Content-Type: audio/m4a\r\n\r\n")
        body.append(audioData)
        body.append("\r\n")

        // Add other form fields
        let parameters = [
            "model": "whisper-large-v3-turbo",
            "temperature": "0",
            "response_format": "json",
        ]

        for (key, value) in parameters {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }

        body.append("--\(boundary)--\r\n")
        request.httpBody = body

        return request
    }

    private func createOpenAITranscriptionRequest(with audioData: Data, apiKey: String) -> URLRequest {
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(
            "multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type"
        )

        var body = Data()

        // Add file data
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"recording.m4a\"\r\n")
        body.append("Content-Type: audio/m4a\r\n\r\n")
        body.append(audioData)
        body.append("\r\n")

        // Add other form fields
        let parameters = [
            "model": "whisper-1",
            "temperature": "0",
            "response_format": "json",
        ]

        for (key, value) in parameters {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }

        body.append("--\(boundary)--\r\n")
        request.httpBody = body

        return request
    }
}

enum AIError: Error {
    case audioFileReadError
    case noDataReceived
    case invalidResponse
    case missingAPIKey
}

// Extension to append strings to Data
extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

import Foundation
import UIKit

struct AIRecognitionResult {
    let name: String
    let description: String
    let category: String
    let confidence: Float
    let additionalInfo: [String: String]
}

struct AIRecognitionResponse: Codable {
    let choices: [Choice]

    struct Choice: Codable {
        let message: Message

        struct Message: Codable {
            let content: String
        }
    }
}

class AIRecognitionService {
    private let apiKey: String
    private let baseURL: String
    private let model: String

    init(apiKey: String, baseURL: String = "https://api.openai.com/v1", model: String = "gpt-4o") {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.model = model
    }

    func recognizeObject(imageData: Data) async throws -> AIRecognitionResult {
        guard let base64Image = imageToBase64(imageData) else {
            throw AIRecognitionError.invalidImage
        }

        let requestBody = buildRequestBody(base64Image: base64Image)
        let request = buildRequest(body: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIRecognitionError.httpError((response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        let aiResponse = try JSONDecoder().decode(AIRecognitionResponse.self, from: data)
        return try parseResponse(aiResponse)
    }

    private func imageToBase64(_ data: Data) -> String? {
        guard let image = UIImage(data: data),
              let imageData = image.jpegData(compressionQuality: 0.8) else { return nil }
        return imageData.base64EncodedString()
    }

    private func buildRequestBody(base64Image: String) -> [String: Any] {
        [
            "model": model,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": """
分析图片中的主要物体，以JSON格式返回：
{"name":"名称(2-4字)","description":"描述","category":"分类","confidence":0.95,"additionalInfo":{"color":"颜色","material":"材质"}}
只返回JSON。
"""],
                        ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]]
                    ]
                ]
            ],
            "max_tokens": 500
        ]
    }

    private func buildRequest(body: [String: Any]) -> URLRequest {
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func parseResponse(_ response: AIRecognitionResponse) throws -> AIRecognitionResult {
        guard let content = response.choices.first?.message.content else {
            throw AIRecognitionError.emptyResponse
        }

        let cleaned = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleaned.data(using: .utf8) else {
            throw AIRecognitionError.parsingError
        }

        struct Parsed: Codable {
            let name: String
            let description: String
            let category: String
            let confidence: Float?
            let additionalInfo: [String: String]?
        }

        let parsed = try JSONDecoder().decode(Parsed.self, from: jsonData)
        return AIRecognitionResult(
            name: parsed.name,
            description: parsed.description,
            category: parsed.category,
            confidence: parsed.confidence ?? 0.9,
            additionalInfo: parsed.additionalInfo ?? [:]
        )
    }
}

enum AIRecognitionError: Error, LocalizedError {
    case invalidImage
    case httpError(Int)
    case emptyResponse
    case parsingError

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "无法处理图像"
        case .httpError(let c): return "HTTP错误: \(c)"
        case .emptyResponse: return "响应为空"
        case .parsingError: return "解析失败"
        }
    }
}
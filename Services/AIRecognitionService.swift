import Foundation
import UIKit

private struct ChatCompletionsResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String
    }
}

final class AIRecognitionService {
    static let recognitionPrompt = """
    你是一个收纳识别助手。请仔细分析图片中的收纳场景。

    坐标系统说明：
    - 以图片左上角为原点 (0, 0)，右下角为 (1000, 1000)
    - X 轴向右增大，Y 轴向下增大
    - 请为每个识别到的物品估算其中心点的 (coordX, coordY) 坐标
    - 坐标值为 0-1000 的整数，表示物品中心在图片中的千分比位置
    - 请尽量精确，不同物品的坐标应有明显区分

    重要要求：
    1. 请尽可能多地识别图片中的物品，无论大小都要识别，包括角落和边缘的物品。
    2. 识别画面中最适合作为定位参考的明显物品作为 anchorObject。
    3. 在 items 中列出你能辨认的所有物品，不要遗漏任何可见物品。
    4. relativeLocation 描述物品相对于 anchorObject 的位置；如果没有 anchorObject，就描述它在画面中的位置。
    5. 名称和分类使用简洁中文。
    6. confidence 取值为 0 到 1。
    7. 务必为每个物品提供准确的 coordX 和 coordY 坐标（0-1000 范围）。
    8. 不要只列出主要物品，小物品（如数据线、橡皮、笔、纸片等）也要识别。
    9. 严格禁止对同一物品重复识别，每个物品只出现一次。
    
    商品识别要求（重要）：
    1. 如果识别到的商品是品牌商品（如电子产品、日用品、食品饮料等），请提供准确的品牌名称和商品全称。
       例如：不是"保温杯"，而是"象印不锈钢保温杯"；不是"手机"，而是"iPhone 15 Pro"。
    2. 描述中应包含商品的关键特征：颜色、材质、品牌、型号、容量等可见信息。
       例如："白色不锈钢保温杯，500ml容量，象印品牌"
    3. 分类要准确：电子产品、办公用品、厨房用品、清洁用品、食品饮料、个人护理等。
    
    收纳建议要求：
    1. 请提供简洁的收纳建议（200字以内），包含以下三个方面：
       - 是否杂乱：评估当前收纳区域的整洁程度
       - 收纳合理性：分析当前物品收纳是否合理，指出不合理之处
       - 总体建议：给出整体的收纳改进建议
    2. 建议要具体实用，针对识别到的物品给出具体建议
    3. 语言简洁明了，避免冗长描述
    
    幽默评价要求（重要）：
    1. 根据收纳区域的整洁程度，给出一句幽默风趣的评价（18字以内）。
    2. 如果整齐有序：用绿色字体，给予赞扬，如"强迫症看了会流泪的整齐"、"收纳界的模范生"、"井井有条，赏心悦目"
    3. 如果一般：用黄色字体，给予鼓励，如"继续加油，胜利在望"、"潜力股，再整理一下就完美"、"差一点点就满分了"
    4. 如果杂乱：用红色字体，适度嘲讽，如"这是刚被台风刮过吗"、"考古学家的宝藏"、"创意混沌风"
    5. 要幽默有尺度，不要过于刻薄
    6. 直接写评价，不要加引号或标题
    """

    private let apiKey: String
    private let baseURL: String
    private let model: String

    init(apiKey: String, baseURL: String = "https://api.openai.com/v1", model: String = "gpt-4o") {
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        self.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func recognizeObject(imageData: Data) async throws -> AIRecognitionResult {
        guard let image = UIImage(data: imageData) else {
            throw AIRecognitionError.invalidImage
        }

        // 缩放到最大 1024px 避免 IOSurface 溢出，同时减少 token 消耗
        let resized = resizeImage(image, maxDimension: 1024)
        guard let normalizedData = resized.jpegData(compressionQuality: 0.8) else {
            throw AIRecognitionError.invalidImage
        }

        let url = try makeCompletionsURL()
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 600
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: makeRequestBody(base64Image: normalizedData.base64EncodedString()))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIRecognitionError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw AIRecognitionError.httpError(httpResponse.statusCode, message: extractErrorMessage(from: data))
        }

        let decoded = try JSONDecoder().decode(ChatCompletionsResponse.self, from: data)
        guard let rawContent = decoded.choices.first?.message.content,
              !rawContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIRecognitionError.emptyResponse
        }

        let cleanContent = stripCodeFence(from: rawContent)
        guard let jsonData = cleanContent.data(using: .utf8) else {
            throw AIRecognitionError.parsingError
        }

        do {
            return try JSONDecoder().decode(AIRecognitionResult.self, from: jsonData)
        } catch {
            print("解析失败: \(error)")
            throw AIRecognitionError.parsingError
        }
    }

    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let ratio = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        if ratio >= 1.0 { return image }
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private func makeCompletionsURL() throws -> URL {
        var normalized = baseURL
        while normalized.hasSuffix("/") {
            normalized.removeLast()
        }

        guard !normalized.isEmpty,
              let url = URL(string: normalized + "/chat/completions") else {
            throw AIRecognitionError.invalidURL
        }
        return url
    }

    private func makeRequestBody(base64Image: String) -> [String: Any] {
        let schema: [String: Any] = [
            "name": "storage_recognition",
            "strict": true,
            "schema": [
                "type": "object",
                "properties": [
                    "anchorObject": [
                        "anyOf": [
                            ["type": "string"],
                            ["type": "null"]
                        ]
                    ],
                    "items": [
                        "type": "array",
                        "items": [
                            "type": "object",
                            "properties": [
                                "name": ["type": "string"],
                                "category": ["type": "string"],
                                "relativeLocation": ["type": "string"],
                                "description": ["type": "string"],
                                "confidence": ["type": "number"],
                                "coordX": ["anyOf": [["type": "number"], ["type": "null"]]],
                                "coordY": ["anyOf": [["type": "number"], ["type": "null"]]]
                            ],
                            "required": ["name", "category", "relativeLocation", "description", "confidence", "coordX", "coordY"],
                            "additionalProperties": false
                        ]
                    ],
                    "organizingAdvice": [
                        "anyOf": [
                            ["type": "string"],
                            ["type": "null"]
                        ]
                    ],
                    "funnyComment": [
                        "anyOf": [
                            ["type": "string"],
                            ["type": "null"]
                        ]
                    ]
                ],
                "required": ["anchorObject", "items", "organizingAdvice", "funnyComment"],
                "additionalProperties": false
            ]
        ]

        return [
            "model": model,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": Self.recognitionPrompt],
                        ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]]
                    ]
                ]
            ],
            "response_format": [
                "type": "json_schema",
                "json_schema": schema
            ],
            "max_tokens": 8000
        ]
    }

    private func stripCodeFence(from content: String) -> String {
        content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractErrorMessage(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let error = object["error"] as? [String: Any],
           let message = error["message"] as? String,
           !message.isEmpty {
            return message
        }

        if let message = object["message"] as? String,
           !message.isEmpty {
            return message
        }

        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum AIRecognitionError: LocalizedError {
    case invalidImage
    case invalidURL
    case invalidResponse
    case httpError(Int, message: String?)
    case emptyResponse
    case parsingError

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "无法处理图片数据"
        case .invalidURL:
            return "API 地址无效，请检查设置页中的 Base URL"
        case .invalidResponse:
            return "服务器返回了无效响应"
        case .httpError(let statusCode, let message):
            if let message, !message.isEmpty {
                return "请求失败（\(statusCode)）：\(message)"
            }
            return "请求失败，HTTP 状态码：\(statusCode)"
        case .emptyResponse:
            return "AI 没有返回可用内容"
        case .parsingError:
            return "AI 返回内容无法解析为预期 JSON"
        }
    }
}

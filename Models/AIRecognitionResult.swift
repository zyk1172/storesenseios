import Foundation

struct AIRecognitionResult: Codable {
    let anchorObject: String?
    let items: [AIItemResult]
    let organizingAdvice: String?
    let funnyComment: String?
    let cleanlinessLevel: String?
    let cleanlinessScore: Int?
    let dimensionScores: DimensionScores?
    let mainProblems: [String]?
    /// 整图识别时输出的物品总数，用于与分割图结果校验
    let totalItemCount: Int?
}

struct AIItemResult: Codable {
    let name: String
    let category: String
    let relativeLocation: String
    let description: String
    let attributes: String
    let confidence: Float
    let coordX: Float?
    let coordY: Float?

    nonisolated init(
        name: String,
        category: String,
        relativeLocation: String,
        description: String,
        attributes: String = "",
        confidence: Float,
        coordX: Float?,
        coordY: Float?
    ) {
        self.name = name
        self.category = category
        self.relativeLocation = relativeLocation
        self.description = description
        self.attributes = attributes
        self.confidence = confidence
        self.coordX = coordX
        self.coordY = coordY
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(String.self, forKey: .category)
        relativeLocation = try container.decode(String.self, forKey: .relativeLocation)
        description = try container.decode(String.self, forKey: .description)
        attributes = (try? container.decode(String.self, forKey: .attributes)) ?? ""
        confidence = try container.decode(Float.self, forKey: .confidence)
        coordX = try? container.decode(Float.self, forKey: .coordX)
        coordY = try? container.decode(Float.self, forKey: .coordY)
    }
}

struct DimensionScores: Codable {
    /// 分类归位 (满分25)
    let categoryPlacement: Int
    /// 空间利用 (满分20)
    let spaceUsage: Int
    /// 取用便利 (满分20)
    let accessibility: Int
    /// 视觉整洁 (满分20)
    let visualTidiness: Int
    /// 安全卫生 (满分15)
    let safetyHygiene: Int

    var total: Int {
        categoryPlacement + spaceUsage + accessibility + visualTidiness + safetyHygiene
    }
}

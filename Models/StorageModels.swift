import Foundation

struct StorageGroup: Identifiable, Codable {
    let id: UUID
    var name: String
    var createdAt: Date

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
    }
}

struct StorageLocation: Identifiable, Codable {
    let id: UUID
    var name: String
    var groupName: String
    var createdAt: Date
    var updatedAt: Date
    var items: [StorageItem]
    var backgroundImageData: Data?
    var coverImageData: Data?
    var anchorItemName: String?
    var inputType: InputType?
    var organizingAdvice: String?
    var funnyComment: String?
    var cleanlinessLevel: String?
    var cleanlinessScore: Int?
    var mainProblems: [String]?

    enum InputType: String, Codable {
        case imageRecognition
        case textInput
    }

    init(name: String, groupName: String = "默认") {
        self.id = UUID()
        self.name = name
        self.groupName = groupName
        self.createdAt = Date()
        self.updatedAt = Date()
        self.items = []
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        groupName = (try? container.decode(String.self, forKey: .groupName)) ?? "默认"
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        items = try container.decode([StorageItem].self, forKey: .items)
        backgroundImageData = try? container.decode(Data.self, forKey: .backgroundImageData)
        coverImageData = try? container.decode(Data.self, forKey: .coverImageData)
        anchorItemName = try? container.decode(String.self, forKey: .anchorItemName)
        inputType = try? container.decode(InputType.self, forKey: .inputType)
        organizingAdvice = try? container.decode(String.self, forKey: .organizingAdvice)
        funnyComment = try? container.decode(String.self, forKey: .funnyComment)
        cleanlinessLevel = try? container.decode(String.self, forKey: .cleanlinessLevel)
        cleanlinessScore = try? container.decode(Int.self, forKey: .cleanlinessScore)
        mainProblems = try? container.decode([String].self, forKey: .mainProblems)
    }

    mutating func clearRecognizedContent() {
        items = []
        backgroundImageData = nil
        coverImageData = nil
        anchorItemName = nil
        inputType = nil
        organizingAdvice = nil
        funnyComment = nil
        cleanlinessLevel = nil
        cleanlinessScore = nil
        mainProblems = nil
        updatedAt = Date()
    }
}

struct StorageItem: Identifiable, Codable {
    let id: UUID
    var name: String
    var category: String
    var description: String
    var attributes: String
    var relativeLocation: String
    var confidence: Float
    var createdAt: Date
    var coordX: Float?
    var coordY: Float?
    /// 标记为已验证：描述和定位准确，下次识别可复用
    var isVerified: Bool

    init(name: String, category: String, relativeLocation: String, description: String, attributes: String = "", confidence: Float, coordX: Float? = nil, coordY: Float? = nil, isVerified: Bool = false) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.relativeLocation = relativeLocation
        self.description = description
        self.attributes = attributes
        self.confidence = confidence
        self.coordX = coordX
        self.coordY = coordY
        self.isVerified = isVerified
        self.createdAt = Date()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(String.self, forKey: .category)
        description = try container.decode(String.self, forKey: .description)
        attributes = (try? container.decode(String.self, forKey: .attributes)) ?? ""
        relativeLocation = try container.decode(String.self, forKey: .relativeLocation)
        confidence = try container.decode(Float.self, forKey: .confidence)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        coordX = try? container.decode(Float.self, forKey: .coordX)
        coordY = try? container.decode(Float.self, forKey: .coordY)
        isVerified = (try? container.decode(Bool.self, forKey: .isVerified)) ?? false
    }
}

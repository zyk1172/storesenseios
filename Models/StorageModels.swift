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
    var organizingAdvice: String?  // AI生成的收纳建议
    var funnyComment: String?  // AI生成的幽默评价

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
    }
}

struct StorageItem: Identifiable, Codable {
    let id: UUID
    var name: String
    var category: String
    var description: String
    var relativeLocation: String
    var confidence: Float
    var createdAt: Date
    /// 物品在图片中的 X 坐标 (0-1000, 左上角为原点)
    var coordX: Float?
    /// 物品在图片中的 Y 坐标 (0-1000, 左上角为原点)
    var coordY: Float?

    init(name: String, category: String, relativeLocation: String, description: String, confidence: Float, coordX: Float? = nil, coordY: Float? = nil) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.relativeLocation = relativeLocation
        self.description = description
        self.confidence = confidence
        self.coordX = coordX
        self.coordY = coordY
        self.createdAt = Date()
    }
}


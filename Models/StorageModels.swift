import Foundation

struct StorageLocation: Identifiable, Codable {
    let id: UUID
    var name: String
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

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.updatedAt = Date()
        self.items = []
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


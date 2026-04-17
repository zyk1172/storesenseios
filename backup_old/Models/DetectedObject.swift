import Foundation
import SwiftUI

struct DetectedObject: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String
    var category: String
    var position: Position3D
    var imageData: Data?
    var thumbnailData: Data?
    var createdAt: Date
    var updatedAt: Date
    var confidence: Float
    var additionalInfo: [String: String]

    init(
        name: String,
        description: String,
        category: String,
        position: Position3D,
        imageData: Data? = nil,
        thumbnailData: Data? = nil,
        confidence: Float = 1.0,
        additionalInfo: [String: String] = [:]
    ) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.category = category
        self.position = position
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.createdAt = Date()
        self.updatedAt = Date()
        self.confidence = confidence
        self.additionalInfo = additionalInfo
    }

    var thumbnail: Image? {
        guard let data = thumbnailData,
              let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
    }
}

struct Position3D: Codable {
    var x: Float
    var y: Float
    var z: Float

    init(x: Float, y: Float, z: Float) {
        self.x = x
        self.y = y
        self.z = z
    }

    static let zero = Position3D(x: 0, y: 0, z: 0)
}
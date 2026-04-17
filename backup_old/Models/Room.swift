import Foundation

struct Room: Identifiable, Codable {
    let id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var objects: [DetectedObject]
    var meshData: Data?
    var anchorData: Data?

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.updatedAt = Date()
        self.objects = []
    }

    mutating func addObject(_ object: DetectedObject) {
        objects.append(object)
        updatedAt = Date()
    }

    mutating func removeObject(_ objectId: UUID) {
        objects.removeAll { $0.id == objectId }
        updatedAt = Date()
    }
}
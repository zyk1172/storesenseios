import Foundation

class ObjectStorageService {
    private let fileManager = FileManager.default

    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var roomsFile: URL {
        documentsDirectory.appendingPathComponent("rooms.json")
    }

    func saveRoom(_ room: Room) {
        var rooms = fetchAllRooms()
        if let index = rooms.firstIndex(where: { $0.id == room.id }) {
            rooms[index] = room
        } else {
            rooms.append(room)
        }
        saveRooms(rooms)
    }

    func fetchAllRooms() -> [Room] {
        guard let data = try? Data(contentsOf: roomsFile),
              let rooms = try? JSONDecoder().decode([Room].self, from: data) else {
            return []
        }
        return rooms
    }

    func deleteRoom(_ room: Room) {
        var rooms = fetchAllRooms()
        rooms.removeAll { $0.id == room.id }
        saveRooms(rooms)
    }

    private func saveRooms(_ rooms: [Room]) {
        guard let data = try? JSONEncoder().encode(rooms) else { return }
        try? data.write(to: roomsFile)
    }

    func searchObjects(query: String) -> [(room: Room, object: DetectedObject)] {
        let rooms = fetchAllRooms()
        let lowercasedQuery = query.lowercased()

        return rooms.flatMap { room in
            room.objects.compactMap { object in
                if object.name.lowercased().contains(lowercasedQuery) ||
                   object.description.lowercased().contains(lowercasedQuery) ||
                   object.category.lowercased().contains(lowercasedQuery) {
                    return (room, object)
                }
                return nil
            }
        }
    }
}
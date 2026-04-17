import SwiftUI
import Combine

class AppState: ObservableObject {
    @Published var currentRoom: Room?
    @Published var rooms: [Room] = []
    @Published var isScanning: Bool = false
    @Published var isProcessing: Bool = false

    private let storageService = ObjectStorageService()
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadRooms()
    }

    func loadRooms() {
        rooms = storageService.fetchAllRooms()
    }

    func createRoom(name: String) -> Room {
        let room = Room(name: name)
        storageService.saveRoom(room)
        rooms.append(room)
        currentRoom = room
        return room
    }

    func deleteRoom(_ room: Room) {
        storageService.deleteRoom(room)
        rooms.removeAll { $0.id == room.id }
        if currentRoom?.id == room.id {
            currentRoom = nil
        }
    }
}
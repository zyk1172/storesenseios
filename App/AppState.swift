import SwiftUI
import Combine

class AppState: ObservableObject {
    /// 当前选中的收纳位（如某个抽屉）
    @Published var currentRoom: StorageLocation?
    /// 所有已保存的收纳位列表
    @Published var rooms: [StorageLocation] = []
    
    /// UI 状态控制
    @Published var isScanning: Bool = false 
    @Published var isProcessing: Bool = false

    private let storageService = ObjectStorageService()

    init() {
        loadRooms()
        // 启动时重建搜索索引
        rebuildSearchIndex()
    }

    func loadRooms() {
        rooms = storageService.fetchAllRooms()
    }

    func createRoom(name: String) -> StorageLocation {
        let room = StorageLocation(name: name)
        storageService.saveRoom(room)
        loadRooms() // 重新加载以保持同步
        currentRoom = room
        return room
    }

    func deleteRoom(_ room: StorageLocation) {
        storageService.deleteRoom(room)
        rooms.removeAll { $0.id == room.id }
        if currentRoom?.id == room.id {
            currentRoom = nil
        }
    }
    
    func rebuildSearchIndex() {
        storageService.rebuildSearchIndex()
    }
    
    func clearSearchIndex() {
        storageService.clearSearchIndex()
    }
}

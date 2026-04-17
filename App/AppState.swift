import SwiftUI
import Combine

class AppState: ObservableObject {
    /// 当前选中的收纳位（如某个抽屉）
    @Published var currentRoom: StorageLocation?
    /// 所有已保存的收纳位列表
    @Published var rooms: [StorageLocation] = []
    /// 所有收纳组
    @Published var groups: [StorageGroup] = []

    /// UI 状态控制
    @Published var isScanning: Bool = false
    @Published var isProcessing: Bool = false

    private let storageService = ObjectStorageService()

    init() {
        loadRooms()
        loadGroups()
        ensureDefaultGroup()
        rebuildSearchIndex()
    }

    func loadRooms() {
        rooms = storageService.fetchAllRooms()
    }

    func loadGroups() {
        groups = storageService.fetchAllGroups()
    }

    private func ensureDefaultGroup() {
        if !groups.contains(where: { $0.name == "默认" }) {
            let defaultGroup = StorageGroup(name: "默认")
            storageService.saveGroup(defaultGroup)
            loadGroups()
        }
    }

    func createRoom(name: String, groupName: String = "默认") -> StorageLocation {
        let room = StorageLocation(name: name, groupName: groupName)
        storageService.saveRoom(room)
        loadRooms()
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

    func createGroup(name: String) -> StorageGroup {
        let group = StorageGroup(name: name)
        storageService.saveGroup(group)
        loadGroups()
        return group
    }

    func deleteGroup(_ group: StorageGroup) {
        // 将该组下的收纳位移到默认组
        for room in rooms where room.groupName == group.name {
            var movedRoom = room
            movedRoom.groupName = "默认"
            storageService.saveRoom(movedRoom)
        }
        storageService.deleteGroup(group)
        loadGroups()
        loadRooms()
    }

    func renameGroup(_ group: StorageGroup, newName: String) {
        let oldName = group.name
        // 更新该组下所有收纳位的组名
        for room in rooms where room.groupName == oldName {
            var movedRoom = room
            movedRoom.groupName = newName
            storageService.saveRoom(movedRoom)
        }
        var updatedGroup = group
        updatedGroup.name = newName
        storageService.saveGroup(updatedGroup)
        loadGroups()
        loadRooms()
    }

    func rebuildSearchIndex() {
        storageService.rebuildSearchIndex()
    }

    func clearSearchIndex() {
        storageService.clearSearchIndex()
    }
}

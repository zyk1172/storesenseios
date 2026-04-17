import Foundation

class ObjectStorageService {
    private let fileManager = FileManager.default
    private var storageURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("storage_locations.json")
    }
    
    private let searchIndexService = SearchIndexService.shared

    /// 🚀 保存或更新：根据 ID 匹配，存在则覆盖（实现更新功能）
    func saveRoom(_ location: StorageLocation) {
        var all = fetchAllRooms()
        if let index = all.firstIndex(where: { $0.id == location.id }) {
            // 更新房间时，先删除旧索引
            searchIndexService.removeRoomIndex(all[index])
            all[index] = location
        } else {
            all.append(location)
        }
        
        if let data = try? JSONEncoder().encode(all) {
            try? data.write(to: storageURL)
        }
        
        // 为新物品创建搜索索引和NSUserActivity
        for item in location.items {
            searchIndexService.indexItem(item, in: location)
            searchIndexService.activateUserActivity(for: item, in: location)
        }
    }

    func fetchAllRooms() -> [StorageLocation] {
        guard let data = try? Data(contentsOf: storageURL),
              let locations = try? JSONDecoder().decode([StorageLocation].self, from: data) else {
            return []
        }
        return locations
    }

    func deleteRoom(_ location: StorageLocation) {
        var all = fetchAllRooms()
        all.removeAll { $0.id == location.id }
        if let data = try? JSONEncoder().encode(all) {
            try? data.write(to: storageURL)
        }
        
        // 删除房间的所有搜索索引
        searchIndexService.removeRoomIndex(location)
    }

    func searchObjects(query: String) -> [(location: StorageLocation, item: StorageItem)] {
        let all = fetchAllRooms()
        let q = query.lowercased()
        var results: [(location: StorageLocation, item: StorageItem)] = []
        
        for loc in all {
            // 搜索普通物品
            for item in loc.items {
                if item.name.lowercased().contains(q) || 
                   item.description.lowercased().contains(q) ||
                   item.category.lowercased().contains(q) {
                    results.append((loc, item))
                }
            }
            
            // 搜索锚点物品（如果不在items列表中，才添加虚拟物品）
            if let anchorName = loc.anchorItemName, anchorName.lowercased().contains(q) {
                // 检查锚点物品是否已在items中
                let anchorExists = loc.items.contains { $0.name.lowercased() == anchorName.lowercased() }
                if !anchorExists {
                    // 创建一个虚拟的StorageItem来表示锚点物品
                    let anchorItem = StorageItem(
                        name: anchorName,
                        category: "基准物品",
                        relativeLocation: "当前位置的参考基准",
                        description: "这是\(loc.name)的基准物品",
                        confidence: 1.0
                    )
                    results.append((loc, anchorItem))
                }
            }
        }
        
        return results
    }
    
    // 重建所有搜索索引
    func rebuildSearchIndex() {
        searchIndexService.indexAllItems()
    }
    
    // 清空所有搜索索引
    func clearSearchIndex() {
        searchIndexService.clearAllIndexes()
    }
}

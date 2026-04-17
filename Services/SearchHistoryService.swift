import Foundation

struct SearchHistoryItem: Codable, Identifiable {
    let id: UUID
    let query: String       // 搜索关键词
    let itemName: String    // 找到/点击的物品名
    let locationName: String // 所在收纳位
    let timestamp: Date

    init(query: String, itemName: String, locationName: String) {
        self.id = UUID()
        self.query = query
        self.itemName = itemName
        self.locationName = locationName
        self.timestamp = Date()
    }
}

class SearchHistoryService {
    private let fileManager = FileManager.default
    private var storageURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("search_history.json")
    }

    /// 保存一条搜索记录
    func addRecord(_ item: SearchHistoryItem) {
        var all = fetchAll()
        all.append(item)
        // 只保留最近 200 条
        if all.count > 200 {
            all = Array(all.suffix(200))
        }
        save(all)
    }

    /// 获取所有搜索记录（按时间倒序）
    func fetchAll() -> [SearchHistoryItem] {
        guard let data = try? Data(contentsOf: storageURL),
              let items = try? JSONDecoder().decode([SearchHistoryItem].self, from: data) else {
            return []
        }
        return items.sorted { $0.timestamp > $1.timestamp }
    }

    /// 最近查找（取最近 N 条）
    func recentSearches(limit: Int = 10) -> [SearchHistoryItem] {
        Array(fetchAll().prefix(limit))
    }

    /// 最常查找（按物品名统计频次）
    func mostSearched(limit: Int = 10) -> [(itemName: String, count: Int, locationName: String)] {
        let all = fetchAll()
        var freq: [String: (count: Int, locationName: String)] = [:]
        for item in all {
            let key = item.itemName
            if freq[key] != nil {
                freq[key]!.count += 1
            } else {
                freq[key] = (count: 1, locationName: item.locationName)
            }
        }
        return freq.map { (itemName: $0.key, count: $0.value.count, locationName: $0.value.locationName) }
            .sorted { $0.count > $1.count }
            .prefix(limit)
            .map { $0 }
    }

    private func save(_ items: [SearchHistoryItem]) {
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: storageURL)
        }
    }
    
    /// 清空所有搜索记录
    func clearAllHistory() {
        try? FileManager.default.removeItem(at: storageURL)
    }
}

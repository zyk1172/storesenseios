import SwiftUI
import CoreSpotlight
import AppIntents

struct ContentView: View {
    @State private var selectedTab: Tab = .scan
    @State private var searchResultItem: StorageItem?
    @State private var searchResultRoom: StorageLocation?
    @State private var showSearchResult = false

    enum Tab {
        case scan, detect, map, search
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ScanView(selectedTab: $selectedTab)
                .tabItem {
                    Label("收纳位", systemImage: "cube.transparent")
                }
                .tag(Tab.scan)

            DetectView()
                .tabItem {
                    Label("识别", systemImage: "camera.viewfinder")
                }
                .tag(Tab.detect)

            MapView()
                .tabItem {
                    Label("统计", systemImage: "chart.bar.fill")
                }
                .tag(Tab.map)

            SearchView()
                .tabItem {
                    Label("搜索", systemImage: "magnifyingglass")
                }
                .tag(Tab.search)
        }
        .onAppear {
            if #available(iOS 16.0, *) {
                // 注册 Siri App Shortcuts
                StoreSenseShortcuts.updateAppShortcutParameters()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FindItemBySiri"))) { notification in
            // 监听由 Siri 唤醒的 AppIntent 派发的通知
            if let itemName = notification.object as? String {
                findAndShowItemByName(itemName)
            }
        }
        .onContinueUserActivity("zhengyk.StoreSense.search") { userActivity in
            handleSearchResult(userActivity)
        }
        .onContinueUserActivity(CSSearchableItemActionType) { userActivity in
            handleSpotlightSearch(userActivity)
        }
        .sheet(isPresented: $showSearchResult) {
            if let item = searchResultItem, let room = searchResultRoom {
                ItemDetailView(
                    item: item,
                    location: room,
                    onItemChanged: { _ in },
                    onItemDeleted: { }
                )
            }
        }
    }
    
    // MARK: - 搜索处理
    
    private func findAndShowItemByName(_ name: String) {
        let storageService = ObjectStorageService()
        let rooms = storageService.fetchAllRooms()
        
        for room in rooms {
            // 模糊匹配物品名称
            if let item = room.items.first(where: { $0.name.lowercased().contains(name.lowercased()) }) {
                searchResultItem = item
                searchResultRoom = room
                showSearchResult = true
                return
            }
        }
    }
    
    private func handleSearchResult(_ userActivity: NSUserActivity) {
        guard let identifier = userActivity.userInfo?["identifier"] as? String else {
            return
        }
        findAndShowItem(identifier: identifier)
    }
    
    private func handleSpotlightSearch(_ userActivity: NSUserActivity) {
        guard let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String else {
            return
        }
        findAndShowItem(identifier: identifier)
    }
    
    private func findAndShowItem(identifier: String) {
        // 解析物品ID
        let components = identifier.split(separator: ".")
        guard components.count >= 3, let itemUUID = components.last else {
            return
        }
        
        let itemId = String(itemUUID)
        let storageService = ObjectStorageService()
        let rooms = storageService.fetchAllRooms()
        
        for room in rooms {
            if let item = room.items.first(where: { $0.id.uuidString == itemId }) {
                searchResultItem = item
                searchResultRoom = room
                showSearchResult = true
                return
            }
        }
    }
}

// MARK: - Siri / AppIntents 支持

// 1. 定义一个 AppEntity 让 Siri 能理解我们的“收纳物品”
@available(iOS 16.0, *)
struct StorageItemEntity: AppEntity {
    var id: String
    var name: String

    static var defaultQuery = StorageItemQuery()
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "收纳物品"

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

// 2. 为 AppEntity 提供查询器，Siri 会用它来检索匹配的物品
@available(iOS 16.0, *)
struct StorageItemQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [String]) async throws -> [StorageItemEntity] {
        let storageService = ObjectStorageService()
        let rooms = storageService.fetchAllRooms()
        var results: [StorageItemEntity] = []
        for room in rooms {
            for item in room.items {
                if identifiers.contains(item.id.uuidString) {
                    results.append(StorageItemEntity(id: item.id.uuidString, name: item.name))
                }
            }
        }
        return results
    }

    @MainActor
    func suggestedEntities() async throws -> [StorageItemEntity] {
        let storageService = ObjectStorageService()
        let rooms = storageService.fetchAllRooms()
        return rooms.flatMap { $0.items }.map { StorageItemEntity(id: $0.id.uuidString, name: $0.name) }
    }

    @MainActor
    func entities(matching string: String) async throws -> [StorageItemEntity] {
        let storageService = ObjectStorageService()
        let rooms = storageService.fetchAllRooms()
        return rooms.flatMap { $0.items }
            .filter { $0.name.lowercased().contains(string.lowercased()) }
            .map { StorageItemEntity(id: $0.id.uuidString, name: $0.name) }
    }
}

// 3. 意图定义
@available(iOS 16.0, *)
struct FindItemIntent: AppIntent {
    static var title: LocalizedStringResource = "查找物品"
    static var description = IntentDescription("在收纳助手中查找物品的位置。")
    
    // 使用 AppEntity 作为参数
    @Parameter(title: "物品")
    var item: StorageItemEntity
    
    // 唤醒并打开 App
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // 通过 NotificationCenter 通知 ContentView 展示物品详情
        NotificationCenter.default.post(name: NSNotification.Name("FindItemBySiri"), object: item.name)
        return .result()
    }
}

// 4. 定义短语（所有短语必须包含 \(.applicationName)）
@available(iOS 16.0, *)
struct StoreSenseShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: FindItemIntent(),
            phrases: [
                "用 \(.applicationName) 找 \(\.$item)",
                "在 \(.applicationName) 里面我的 \(\.$item) 在哪",
                "让 \(.applicationName) 查找 \(\.$item)"
            ],
            shortTitle: "查找物品",
            systemImageName: "magnifyingglass"
        )
    }
}


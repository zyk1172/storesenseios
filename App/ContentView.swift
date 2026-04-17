import SwiftUI
import CoreSpotlight

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
        
        // 查找物品
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppState())
    }
}

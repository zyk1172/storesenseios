import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .scan

    enum Tab {
        case scan, detect, map, search
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ScanView()
                .tabItem {
                    Label("扫描", systemImage: "cube.transparent")
                }
                .tag(Tab.scan)

            DetectView()
                .tabItem {
                    Label("识别", systemImage: "camera.viewfinder")
                }
                .tag(Tab.detect)

            MapView()
                .tabItem {
                    Label("地图", systemImage: "map")
                }
                .tag(Tab.map)

            SearchView()
                .tabItem {
                    Label("搜索", systemImage: "magnifyingglass")
                }
                .tag(Tab.search)
        }
    }
}

#Preview {
    ContentView()
}
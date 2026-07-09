import SwiftUI

@main
struct StoreSenseApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var llmManager = LLMManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(llmManager)
        }
    }
}

import Foundation
import Combine
import SwiftUI

class LLMManager: ObservableObject {
    @Published var providers: [LLMProvider] = []

    private let userDefaultsKey = "llm_providers"
    private let keychainService = "com.zhengyk.StoreSense.LLM"

    var activeProvider: LLMProvider? {
        providers.first { $0.isActive }
    }

    struct CurrentConfig {
        let apiKey: String
        let baseURL: String
        let model: String
    }

    var currentConfig: CurrentConfig {
        if let active = activeProvider {
            return CurrentConfig(
                apiKey: loadKey(for: active.id),
                baseURL: active.baseURL,
                model: active.currentModel
            )
        }
        return CurrentConfig(apiKey: "", baseURL: "https://api.openai.com/v1", model: "gpt-4o")
    }

    init() {
        loadProviders()
        if providers.isEmpty {
            let defaultProvider = LLMProvider(name: "默认模型", baseURL: "https://api.openai.com/v1", model: "gpt-4o", isActive: true)
            providers = [defaultProvider]
            saveProviders()
        }
        if !providers.contains(where: { $0.isActive }) {
            providers[0].isActive = true
            saveProviders()
        }
    }

    // MARK: - Provider CRUD

    func addProvider(_ provider: LLMProvider) {
        var p = provider
        if providers.isEmpty { p.isActive = true }
        providers.append(p)
        saveProviders()
    }

    func updateProvider(_ provider: LLMProvider) {
        if let idx = providers.firstIndex(where: { $0.id == provider.id }) {
            providers[idx] = provider
            saveProviders()
        }
    }

    func deleteProvider(_ provider: LLMProvider) {
        providers.removeAll { $0.id == provider.id }
        deleteKey(for: provider.id)
        if provider.isActive, !providers.isEmpty {
            providers[0].isActive = true
        }
        saveProviders()
    }

    func setActive(_ provider: LLMProvider) {
        for i in providers.indices {
            providers[i].isActive = (providers[i].id == provider.id)
        }
        saveProviders()
    }

    func selectModel(in providerID: UUID, modelIndex: Int) {
        if let idx = providers.firstIndex(where: { $0.id == providerID }) {
            providers[idx].selectedModelIndex = modelIndex
            saveProviders()
        }
    }

    // MARK: - Keychain

    func saveKey(_ key: String, for providerID: UUID) {
        let account = "llm_\(providerID.uuidString)"
        let data = Data(key.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        guard !key.isEmpty else { return }
        var newQuery = query
        newQuery[kSecValueData as String] = data
        SecItemAdd(newQuery as CFDictionary, nil)
    }

    func loadKey(for providerID: UUID) -> String {
        let account = "llm_\(providerID.uuidString)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var ref: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &ref)
        if status == errSecSuccess, let data = ref as? Data {
            return String(decoding: data, as: UTF8.self)
        }
        return ""
    }

    private func deleteKey(for providerID: UUID) {
        let account = "llm_\(providerID.uuidString)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Persistence

    private func saveProviders() {
        if let data = try? JSONEncoder().encode(providers) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    private func loadProviders() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let list = try? JSONDecoder().decode([LLMProvider].self, from: data) else {
            return
        }
        providers = list
    }
}

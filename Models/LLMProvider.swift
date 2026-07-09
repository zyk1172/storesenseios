import Foundation

struct LLMProvider: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var baseURL: String
    var models: [String]
    var selectedModelIndex: Int
    var isActive: Bool

    /// 当前选中的模型 ID
    var currentModel: String {
        guard !models.isEmpty, selectedModelIndex >= 0, selectedModelIndex < models.count else {
            return models.first ?? ""
        }
        return models[selectedModelIndex]
    }

    init(id: UUID = UUID(), name: String, baseURL: String, models: [String], selectedModelIndex: Int = 0, isActive: Bool = false) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.models = models.isEmpty ? [""] : models
        self.selectedModelIndex = min(selectedModelIndex, self.models.count - 1)
        self.isActive = isActive
    }

    /// 兼容旧版：单模型初始化
    init(id: UUID = UUID(), name: String, baseURL: String, model: String, isActive: Bool = false) {
        self.init(id: id, name: name, baseURL: baseURL, models: [model], isActive: isActive)
    }

    static func == (lhs: LLMProvider, rhs: LLMProvider) -> Bool {
        lhs.id == rhs.id
    }
}

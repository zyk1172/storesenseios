import SwiftUI
import UniformTypeIdentifiers

// 显式实现 Codable 并标记为 nonisolated，消除 Swift 6 并发警告
struct BackupData: Codable, Sendable {
    let rooms: [StorageLocation]
    let groups: [StorageGroup]
    
    // 这里存储的是 AES-GCM 加密后的密文，不再是明文了！
    let apiKey: String?
    
    let baseURL: String?
    let model: String?
    
    enum CodingKeys: String, CodingKey {
        case rooms
        case groups
        case apiKey
        case baseURL
        case model
    }
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.rooms = try container.decode([StorageLocation].self, forKey: .rooms)
        self.groups = try container.decode([StorageGroup].self, forKey: .groups)
        self.apiKey = try container.decodeIfPresent(String.self, forKey: .apiKey)
        self.baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL)
        self.model = try container.decodeIfPresent(String.self, forKey: .model)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rooms, forKey: .rooms)
        try container.encode(groups, forKey: .groups)
        // 允许导出，因为已经在外部加密了
        try container.encodeIfPresent(apiKey, forKey: .apiKey)
        try container.encodeIfPresent(baseURL, forKey: .baseURL)
        try container.encodeIfPresent(model, forKey: .model)
    }
    
    init(rooms: [StorageLocation], groups: [StorageGroup], apiKey: String?, baseURL: String?, model: String?) {
        self.rooms = rooms
        self.groups = groups
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.model = model
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: BackupData

    init(data: BackupData) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let fileData = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        let decoder = JSONDecoder()
        self.data = try decoder.decode(BackupData.self, from: fileData)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let encodedData = try encoder.encode(self.data)
        return FileWrapper(regularFileWithContents: encodedData)
    }
}

struct SettingsView: View {
    // 使用 State 绑定，底层数据由 Keychain 托管
    @State private var apiKey = ""
    
    @AppStorage("openai_base_url") private var baseURL = "https://api.openai.com/v1"
    @AppStorage("openai_model") private var model = "gpt-4o"
    @State private var showKey = false
    @State private var isTesting = false
    @State private var testResult: String?
    
    // 备份与恢复状态
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var exportDoc: BackupDocument?
    @State private var backupMessage: String?
    
    // 索引操作反馈状态
    @State private var isRebuildingIndex = false
    @State private var showIndexAlert = false
    @State private var indexAlertMessage = ""

    @EnvironmentObject var appState: AppState

    // 预设模型选项 (使用 String(localized:) 以支持多语言提取)
    private let presetModels = [
        (String(localized: "ChatGPT (gpt-4o)"), "gpt-4o"),
        (String(localized: "DeepSeek (deepseek-chat)"), "deepseek-chat"),
        (String(localized: "千问 (qwen-vl-plus)"), "qwen-vl-plus"),
        (String(localized: "豆包 (ep-xxx)"), "ep-xxx"),
        (String(localized: "谷歌 (gemini-1.5-pro)"), "gemini-1.5-pro"),
        (String(localized: "小米 (MiLM-Vision)"), "MiLM-Vision")
    ]

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("API Key")
                    Spacer()
                    if showKey {
                        TextField("sk-...", text: $apiKey)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                    } else {
                        SecureField("sk-...", text: $apiKey)
                            .multilineTextAlignment(.trailing)
                    }
                    Button { showKey.toggle() } label: {
                        Image(systemName: showKey ? "eye.slash" : "eye").foregroundStyle(.secondary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Base URL")
                    TextField("https://api.openai.com/v1", text: $baseURL)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .autocapitalization(.none)
                }
                .padding(.vertical, 4)
            } header: {
                Text("API 配置")
            } footer: {
                Text("API Key 已安全地加密存储在您的设备钥匙串（Keychain）中。")
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("常用模型")
                        Spacer()
                        Picker("", selection: Binding(
                            get: {
                                if presetModels.contains(where: { $0.1 == model }) {
                                    return model
                                } else {
                                    return ""
                                }
                            },
                            set: { newValue in
                                if !newValue.isEmpty {
                                    model = newValue
                                }
                            }
                        )) {
                            ForEach(presetModels, id: \.1) { name, id in
                                Text(name).tag(id)
                            }
                            Text("自定义...").tag("")
                        }
                        .pickerStyle(.menu)
                    }
                    
                    Text("当前模型名称")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    TextField("输入自定义模型名称...", text: $model)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .autocapitalization(.none)
                }
                .padding(.vertical, 8)
            } header: {
                Text("模型设置")
            } footer: {
                Text("你可以从下拉菜单选择常用模型，或手动输入任何兼容 OpenAI 接口的多模态模型名称。")
            }

            Section {
                HStack {
                    Text("服务状态")
                    Spacer()
                    if apiKey.isEmpty {
                        Label("未配置 API Key", systemImage: "xmark.circle.fill").foregroundStyle(.red)
                    } else {
                        Label("已就绪", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                }
            }

            Section {
                Button {
                    Task { await testAPIConnection() }
                } label: {
                    HStack {
                        Spacer()
                        if isTesting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .padding(.trailing, 8)
                        }
                        Text(isTesting ? "测试中..." : "测试 API 连接")
                            .fontWeight(.medium)
                        Spacer()
                    }
                }
                .disabled(apiKey.isEmpty || isTesting)

                if let result = testResult {
                    HStack {
                        Spacer()
                        Text(result)
                            .font(.subheadline)
                            .foregroundStyle(result.hasPrefix("✅") ? .green : .red)
                        Spacer()
                    }
                }
            } header: {
                Text("连接测试")
            } footer: {
                Text("使用当前配置的 API Key、Base URL 和模型发送测试请求。请仅使用您信任的 API 服务地址，以保护您的密钥和照片隐私。")
            }
            
            // 数据备份与恢复
            Section {
                Button("导出备份到文件 / iCloud") {
                    // 🛡️ 本地 AES 加密 API Key，然后再写入 BackupData 结构体
                    let encryptedKey = CryptoHelper.encrypt(apiKey)
                    
                    let backupData = BackupData(
                        rooms: appState.rooms,
                        groups: appState.groups,
                        apiKey: encryptedKey,
                        baseURL: baseURL,
                        model: model
                    )
                    exportDoc = BackupDocument(data: backupData)
                    isExporting = true
                }
                
                Button("从文件 / iCloud 导入备份") {
                    isImporting = true
                }
            } header: {
                Text("数据备份与恢复")
            } footer: {
                Text(backupMessage ?? String(localized: "通过系统文件管理器，您可以将数据安全备份到 iCloud 等云盘中。出于隐私保护，API Key 在备份文件中将经过强加密处理。"))
                    .foregroundColor(backupMessage != nil ? .blue : .secondary)
            }
            .fileExporter(isPresented: $isExporting, document: exportDoc, contentType: .json, defaultFilename: "StoreSenseBackup") { result in
                switch result {
                case .success:
                    backupMessage = String(localized: "导出成功！")
                case .failure(let error):
                    let errorMsg = error.localizedDescription
                    backupMessage = String(localized: "导出失败：\(errorMsg)")
                }
            }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    do {
                        guard url.startAccessingSecurityScopedResource() else { return }
                        defer { url.stopAccessingSecurityScopedResource() }
                        let data = try Data(contentsOf: url)
                        let backup = try JSONDecoder().decode(BackupData.self, from: data)
                        
                        // 恢复本地存储的物品和空间
                        let storage = ObjectStorageService()
                        backup.groups.forEach { storage.saveGroup($0) }
                        backup.rooms.forEach { storage.saveRoom($0) }
                        appState.loadGroups()
                        appState.loadRooms()
                        
                        // 恢复大模型配置（若存在）
                        if let importedEncryptedKey = backup.apiKey {
                            // 🔓 本地 AES 解密
                            let decryptedKey = CryptoHelper.decrypt(importedEncryptedKey) ?? importedEncryptedKey
                            apiKey = decryptedKey
                            KeychainManager.shared.saveKey(decryptedKey) // 同步回 Keychain
                        }
                        if let importedBaseURL = backup.baseURL { baseURL = importedBaseURL }
                        if let importedModel = backup.model { model = importedModel }
                        
                        let count = backup.rooms.count
                        backupMessage = String(localized: "导入成功，已恢复 \(count) 个收纳位与模型配置！")
                        
                        // 自动重建一次索引
                        rebuildSearchIndex()
                        
                    } catch {
                        backupMessage = String(localized: "导入失败：格式不正确或读取失败")
                    }
                case .failure(let error):
                    let errorMsg = error.localizedDescription
                    backupMessage = String(localized: "导入失败：\(errorMsg)")
                }
            }
            
            Section {
                Button {
                    rebuildSearchIndex()
                } label: {
                    HStack {
                        Spacer()
                        if isRebuildingIndex {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .padding(.trailing, 8)
                        }
                        Text(isRebuildingIndex ? "正在重建..." : "重建搜索索引")
                            .fontWeight(.medium)
                        Spacer()
                    }
                }
                .disabled(isRebuildingIndex)
                
                Button(role: .destructive) {
                    clearSearchIndex()
                } label: {
                    HStack {
                        Spacer()
                        Text("清空搜索索引")
                        Spacer()
                    }
                }
                .disabled(isRebuildingIndex)
            } header: {
                Text("搜索索引")
            } footer: {
                Text("重建索引可解决Siri和Spotlight搜索不到物品的问题。清空索引会移除所有Siri搜索建议。")
            }
            
            // 新增版权声明
            VStack {
                Text("郑云凯 769440615@qq.com 版权所有，侵权必究©️")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .listRowBackground(Color.clear)
        }
        .navigationTitle("设置")
        // 初始化时从 Keychain 读入
        .onAppear {
            self.apiKey = KeychainManager.shared.loadKey()
        }
        // 当用户在文本框修改了 apiKey 时，自动加密存入 Keychain
        .onChange(of: apiKey) { newValue in
            KeychainManager.shared.saveKey(newValue)
        }
        .alert("索引操作", isPresented: $showIndexAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(indexAlertMessage)
        }
    }
    
    private func rebuildSearchIndex() {
        isRebuildingIndex = true
        // 绕过 AppState，直接通过单例执行并接收回调更新 UI
        SearchIndexService.shared.indexAllItems { success in
            DispatchQueue.main.async {
                self.isRebuildingIndex = false
                self.indexAlertMessage = success ? "重建搜索索引成功！\n现在可以通过 Siri 和 Spotlight 搜索你的物品了。" : "重建搜索索引失败，请稍后重试。"
                self.showIndexAlert = true
            }
        }
    }
    
    private func clearSearchIndex() {
        SearchIndexService.shared.clearAllIndexes { success in
            DispatchQueue.main.async {
                self.indexAlertMessage = success ? "已成功清空所有搜索索引。" : "清空搜索索引失败。"
                self.showIndexAlert = true
            }
        }
    }

    private func testAPIConnection() async {
        isTesting = true
        testResult = nil

        do {
            var base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            while base.hasSuffix("/") {
                base.removeLast()
            }

            let urlString = base.appending("/chat/completions")
            guard let url = URL(string: urlString) else {
                testResult = String(localized: "❌ 无效的 URL")
                isTesting = false
                return
            }

            let testBody: [String: Any] = [
                "model": model,
                "messages": [
                    ["role": "user", "content": "测试连接，请回复'连接成功'"]
                ],
                "max_tokens": 50
            ]

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(apiKey.trimmingCharacters(in: .whitespaces))", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 30
            request.httpBody = try? JSONSerialization.data(withJSONObject: testBody)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                testResult = String(localized: "❌ 无效的响应")
                isTesting = false
                return
            }

            if httpResponse.statusCode == 200 {
                testResult = String(localized: "✅ API 连接成功！")
            } else {
                let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                let detail = (errorJson?["error"] as? [String: Any])?["message"] as? String
                            ?? (errorJson?["message"] as? String)
                            ?? "HTTP \(httpResponse.statusCode)"
                testResult = String(localized: "❌ 连接失败: \(detail)")
            }
        } catch {
            let errorMsg = error.localizedDescription
            testResult = String(localized: "❌ 连接失败: \(errorMsg)")
        }

        isTesting = false
    }
}

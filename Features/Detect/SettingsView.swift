import SwiftUI
import UniformTypeIdentifiers

// MARK: - 备份数据

struct BackupData: Codable {
    let rooms: [StorageLocation]
    let groups: [StorageGroup]
    let apiKey: String?
    let baseURL: String?
    let model: String?
    let providers: [LLMProvider]?
    let encryptedKeys: [String: String]?

    private enum CodingKeys: String, CodingKey {
        case rooms, groups, apiKey, baseURL, model, providers, encryptedKeys
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rooms = try c.decode([StorageLocation].self, forKey: .rooms)
        groups = try c.decode([StorageGroup].self, forKey: .groups)
        apiKey = try c.decodeIfPresent(String.self, forKey: .apiKey)
        baseURL = try c.decodeIfPresent(String.self, forKey: .baseURL)
        model = try c.decodeIfPresent(String.self, forKey: .model)
        providers = try c.decodeIfPresent([LLMProvider].self, forKey: .providers)
        encryptedKeys = try c.decodeIfPresent([String: String].self, forKey: .encryptedKeys)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(rooms, forKey: .rooms)
        try c.encode(groups, forKey: .groups)
        try c.encodeIfPresent(apiKey, forKey: .apiKey)
        try c.encodeIfPresent(baseURL, forKey: .baseURL)
        try c.encodeIfPresent(model, forKey: .model)
        try c.encodeIfPresent(providers, forKey: .providers)
        try c.encodeIfPresent(encryptedKeys, forKey: .encryptedKeys)
    }

    nonisolated init(rooms: [StorageLocation], groups: [StorageGroup], apiKey: String? = nil, baseURL: String? = nil, model: String? = nil, providers: [LLMProvider]? = nil, encryptedKeys: [String: String]? = nil) {
        self.rooms = rooms
        self.groups = groups
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.model = model
        self.providers = providers
        self.encryptedKeys = encryptedKeys
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: BackupData

    init(data: BackupData) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let fileData = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.data = try JSONDecoder().decode(BackupData.self, from: fileData)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return FileWrapper(regularFileWithContents: try encoder.encode(data))
    }
}

// MARK: - 设置主页

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var llmManager: LLMManager

    @State private var showAddProvider = false
    @State private var editingProvider: LLMProvider?
    @State private var expandedProviderID: UUID?

    // 备份
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var exportDoc: BackupDocument?
    @State private var backupMessage: String?

    // 索引
    @State private var isRebuildingIndex = false
    @State private var showIndexAlert = false
    @State private var indexAlertMessage = ""

    var body: some View {
        Form {
            // 当前激活模型
            Section {
                if let active = llmManager.activeProvider {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .font(.largeTitle)
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(active.name)
                                .font(.headline)
                            HStack(spacing: 6) {
                                Text("模型")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(active.currentModel)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(.blue)
                                    .clipShape(Capsule())
                            }
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                    .padding(.vertical, 4)
                } else {
                    Text("未配置模型").foregroundStyle(.secondary)
                }
            } header: {
                Text("当前激活模型")
            }

            // 所有模型列表
            Section {
                ForEach(llmManager.providers) { provider in
                    VStack(spacing: 0) {
                        // Provider 主行 — 用 contentShape + onTapGesture 代替 Button，避免吞子按钮事件
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(provider.name)
                                    .font(.subheadline).bold()
                                    .foregroundStyle(.primary)
                                HStack(spacing: 6) {
                                    Text("ID")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(provider.currentModel)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.purple)
                                        .clipShape(Capsule())
                                    if provider.models.count > 1 {
                                        Image(systemName: expandedProviderID == provider.id ? "chevron.up" : "chevron.down")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            Spacer()
                            if provider.isActive {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            }
                            // 编辑按钮
                            Button {
                                editingProvider = provider
                            } label: {
                                Image(systemName: "pencil.circle")
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                            // 删除按钮
                            Button {
                                llmManager.deleteProvider(provider)
                            } label: {
                                Image(systemName: "trash.circle")
                                    .foregroundStyle(.red.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // 先激活该 provider
                            llmManager.setActive(provider)
                            // 如果有多个模型，同时展开/收起子模型列表
                            if provider.models.count > 1 {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    expandedProviderID = expandedProviderID == provider.id ? nil : provider.id
                                }
                            }
                        }

                        // 子模型切换
                        if expandedProviderID == provider.id && provider.models.count > 1 {
                            VStack(spacing: 0) {
                                Divider().padding(.leading, 40)
                                HStack(spacing: 0) {
                                    Text("点击切换：")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(provider.models, id: \.self) { model in
                                                let index = provider.models.firstIndex(of: model) ?? 0
                                                Button {
                                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                                        llmManager.selectModel(in: provider.id, modelIndex: index)
                                                    }
                                                } label: {
                                                    Text(model)
                                                        .font(.system(.caption, design: .monospaced))
                                                        .padding(.horizontal, 10)
                                                        .padding(.vertical, 5)
                                                        .background(model == provider.currentModel ? Color.blue : Color(.tertiarySystemBackground))
                                                        .foregroundStyle(model == provider.currentModel ? .white : .primary)
                                                        .clipShape(Capsule())
                                                }
                                            }
                                        }
                                        .padding(.vertical, 8)
                                    }
                                }
                                .padding(.horizontal, 12)
                            }
                        }
                    }
                }
                .onMove { source, dest in
                    llmManager.providers.move(fromOffsets: source, toOffset: dest)
                }

                Button {
                    showAddProvider = true
                } label: {
                    Label("添加模型", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("模型列表")
            } footer: {
                Text("点击整行切换激活模型，铅笔编辑，红色删除。多模型的点击展开后可切换子模型。")
            }

            // 测试连接
            Section {
                if let active = llmManager.activeProvider {
                    NavigationLink("测试当前连接") {
                        TestConnectionView(provider: active, llmManager: llmManager)
                    }
                }
            }

            // 数据备份
            Section {
                Button("导出备份") {
                    // 加密每个 provider 的 API Key
                    var encryptedKeys: [String: String] = [:]
                    for p in llmManager.providers {
                        let key = llmManager.loadKey(for: p.id)
                        if !key.isEmpty, let encrypted = CryptoHelper.encrypt(key) {
                            encryptedKeys[p.id.uuidString] = encrypted
                        }
                    }

                    let backupData = BackupData(
                        rooms: appState.rooms,
                        groups: appState.groups,
                        providers: llmManager.providers,
                        encryptedKeys: encryptedKeys
                    )
                    exportDoc = BackupDocument(data: backupData)
                    isExporting = true
                }
                Button("导入备份") { isImporting = true }
            } header: {
                Text("数据备份与恢复")
            } footer: {
                Text(backupMessage ?? "导出/导入收纳数据和模型配置。API Key 在备份中经加密处理。")
                    .foregroundColor(backupMessage != nil ? .blue : .secondary)
            }
            .fileExporter(isPresented: $isExporting, document: exportDoc, contentType: .json, defaultFilename: "StoreSenseBackup") { result in
                switch result {
                case .success: backupMessage = "导出成功！"
                case .failure(let e): backupMessage = "导出失败：\(e.localizedDescription)"
                }
            }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
                if case .success(let url) = result {
                    guard url.startAccessingSecurityScopedResource() else { return }
                    defer { url.stopAccessingSecurityScopedResource() }
                    do {
                        let backup = try JSONDecoder().decode(BackupData.self, from: Data(contentsOf: url))
                        let storage = ObjectStorageService()
                        backup.groups.forEach { storage.saveGroup($0) }
                        backup.rooms.forEach { storage.saveRoom($0) }
                        appState.loadGroups()
                        appState.loadRooms()

                        // 恢复多 provider 模型配置
                        if let providers = backup.providers, !providers.isEmpty {
                            // 先清空现有 providers
                            for existing in llmManager.providers {
                                llmManager.deleteProvider(existing)
                            }
                            // 逐个恢复
                            for p in providers {
                                var restored = p
                                restored.isActive = false
                                llmManager.addProvider(restored)
                                if let encryptedKey = backup.encryptedKeys?[p.id.uuidString] {
                                    let decryptedKey = CryptoHelper.decrypt(encryptedKey) ?? encryptedKey
                                    llmManager.saveKey(decryptedKey, for: p.id)
                                }
                            }
                            // 恢复激活状态
                            if let activeBackup = providers.first(where: { $0.isActive }) {
                                llmManager.setActive(activeBackup)
                            } else if let first = llmManager.providers.first {
                                llmManager.setActive(first)
                            }
                        }

                        // 兼容旧版备份：如果有单 apiKey/baseURL/model
                        if let encryptedKey = backup.apiKey, let baseURL = backup.baseURL, let model = backup.model {
                            let decryptedKey = CryptoHelper.decrypt(encryptedKey) ?? encryptedKey
                            let p = LLMProvider(name: "导入模型", baseURL: baseURL, model: model, isActive: true)
                            llmManager.addProvider(p)
                            if let added = llmManager.providers.last {
                                llmManager.saveKey(decryptedKey, for: added.id)
                            }
                        }

                        backupMessage = "导入成功！"
                        rebuildSearchIndex()
                    } catch {
                        backupMessage = "导入失败：\(error.localizedDescription)"
                    }
                }
            }

            // 搜索索引
            Section {
                Button { rebuildSearchIndex() } label: {
                    HStack { Spacer(); Text("重建搜索索引").fontWeight(.medium); Spacer() }
                }
                .disabled(isRebuildingIndex)
                Button(role: .destructive) {
                    SearchIndexService.shared.clearAllIndexes { success in
                        DispatchQueue.main.async { indexAlertMessage = success ? "已清空" : "失败"; showIndexAlert = true }
                    }
                } label: {
                    HStack { Spacer(); Text("清空搜索索引"); Spacer() }
                }
            } header: { Text("搜索索引") }

            VStack {
                Text("郑云凯 769440615@qq.com 版权所有©️")
                    .font(.caption2).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .listRowBackground(Color.clear)
        }
        .navigationTitle("设置")
        .sheet(isPresented: $showAddProvider) {
            ProviderEditSheet(llmManager: llmManager)
        }
        .sheet(item: $editingProvider) { provider in
            ProviderEditSheet(llmManager: llmManager, editing: provider)
        }
        .alert("索引操作", isPresented: $showIndexAlert) {
            Button("确定", role: .cancel) {}
        } message: { Text(indexAlertMessage) }
    }

    private func rebuildSearchIndex() {
        isRebuildingIndex = true
        SearchIndexService.shared.indexAllItems { success in
            DispatchQueue.main.async {
                isRebuildingIndex = false
                indexAlertMessage = success ? "重建成功！" : "重建失败"
                showIndexAlert = true
            }
        }
    }
}

// MARK: - 连接测试

struct TestConnectionView: View {
    let provider: LLMProvider
    let llmManager: LLMManager
    @State private var isTesting = false
    @State private var result: String?
    @State private var visionResult: String?

    var body: some View {
        VStack(spacing: 20) {
            if isTesting {
                ProgressView("测试中...").padding(.top, 40)
            }
            if let result {
                Label(result, systemImage: result.contains("✅") ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(result.contains("✅") ? .green : .red)
                    .padding()
            }
            if let visionResult {
                Label(visionResult, systemImage: visionResult.contains("✅") ? "eye.fill" : "eye.slash")
                    .font(.subheadline)
                    .foregroundStyle(visionResult.contains("✅") ? .green : .orange)
                    .padding(.horizontal)
            }
            Button("开始测试") { Task { await test() } }
                .disabled(isTesting)
        }
        .navigationTitle("连接测试")
    }

    private func test() async {
        isTesting = true
        result = nil
        visionResult = nil
        let apiKey = llmManager.loadKey(for: provider.id)
        guard !apiKey.isEmpty else {
            result = "❌ 未配置 API Key"
            isTesting = false
            return
        }
        do {
            var base = provider.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            while base.hasSuffix("/") { base.removeLast() }
            guard let url = URL(string: base + "/chat/completions") else {
                result = "❌ 无效 URL"; isTesting = false; return
            }

            // 1. 纯文字测试
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.timeoutInterval = 30
            req.httpBody = try? JSONSerialization.data(withJSONObject: [
                "model": provider.currentModel,
                "messages": [["role": "user", "content": "请回复OK"]],
                "max_tokens": 10
            ])
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else {
                result = "❌ 无效响应"; isTesting = false; return
            }
            guard http.statusCode == 200 else {
                let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? [String: Any]
                result = "❌ \(msg?["message"] as? String ?? "HTTP \(http.statusCode)")"
                isTesting = false
                return
            }
            result = "✅ 文字连接成功"

            // 2. 视觉能力测试 — 发一张 2x2 纯色小图
            let tinyImageBase64 = createTinyTestImageBase64()
            var visionReq = URLRequest(url: url)
            visionReq.httpMethod = "POST"
            visionReq.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            visionReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
            visionReq.timeoutInterval = 30
            visionReq.httpBody = try? JSONSerialization.data(withJSONObject: [
                "model": provider.currentModel,
                "messages": [[
                    "role": "user",
                    "content": [
                        ["type": "text", "text": "这张图片是什么颜色？只回答颜色名称。"],
                        ["type": "image_url", "image_url": ["url": "data:image/png;base64,\(tinyImageBase64)"]]
                    ]
                ]],
                "max_tokens": 20
            ])
            let (vData, vResp) = try await URLSession.shared.data(for: visionReq)
            if let vHttp = vResp as? HTTPURLResponse, vHttp.statusCode == 200 {
                let content = (try? JSONSerialization.jsonObject(with: vData) as? [String: Any])?["choices"] as? [[String: Any]]
                let msg = content?.first?["message"] as? [String: Any]
                let text = (msg?["content"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                visionResult = "✅ 支持视觉识别（回复：\(text)）"
            } else {
                let errMsg = (try? JSONSerialization.jsonObject(with: vData) as? [String: Any])?["error"] as? [String: Any]
                let detail = errMsg?["message"] as? String ?? "图片请求被拒绝"
                visionResult = "⚠️ 不支持视觉识别 - \(detail)"
            }
        } catch {
            result = "❌ \(error.localizedDescription)"
        }
        isTesting = false
    }

    /// 生成一张 2x2 纯红色 PNG 的 base64（约 100 字节）
    private func createTinyTestImageBase64() -> String {
        let size = CGSize(width: 2, height: 2)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        return (image.pngData() ?? Data()).base64EncodedString()
    }
}

// MARK: - 模型编辑 Sheet

struct ProviderEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var llmManager: LLMManager

    var editing: LLMProvider?

    @State private var displayName = ""
    @State private var baseURL = "https://api.openai.com/v1"
    @State private var models: [String] = [""]
    @State private var apiKey = ""
    @State private var showKey = false
    @State private var newModelText = ""

    private var isEditing: Bool { editing != nil }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundStyle(.blue)
                            .font(.largeTitle)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("给自己看的备注")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("例如：免费额度 / 书房专用", text: $displayName)
                                .font(.body)
                        }
                    }
                } header: {
                    Text("备注名称")
                } footer: {
                    Text("随便起，只有你自己看得到，不影响任何功能。")
                }

                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "server.rack")
                            .foregroundStyle(.green)
                            .font(.largeTitle)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("API 地址")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("https://api.openai.com/v1", text: $baseURL)
                                .font(.system(.body, design: .monospaced))
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                        }
                    }
                } header: {
                    Text("服务地址")
                }

                Section {
                    ForEach(Array(models.enumerated()), id: \.offset) { index, model in
                        HStack {
                            if models.count > 1 {
                                Image(systemName: index == editing?.selectedModelIndex ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(index == editing?.selectedModelIndex ? .blue : .secondary)
                            }
                            TextField("gpt-4o / deepseek-chat", text: binding(for: index))
                                .font(.system(.body, design: .monospaced))
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                            if models.count > 1 {
                                Button {
                                    models.remove(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }
                    .onDelete { indexSet in
                        models.remove(atOffsets: indexSet)
                    }

                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue)
                        TextField("输入新模型 ID，按回车添加", text: $newModelText)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .onSubmit {
                                let trimmed = newModelText.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !trimmed.isEmpty && !models.contains(trimmed) {
                                    models.append(trimmed)
                                    newModelText = ""
                                }
                            }
                    }
                } header: {
                    Text("模型列表")
                } footer: {
                    Text("同一 API Key 下可以有多个模型，按回车添加。点击圆圈可设为默认使用的模型。")
                }

                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.orange)
                            .font(.largeTitle)
                        if showKey {
                            TextField("sk-...", text: $apiKey)
                                .font(.system(.body, design: .monospaced))
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                        } else {
                            SecureField("sk-...", text: $apiKey)
                        }
                        Button { showKey.toggle() } label: {
                            Image(systemName: showKey ? "eye.slash" : "eye").foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("密钥")
                } footer: {
                    Text("存储在本机钥匙串，不会上传。")
                }
            }
            .navigationTitle(isEditing ? "编辑模型" : "添加新模型")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(displayName.isEmpty || models.allSatisfy { $0.isEmpty })
                }
            }
            .onAppear {
                if let p = editing {
                    displayName = p.name
                    baseURL = p.baseURL
                    models = p.models.isEmpty ? [""] : p.models
                    apiKey = llmManager.loadKey(for: p.id)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func binding(for index: Int) -> Binding<String> {
        Binding(
            get: { models[index] },
            set: { models[index] = $0 }
        )
    }

    private func save() {
        let filteredModels = models.filter { !$0.isEmpty }
        guard !filteredModels.isEmpty else { return }

        if let p = editing {
            var updated = p
            updated.name = displayName
            updated.baseURL = baseURL
            updated.models = filteredModels
            updated.selectedModelIndex = min(p.selectedModelIndex, filteredModels.count - 1)
            llmManager.updateProvider(updated)
            llmManager.saveKey(apiKey, for: p.id)
        } else {
            let p = LLMProvider(name: displayName, baseURL: baseURL, models: filteredModels)
            llmManager.addProvider(p)
            if let added = llmManager.providers.last {
                llmManager.saveKey(apiKey, for: added.id)
            }
        }
        dismiss()
    }
}

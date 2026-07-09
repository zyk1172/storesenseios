import SwiftUI

/// A wrapper to make search results Identifiable for SwiftUI sheets and lists.
struct SearchResult: Identifiable {
    var id: UUID { item.id }
    let location: StorageLocation
    let item: StorageItem
    var matchScore: Double? = nil  // 智能搜索的匹配分数
}

enum SearchMode: String, CaseIterable {
    case normal = "普通搜索"
    case smart = "智能搜索"
}

struct SearchView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var llmManager: LLMManager
    @State private var searchText = ""
    @State private var results: [SearchResult] = []
    @State private var selected: SearchResult?
    @State private var searchMode: SearchMode = .normal
    @State private var isSearching = false
    @State private var isSearchFinished = false
    @State private var searchError: String?

    private let storage = ObjectStorageService()
    private let historyService = SearchHistoryService()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索栏
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("搜索物体...", text: $searchText)
                        .textFieldStyle(.plain)
                        .onSubmit { performSearch() }
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            results = []
                        } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top)
                
                // 搜索模式选择
                Picker("搜索模式", selection: $searchMode) {
                    ForEach(SearchMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                if searchText.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "magnifyingglass").font(.system(size: 60)).foregroundStyle(.secondary)
                        Text("搜索你的物品").font(.headline)
                        Text("输入物品名称、描述或分类").font(.subheadline).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if isSearching {
                    VStack {
                        Spacer()
                        AILoadingView(title: "智能搜索中...", isFinished: $isSearchFinished)
                            .padding(.horizontal, 40)
                        Spacer()
                        Spacer() // 下方多一点空白，使它更贴近视觉中心
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = searchError {
                    VStack(spacing: 20) {
                        Image(systemName: "questionmark.circle").font(.system(size: 60)).foregroundStyle(.secondary)
                        Text(error).font(.headline)
                        if searchMode == .smart {
                            Text("试试普通搜索或其他关键词").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if results.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "magnifyingglass").font(.system(size: 60)).foregroundStyle(.secondary)
                        Text("未找到 \"\(searchText)\"").font(.headline)
                        Text("尝试其他关键词").font(.subheadline).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(results) { r in
                            HStack {
                                if let coverData = r.location.coverImageData, let uiImage = UIImage(data: coverData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 50, height: 50)
                                        .cornerRadius(8)
                                        .clipped()
                                } else {
                                    Rectangle().fill(Color(.systemGray4))
                                        .frame(width: 50, height: 50).cornerRadius(8)
                                        .overlay { Image(systemName: "cube").foregroundStyle(.secondary) }
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(r.item.name).font(.headline)
                                        if let score = r.matchScore {
                                            Text("\(Int(score * 100))%")
                                                .font(.caption2)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(score > 0.7 ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                                                .foregroundColor(score > 0.7 ? .green : .orange)
                                                .cornerRadius(4)
                                        }
                                    }
                                    Text("\(r.location.name) · \(r.item.category)").font(.caption).foregroundStyle(.secondary)
                                    if !r.item.attributes.isEmpty {
                                        Text(r.item.attributes).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                    Text(r.item.description).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                recordSearch(query: searchText, item: r.item, location: r.location)
                                selected = r
                            }
                        }
                    }
                }
            }
            .navigationTitle("搜索")
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .sheet(item: $selected) { result in 
                ItemDetailView(
                    item: result.item,
                    location: result.location,
                    onItemChanged: { _ in refreshResults() },
                    onItemDeleted: { refreshResults() }
                )
            }
        }
        .navigationViewStyle(.stack)
    }

    private func performSearch() {
        guard !searchText.isEmpty else { results = []; searchError = nil; return }
        searchError = nil
        
        switch searchMode {
        case .normal:
            normalSearch()
        case .smart:
            smartSearch()
        }
    }
    
    private func normalSearch() {
        results = storage.searchObjects(query: searchText).map { 
            SearchResult(location: $0.location, item: $0.item) 
        }
    }
    
    private func smartSearch() {
        let config = llmManager.currentConfig
        guard !config.apiKey.isEmpty else {
            normalSearch()
            return
        }
        
        isSearching = true
        isSearchFinished = false
        searchError = nil
        
        Task {
            do {
                let allItems = getAllItemsWithDescriptions()
                guard !allItems.isEmpty else {
                    await MainActor.run {
                        results = []
                        isSearching = false
                        searchError = "还没有添加任何物品"
                    }
                    return
                }
                
                let matchedItems = try await searchWithAI(query: searchText, items: allItems)
                
                await MainActor.run {
                    isSearchFinished = true
                }
                
                // 等待半秒让进度条100%动画播放完
                try? await Task.sleep(nanoseconds: 500_000_000)
                
                await MainActor.run {
                    results = matchedItems
                    isSearching = false
                    if matchedItems.isEmpty {
                        searchError = "或许没有这样的物品"
                    }
                }
            } catch {
                await MainActor.run {
                    results = []
                    isSearching = false
                    searchError = "智能搜索失败：\(error.localizedDescription)"
                }
            }
        }
    }
    
    private func getAllItemsWithDescriptions() -> [(location: StorageLocation, item: StorageItem)] {
        var allItems: [(location: StorageLocation, item: StorageItem)] = []
        for room in appState.rooms {
            for item in room.items {
                allItems.append((location: room, item: item))
            }
        }
        return allItems
    }
    
    private func searchWithAI(query: String, items: [(location: StorageLocation, item: StorageItem)]) async throws -> [SearchResult] {
        // 构建物品列表供AI分析
        var itemsDescription = ""
        for (index, entry) in items.enumerated() {
            itemsDescription += """
            \(index + 1). 名称：\(entry.item.name)
               分类：\(entry.item.category)
               属性：\(entry.item.attributes.isEmpty ? "无" : entry.item.attributes)
               描述：\(entry.item.description.isEmpty ? "无" : entry.item.description)
               位置：\(entry.location.name)
            
            """
        }
        
        let prompt = """
        你是一个智能物品搜索助手。用户正在寻找："\(query)"
        
        以下是用户的所有物品：
        \(itemsDescription)
        
        请理解用户的真实需求，找出最匹配的物品。用户可能：
        - 使用物品的俗称或别名（如"喝水的容器"可能是"保温杯"、"水杯"、"马克杯"）
        - 描述物品的用途而非名称（如"听歌的"可能是"耳机"、"音箱"）
        - 搜索功能相似的替代品（如"充电的"可能是"充电器"、"充电宝"）
        
        匹配规则：
        1. 功能匹配：物品的用途/功能与搜索意图匹配
        2. 名称匹配：物品名称与搜索词相同或相似
        3. 描述匹配：物品描述中包含相关关键词
        4. 类别匹配：物品所属类别与搜索意图相关
        
        对于"喝水的容器"这类搜索，请匹配：保温杯、水杯、杯子、马克杯、玻璃杯、茶杯等
        对于"听音乐"这类搜索，请匹配：耳机、音箱、蓝牙音箱、音响等
        对于"照明"这类搜索，请匹配：台灯、手电筒、灯具、夜灯等
        
        请返回JSON格式，包含匹配的物品序号 and 匹配度（0-1之间）：
        {
            "matches": [
                {"index": 1, "score": 0.95, "reason": "这是白色保温杯，符合喝水容器的搜索"},
                {"index": 3, "score": 0.8, "reason": "玻璃杯也可以用来喝水"}
            ]
        }
        
        重要：只返回匹配度 >= 0.8（80%）的结果！低于80%的不要返回。
        最多返回10个结果，按匹配度从高到低排序。
        """
        
        let config = llmManager.currentConfig
        let url = URL(string: "\(config.baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 180
        
        let body: [String: Any] = [
            "model": config.model,
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": 8000
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        // 解析响应
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "AI响应解析失败"])
        }
        
        // 提取JSON
        var jsonString = content
        if let range = jsonString.range(of: "```json") {
            jsonString = String(jsonString[range.upperBound...])
        }
        if let range = jsonString.range(of: "```") {
            jsonString = String(jsonString[..<range.lowerBound])
        }
        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonData = jsonString.data(using: .utf8),
              let result = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let matches = result["matches"] as? [[String: Any]] else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "匹配结果解析失败"])
        }
        
        var searchResults: [SearchResult] = []
        for match in matches {
            if let index = match["index"] as? Int,
               let score = match["score"] as? Double,
               score >= 0.8,  // 只保留匹配度 >= 80% 的结果
               index >= 1 && index <= items.count {
                let entry = items[index - 1]
                searchResults.append(SearchResult(
                    location: entry.location,
                    item: entry.item,
                    matchScore: score
                ))
            }
        }
        
        // 按匹配度从高到低排序
        searchResults.sort { ($0.matchScore ?? 0) > ($1.matchScore ?? 0) }
        
        return searchResults
    }

    private func recordSearch(query: String, item: StorageItem, location: StorageLocation) {
        let record = SearchHistoryItem(
            query: query.isEmpty ? item.name : query,
            itemName: item.name,
            locationName: location.name
        )
        historyService.addRecord(record)
    }

    private func refreshResults() {
        appState.loadRooms()
        if !searchText.isEmpty {
            performSearch()
        }
    }
}

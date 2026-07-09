import SwiftUI

struct MapView: View {
    @EnvironmentObject var appState: AppState
    private let historyService = SearchHistoryService()
    @State private var refreshID = UUID()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 统计卡片
                    statisticsCards
                    
                    // 最近查找
                    recentSearchSection
                    
                    // 最常查找
                    mostSearchedSection
                    
                    // 清空统计按钮
                    clearStatisticsButton
                }
                .padding()
            }
            .navigationTitle("统计")
            .id(refreshID)
        }
        .navigationViewStyle(.stack)
        .onAppear {
            refreshID = UUID()
        }
        .onChange(of: appState.rooms.count) { _ in
            refreshID = UUID()
        }
    }
    
    // MARK: - 统计卡片
    
    private var statisticsCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            GradientStatCard(
                title: "收纳位数量",
                value: "\(appState.rooms.count)",
                icon: "archivebox.fill",
                colors: [.blue, .cyan]
            )
            GradientStatCard(
                title: "物品总数",
                value: "\(totalItemsCount)",
                icon: "cube.box.fill",
                colors: [.green, .mint]
            )
            GradientStatCard(
                title: "最近查找",
                value: lastSearchText,
                icon: "clock.fill",
                colors: [.purple, .indigo]
            )
            GradientStatCard(
                title: "最常查找",
                value: mostSearchedText,
                icon: "flame.fill",
                colors: [.orange, .red]
            )
        }
    }
    
    // MARK: - 最近查找
    
    private var recentSearchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("最近查找", systemImage: "clock.arrow.circlepath")
                .font(.headline)
            
            let recent = historyService.recentSearches(limit: 8)
            if recent.isEmpty {
                HStack {
                    Image(systemName: "clock.badge.questionmark")
                        .foregroundStyle(.secondary)
                    Text("还没有查找记录")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
            } else {
                ForEach(recent) { item in
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.purple)
                            .frame(width: 28, height: 28)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(6)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.itemName)
                                .font(.subheadline)
                                .bold()
                            Text("\(item.locationName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(item.timestamp, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    // MARK: - 最常查找
    
    private var mostSearchedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("最常查找", systemImage: "flame.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            
            let topItems = historyService.mostSearched(limit: 8)
            if topItems.isEmpty {
                HStack {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .foregroundStyle(.secondary)
                    Text("还没有查找记录")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
            } else {
                ForEach(Array(topItems.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 12) {
                        // 排名徽章
                        Text("\(index + 1)")
                            .font(.caption)
                            .bold()
                            .foregroundStyle(index < 3 ? .white : .secondary)
                            .frame(width: 24, height: 24)
                            .background(index < 3 ? Color.orange : Color(.tertiarySystemBackground))
                            .cornerRadius(12)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.itemName)
                                .font(.subheadline)
                                .bold()
                            Text(item.locationName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("\(item.count) 次")
                            .font(.caption)
                            .bold()
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    // MARK: - 清空统计按钮
    
    private var clearStatisticsButton: some View {
        Button(role: .destructive) {
            clearStatistics()
        } label: {
            HStack {
                Spacer()
                Image(systemName: "trash")
                Text("清空搜索统计")
                Spacer()
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
        }
    }
    
    private func clearStatistics() {
        historyService.clearAllHistory()
        refreshID = UUID()  // 刷新页面
    }
    
    // MARK: - 计算属性
    
    private var totalItemsCount: Int {
        appState.rooms.reduce(0) { $0 + $1.items.count }
    }
    
    private var totalRoomsCount: Int {
        appState.rooms.count
    }
    
    private var lastSearchText: String {
        let recent = historyService.recentSearches(limit: 1)
        guard let last = recent.first else {
            return "无"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: last.timestamp, relativeTo: Date())
    }
    
    private var mostSearchedText: String {
        let top = historyService.mostSearched(limit: 1)
        guard let first = top.first else {
            return "无"
        }
        return first.itemName
    }
}

// MARK: - 统计卡片组件

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(color)
                Spacer()
            }
            Spacer(minLength: 0)
            Text(value)
                .font(.title2)
                .bold()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: color.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

// MARK: - ItemDetailView

struct ItemDetailView: View {
    @State var item: StorageItem
    let location: StorageLocation?
    let locationName: String?
    @Environment(\.dismiss) private var dismiss

    /// 父视图传入的回调：物品被修改（改名等）
    var onItemChanged: ((StorageItem) -> Void)?
    /// 父视图传入的回调：物品被删除
    var onItemDeleted: (() -> Void)?

    @State private var showDeleteConfirm = false
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var isRefining = false
    @State private var isRefineFinished = false
    @State private var refineError: String?
    @State private var refreshID = UUID()
    @EnvironmentObject var llmManager: LLMManager
    private let storageService = ObjectStorageService()

    // 兼容旧调用方式
    init(item: StorageItem, locationName: String? = nil, onItemChanged: ((StorageItem) -> Void)? = nil, onItemDeleted: (() -> Void)? = nil) {
        self._item = State(initialValue: item)
        self.location = nil
        self.locationName = locationName
        self.onItemChanged = onItemChanged
        self.onItemDeleted = onItemDeleted
    }

    init(item: StorageItem, location: StorageLocation, onItemChanged: ((StorageItem) -> Void)? = nil, onItemDeleted: (() -> Void)? = nil) {
        self._item = State(initialValue: item)
        self.location = location
        self.locationName = location.name
        self.onItemChanged = onItemChanged
        self.onItemDeleted = onItemDeleted
    }

    private var displayName: String {
        locationName ?? "未知位置"
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // 原图 + 定位标记
                    originalImageSection

                    // 内容区域
                    VStack(spacing: 16) {
                        locationCard
                        infoCard
                        if !item.description.isEmpty {
                            descriptionCard
                        }
                        if !item.attributes.isEmpty {
                            attributesCard
                        }
                        timeCard
                        actionButtons
                    }
                    .padding()
                }
            }
            .navigationTitle(item.name)
            .id(refreshID)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
            .confirmationDialog("确定删除「\(item.name)」？此操作不可撤销。", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("删除", role: .destructive) { deleteItem() }
                Button("取消", role: .cancel) {}
            }
        }
        .navigationViewStyle(.stack)
        .overlay {
            if isRefining {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    AILoadingView(title: "正在重新识别...", isFinished: $isRefineFinished)
                        .padding(.horizontal, 40)
                }
            }
        }
    }

    // MARK: - 原图 + 定位标记

    @ViewBuilder
    private var originalImageSection: some View {
        if let loc = location, let bgData = loc.backgroundImageData, let uiImage = UIImage(data: bgData) {
            let aspectRatio = uiImage.size.width / uiImage.size.height

            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(aspectRatio, contentMode: .fit)
                .overlay(alignment: .topLeading) {
                    // 坐标标记层
                    GeometryReader { geo in
                        let imgW = geo.size.width
                        let imgH = geo.size.height

                        ZStack(alignment: .topLeading) {
                            // 坐标定位标记 — 圆心 = 物品中心点
                            if let cx = item.coordX, let cy = item.coordY {
                                let posX = CGFloat(cx / 1000.0) * imgW
                                let posY = CGFloat(cy / 1000.0) * imgH

                                // 脉冲光环
                                Circle()
                                    .fill(Color.red.opacity(0.15))
                                    .frame(width: 50, height: 50)
                                    .position(x: posX, y: posY)

                                // 白色外圈
                                Circle()
                                    .stroke(Color.white, lineWidth: 2.5)
                                    .frame(width: 36, height: 36)
                                    .position(x: posX, y: posY)

                                // 红色内圈 + 物品图标
                                ZStack {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 28, height: 28)
                                    Image(systemName: "cube.fill")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                                .position(x: posX, y: posY)

                                // 物品名标签 — 居中悬浮于标记上方
                                Text(item.name)
                                    .font(.caption2)
                                    .bold()
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.red)
                                    .foregroundStyle(.white)
                                    .cornerRadius(4)
                                    .position(x: posX, y: posY - 24)
                            }

                            // 底部渐变遮罩
                            VStack {
                                Spacer()
                                LinearGradient(
                                    colors: [.clear, .black.opacity(0.3)],
                                    startPoint: .center,
                                    endPoint: .bottom
                                )
                                .frame(height: 40)
                            }
                        }
                    }
                }
        } else {
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(height: 200)
                .overlay {
                    Image(systemName: "photo")
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary)
                }
        }
    }

    // MARK: - 位置信息卡片

    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("位置信息", systemImage: "location.fill")
                .font(.headline)
                .foregroundStyle(.blue)

            HStack {
                Image(systemName: "archivebox.fill")
                    .foregroundStyle(.blue)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text("所属收纳位")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(displayName)
                        .font(.body)
                        .bold()
                }
            }

            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.orange)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text("相对位置")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.relativeLocation)
                        .font(.body)
                        .bold()
                        .foregroundStyle(.blue)
                }
            }

            if let cx = item.coordX, let cy = item.coordY {
                HStack {
                    Image(systemName: "scope")
                        .foregroundStyle(.red)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("图上坐标")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("(\(Int(cx)), \(Int(cy)))")
                            .font(.body)
                            .bold()
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - 基本信息卡片

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("基本信息", systemImage: "info.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)

            HStack {
                Text("分类").foregroundStyle(.secondary)
                Spacer()
                Text(item.category)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(6)
            }
            .font(.subheadline)

            HStack {
                Text("AI 置信度").foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.0f%%", item.confidence * 100))
                    .bold()
                    .foregroundStyle(item.confidence > 0.8 ? .green : .orange)
            }
            .font(.subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var attributesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("属性", systemImage: "tag.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            Text(item.attributes)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - 详细描述卡片

    private var descriptionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("详细描述", systemImage: "text.alignleft")
                .font(.headline)
                .foregroundStyle(.purple)

            Text(item.description)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - 记录时间卡片

    private var timeCard: some View {
        HStack {
            Image(systemName: "clock.fill")
                .foregroundStyle(.secondary)
            Text(item.createdAt.formatted(date: .long, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    // MARK: - 操作按钮

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // AI精细化识别按钮
            Button {
                showCamera = true
            } label: {
                if isRefining {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                } else {
                    Image(systemName: "sparkles")
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
            }
            .buttonStyle(.bordered)
            .tint(.purple)
            .disabled(isRefining)

            Button {
                showDeleteConfirm = true
            } label: {
                Image(systemName: "trash")
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .fullScreenCover(isPresented: $showCamera) {
            ImagePicker(image: $capturedImage, sourceType: .camera)
                .ignoresSafeArea()
        }
        .onChange(of: capturedImage) { newImage in
            if let image = newImage {
                refineWithAI(image: image)
            }
        }
        .alert("识别错误", isPresented: .constant(refineError != nil)) {
            Button("OK") { refineError = nil }
        } message: {
            Text(refineError ?? "")
        }
    }

    // MARK: - 数据操作

    private func saveChanges() {
        onItemChanged?(item)
        // 从存储中获取最新的location数据并更新
        if let locId = location?.id {
            var allRooms = storageService.fetchAllRooms()
            if let roomIdx = allRooms.firstIndex(where: { $0.id == locId }),
               let itemIdx = allRooms[roomIdx].items.firstIndex(where: { $0.id == item.id }) {
                allRooms[roomIdx].items[itemIdx] = item
                allRooms[roomIdx].updatedAt = Date()
                storageService.saveRoom(allRooms[roomIdx])
            }
        }
    }

    private func deleteItem() {
        onItemDeleted?()
        if let locId = location?.id {
            var allRooms = storageService.fetchAllRooms()
            if let roomIdx = allRooms.firstIndex(where: { $0.id == locId }) {
                allRooms[roomIdx].items.removeAll { $0.id == item.id }
                allRooms[roomIdx].updatedAt = Date()
                storageService.saveRoom(allRooms[roomIdx])
            }
        }
        dismiss()
    }
    
    // MARK: - AI精细化识别
    
    private func refineWithAI(image: UIImage) {
        let config = llmManager.currentConfig
        guard !config.apiKey.isEmpty else {
            refineError = "请先在设置中配置API Key"
            capturedImage = nil
            return
        }
        
        isRefining = true
        isRefineFinished = false
        let capturedItemId = item.id
        let capturedLocationId = location?.id
        let capturedCoordX = item.coordX
        let capturedCoordY = item.coordY
        
        print("   capturedLocationId: \(capturedLocationId?.uuidString ?? "nil")")
        
        Task {
            do {
                // 缩放图片
                let resized = resizeImage(image, maxDimension: 1024)
                guard let imageData = resized.jpegData(compressionQuality: 0.8) else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "图片处理失败"])
                }
                
                let service = AIRecognitionService(apiKey: config.apiKey, baseURL: config.baseURL, model: config.model)
                let result = try await service.recognizeObject(imageData: imageData)
                
                print("   AI识别结果: \(result.items.count) 个物品")
                
                // 只更新物品的基本信息，保留原有的坐标和图片
                guard let firstItem = result.items.first else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "AI未识别到物品"])
                }
                
                print("   识别到: \(firstItem.name)")
                
                await MainActor.run {
                    isRefineFinished = true
                }
                
                // 等待半秒让进度条100%动画播放完
                try? await Task.sleep(nanoseconds: 500_000_000)
                
                await MainActor.run {
                    // 在主线程更新item
                    item.name = firstItem.name
                    item.category = firstItem.category
                    item.description = firstItem.description
                    item.attributes = firstItem.attributes
                    item.relativeLocation = firstItem.relativeLocation
                    item.confidence = firstItem.confidence
                    // 保持原有坐标
                    item.coordX = capturedCoordX
                    item.coordY = capturedCoordY
                    
                    print("   item已更新: \(item.name)")
                    
                    // 直接保存到存储
                    let storage = ObjectStorageService()
                    if let locId = capturedLocationId {
                        var allRooms = storage.fetchAllRooms()
                        print("   总房间数: \(allRooms.count)")
                        if let roomIdx = allRooms.firstIndex(where: { $0.id == locId }) {
                            print("   找到房间: \(allRooms[roomIdx].name)")
                            if let itemIdx = allRooms[roomIdx].items.firstIndex(where: { $0.id == capturedItemId }) {
                                print("   找到物品，索引: \(itemIdx)")
                                print("   旧物品名: \(allRooms[roomIdx].items[itemIdx].name)")
                                allRooms[roomIdx].items[itemIdx] = item
                                allRooms[roomIdx].updatedAt = Date()
                                storage.saveRoom(allRooms[roomIdx])
                                print("   ✅ 已保存")
                            } else {
                                print("   ❌ 未找到物品")
                            }
                        } else {
                            print("   ❌ 未找到房间")
                        }
                    } else {
                        print("   ❌ capturedLocationId 为 nil")
                    }
                    
                    // 通知父视图
                    onItemChanged?(item)
                    
                    refreshID = UUID()
                    isRefining = false
                    capturedImage = nil
                }
            } catch {
                print("   ❌ 错误: \(error)")
                await MainActor.run {
                    refineError = "识别失败：\(error.localizedDescription)"
                    isRefining = false
                    capturedImage = nil
                }
            }
        }
    }
    
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let ratio = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        if ratio >= 1.0 { return image }
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

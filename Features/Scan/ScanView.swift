import SwiftUI

// 新增：排序枚举
enum SortType: String, CaseIterable {
    case name = "名称"
    case date = "创建时间"
}

private enum ItemSwipeSide {
    case leading
    case trailing
}

struct ScanView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedTab: ContentView.Tab
    @State private var showCreateRoom = false
    @State private var newRoomName = ""
    @State private var selectedGroupName = ""
    @State private var newGroupName = ""
    @State private var isCreatingNewGroup = false
    @State private var selectedLocation: StorageLocation?
    @State private var locationToDelete: StorageLocation?
    @State private var showDeleteConfirm = false
    
    // 记录被折叠的空间名称
    @State private var collapsedGroups: Set<String> = []
    
    // MARK: - 编辑与排序状态
    @State private var isSelectionMode = false
    @State private var isSortingMode = false
    @State private var selectedLocations: Set<UUID> = []
    @State private var selectedGroups: Set<String> = []
    @State private var showMultiDeleteConfirm = false
    
    @AppStorage("customGroupOrder") private var customGroupOrder: String = ""
    @AppStorage("customLocationOrder") private var customLocationOrder: String = ""
    
    private var groupOrder: [String] {
        customGroupOrder.isEmpty ? [] : customGroupOrder.components(separatedBy: ",")
    }
    
    private var locationOrder: [String] {
        customLocationOrder.isEmpty ? [] : customLocationOrder.components(separatedBy: ",")
    }

    // 克莱因蓝颜色
    private let kleinBlue = Color(red: 0.0, green: 0.18, blue: 0.65)

    var body: some View {
        NavigationView {
            VStack {
                if appState.rooms.isEmpty && appState.groups.isEmpty {
                    emptyStateView
                } else if isSortingMode {
                    sortingListView
                } else {
                    locationListView
                }
            }
            .navigationTitle(isSelectionMode ? "选择项目" : (isSortingMode ? "拖动排序" : "我的收纳位"))
            .navigationBarTitleDisplayMode(isSelectionMode || isSortingMode ? .inline : .large)
            .toolbar {
                // 左侧按钮：多选模式下的「删除」按钮
                ToolbarItem(placement: .navigationBarLeading) {
                    if isSelectionMode {
                        Button {
                            showMultiDeleteConfirm = true
                        } label: {
                            Text("删除")
                                .foregroundColor(selectedLocations.isEmpty && selectedGroups.isEmpty ? .secondary : .red)
                        }
                        .disabled(selectedLocations.isEmpty && selectedGroups.isEmpty)
                    }
                }
                
                // 右侧按钮组合
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSelectionMode || isSortingMode {
                        Button {
                            withAnimation {
                                isSelectionMode = false
                                isSortingMode = false
                                selectedLocations.removeAll()
                                selectedGroups.removeAll()
                            }
                        } label: {
                            Text("完成").bold()
                        }
                    } else {
                        HStack(spacing: 16) {
                            // 编辑菜单
                            if !appState.groups.isEmpty || !appState.rooms.isEmpty {
                                Menu {
                                    Button {
                                        withAnimation { isSortingMode = true }
                                    } label: {
                                        Label("排序", systemImage: "arrow.up.arrow.down")
                                    }
                                    
                                    Button {
                                        withAnimation { isSelectionMode = true }
                                    } label: {
                                        Label("选择", systemImage: "checkmark.circle")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                }
                            }
                            
                            // 新建按钮（合并为统一的新建收纳位流程）
                            Button {
                                if appState.groups.isEmpty {
                                    isCreatingNewGroup = true
                                    selectedGroupName = "CREATE_NEW_GROUP"
                                } else {
                                    isCreatingNewGroup = false
                                    selectedGroupName = appState.groups.first?.name ?? ""
                                }
                                showCreateRoom = true 
                            } label: {
                                Image(systemName: "plus.circle")
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showCreateRoom) {
                createRoomView
            }
            .sheet(item: $selectedLocation) { location in
                LocationDetailView(location: location, selectedTab: $selectedTab)
                    .id(location.updatedAt)
            }
            .confirmationDialog(
                locationToDelete.map { "确定删除「\($0.name)」及其所有物品？" } ?? "确定删除？",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("删除", role: .destructive) {
                    if let loc = locationToDelete {
                        appState.deleteRoom(loc)
                    }
                }
                Button("取消", role: .cancel) {}
            }
            .confirmationDialog(
                "确定删除选中的空间和收纳位？",
                isPresented: $showMultiDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("删除", role: .destructive) {
                    withAnimation {
                        performMultiDelete()
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("删除空间将同时删除其内部的所有收纳位及其物品。此操作不可撤销。")
            }
        }
        .navigationViewStyle(.stack)
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "archivebox")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)
            Text("还没有收纳空间")
                .font(.headline)
            Text("请先建立一个收纳位")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("新建收纳位") { 
                isCreatingNewGroup = true
                selectedGroupName = "CREATE_NEW_GROUP"
                showCreateRoom = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var locationListView: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // 遍历经过排序的空间
                ForEach(sortedGroups, id: \.self) { groupName in
                    Section {
                        // 🟢 将列数从 2 修改为 3
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            // 折叠状态下为空数组，触发移除动画
                            let locations = collapsedGroups.contains(groupName) ? [] : sortedLocations(for: groupName)
                            ForEach(locations) { location in
                                ZStack(alignment: .topTrailing) {
                                    LocationCard(location: location, kleinBlue: kleinBlue)
                                        .opacity(isSelectionMode && !selectedLocations.contains(location.id) ? 0.7 : 1.0)
                                        .onTapGesture {
                                            if isSelectionMode {
                                                toggleLocationSelection(location, groupName: groupName)
                                            } else {
                                                selectedLocation = location
                                            }
                                        }
                                        .contextMenu {
                                            if !isSelectionMode {
                                                Button(role: .destructive) {
                                                    locationToDelete = location
                                                    showDeleteConfirm = true
                                                } label: {
                                                    Label("删除", systemImage: "trash")
                                                }
                                            }
                                        }
                                    
                                    // 选择框 Overlay
                                    if isSelectionMode {
                                        Image(systemName: selectedLocations.contains(location.id) ? "checkmark.circle.fill" : "circle")
                                            .font(.title3)
                                            .foregroundColor(selectedLocations.contains(location.id) ? .blue : .secondary.opacity(0.5))
                                            .background(Circle().fill(Color(.systemBackground)).padding(1))
                                            .padding(4)
                                    }
                                }
                            }
                        }
                    } header: {
                        groupHeader(groupName: groupName)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - 原生拖拽排序视图
    private var sortingListView: some View {
        List {
            Section {
                ForEach(sortedGroups, id: \.self) { group in
                    Text(group)
                }
                .onMove(perform: moveGroup)
            } header: {
                Text("空间大类排序")
            } footer: {
                Text("按住右侧把手上下拖动")
            }
            
            ForEach(sortedGroups, id: \.self) { group in
                let locs = sortedLocations(for: group)
                if !locs.isEmpty {
                    Section {
                        ForEach(locs) { loc in
                            HStack {
                                Image(systemName: "archivebox")
                                    .foregroundStyle(.blue)
                                Text(loc.name)
                            }
                        }
                        .onMove { source, dest in
                            moveLocation(in: group, from: source, to: dest)
                        }
                    } header: {
                        Text("\(group) - 内部排序")
                    }
                }
            }
        }
        .environment(\.editMode, .constant(.active))
    }

    // MARK: - 排序与数据源支持
    
    private var groupedRooms: [String: [StorageLocation]] {
        Dictionary(grouping: appState.rooms, by: { $0.groupName })
    }
    
    private var sortedGroups: [String] {
        var allGroupNames = Set(groupedRooms.keys)
        appState.groups.forEach { allGroupNames.insert($0.name) }
        
        let order = groupOrder
        return Array(allGroupNames).sorted { a, b in
            let indexA = order.firstIndex(of: a) ?? Int.max
            let indexB = order.firstIndex(of: b) ?? Int.max
            if indexA == indexB {
                let dateA = appState.groups.first(where: { $0.name == a })?.createdAt ?? Date.distantPast
                let dateB = appState.groups.first(where: { $0.name == b })?.createdAt ?? Date.distantPast
                return dateA < dateB
            }
            return indexA < indexB
        }
    }
    
    private func sortedLocations(for groupName: String) -> [StorageLocation] {
        let locs = groupedRooms[groupName] ?? []
        let order = locationOrder
        return locs.sorted { a, b in
            let indexA = order.firstIndex(of: a.id.uuidString) ?? Int.max
            let indexB = order.firstIndex(of: b.id.uuidString) ?? Int.max
            if indexA == indexB {
                return a.createdAt < b.createdAt
            }
            return indexA < indexB
        }
    }
    
    private func moveGroup(from source: IndexSet, to destination: Int) {
        var currentOrder = sortedGroups
        currentOrder.move(fromOffsets: source, toOffset: destination)
        customGroupOrder = currentOrder.joined(separator: ",")
    }
    
    private func moveLocation(in groupName: String, from source: IndexSet, to destination: Int) {
        var currentLocs = sortedLocations(for: groupName)
        currentLocs.move(fromOffsets: source, toOffset: destination)
        
        var order = locationOrder
        let locIds = currentLocs.map { $0.id.uuidString }
        // 移除旧的位置，重新放到最后（局部顺序完美保留，而且不会影响全局其他组）
        order.removeAll(where: { locIds.contains($0) })
        order.append(contentsOf: locIds)
        customLocationOrder = order.joined(separator: ",")
    }

    // MARK: - 选择模式逻辑
    
    private func toggleGroupSelection(_ groupName: String) {
        if selectedGroups.contains(groupName) {
            // 取消全选
            selectedGroups.remove(groupName)
            let locs = groupedRooms[groupName] ?? []
            for loc in locs {
                selectedLocations.remove(loc.id)
            }
        } else {
            // 全选该组所有物品
            selectedGroups.insert(groupName)
            let locs = groupedRooms[groupName] ?? []
            for loc in locs {
                selectedLocations.insert(loc.id)
            }
        }
    }
    
    private func toggleLocationSelection(_ location: StorageLocation, groupName: String) {
        if selectedLocations.contains(location.id) {
            selectedLocations.remove(location.id)
            // 一旦取消选中任意一个子项，组的全选状态也取消
            selectedGroups.remove(groupName)
        } else {
            selectedLocations.insert(location.id)
            // 检查该组下是否已全部选中
            let allIds = (groupedRooms[groupName] ?? []).map { $0.id }
            if !allIds.isEmpty && Set(allIds).isSubset(of: selectedLocations) {
                selectedGroups.insert(groupName)
            }
        }
    }
    
    private func performMultiDelete() {
        // 先删除选中的收纳位
        let roomsToDelete = appState.rooms.filter { selectedLocations.contains($0.id) }
        for room in roomsToDelete {
            appState.deleteRoom(room)
        }
        
        // 再删除选中的空间（顺带清理孤立的空间）
        let groupsToDelete = appState.groups.filter { selectedGroups.contains($0.name) }
        for group in groupsToDelete {
            appState.deleteGroup(group)
        }
        
        isSelectionMode = false
        selectedLocations.removeAll()
        selectedGroups.removeAll()
    }

    // MARK: - UI 组件

    private func groupHeader(groupName: String) -> some View {
        HStack {
            if isSelectionMode {
                Button {
                    withAnimation { toggleGroupSelection(groupName) }
                } label: {
                    Image(systemName: selectedGroups.contains(groupName) ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(selectedGroups.contains(groupName) ? .blue : .secondary.opacity(0.5))
                        .font(.title2)
                }
                .padding(.trailing, 4)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
            
            Image(systemName: "folder")
                .foregroundStyle(.blue)
            Text(groupName)
                .font(.headline)
                .foregroundStyle(.primary)
            Text("\(groupedRooms[groupName]?.count ?? 0)个收纳位")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            
            // 添加折叠/展开指示图标
            if !isSelectionMode {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(collapsedGroups.contains(groupName) ? 0 : 90))
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(Color(.systemBackground))
        .onTapGesture {
            // 如果在编辑模式，点击 Header 整行等于点击前面勾选框
            if isSelectionMode {
                withAnimation { toggleGroupSelection(groupName) }
            } else {
                // 正常模式点击折叠
                withAnimation(.easeInOut(duration: 0.25)) {
                    if collapsedGroups.contains(groupName) {
                        collapsedGroups.remove(groupName)
                    } else {
                        collapsedGroups.insert(groupName)
                    }
                }
            }
        }
    }

    private var createRoomView: some View {
        NavigationView {
            Form {
                Section("收纳位名称") {
                    TextField("例如：左侧第一层抽屉", text: $newRoomName)
                }
                Section("空间") {
                    if appState.groups.isEmpty {
                        TextField("新建空间名称 (例如：书房、主卧)", text: $newGroupName)
                    } else {
                        Picker("选择空间", selection: $selectedGroupName) {
                            ForEach(appState.groups) { group in
                                Text(group.name).tag(group.name)
                            }
                            Text("＋ 新建空间").tag("CREATE_NEW_GROUP")
                        }
                        .onChange(of: selectedGroupName) { newValue in
                            withAnimation {
                                isCreatingNewGroup = (newValue == "CREATE_NEW_GROUP")
                            }
                        }
                        
                        if isCreatingNewGroup {
                            TextField("新建空间名称", text: $newGroupName)
                        }
                    }
                }
            }
            .navigationTitle("新建收纳位")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showCreateRoom = false
                        newRoomName = ""
                        newGroupName = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        let finalGroupName: String
                        if isCreatingNewGroup || appState.groups.isEmpty {
                            if !newGroupName.isEmpty {
                                _ = appState.createGroup(name: newGroupName)
                                finalGroupName = newGroupName
                            } else {
                                finalGroupName = "默认"
                            }
                        } else {
                            finalGroupName = selectedGroupName
                        }
                        
                        if !newRoomName.isEmpty {
                            let newRoom = appState.createRoom(name: newRoomName, groupName: finalGroupName)
                            newRoomName = ""
                            newGroupName = ""
                            showCreateRoom = false
                            
                            // 新建完后直接跳转到识别页面
                            appState.currentRoom = newRoom
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                selectedTab = .detect
                            }
                        }
                    }
                    .disabled(newRoomName.isEmpty || ((isCreatingNewGroup || appState.groups.isEmpty) ? newGroupName.isEmpty : selectedGroupName.isEmpty))
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            if appState.groups.isEmpty {
                isCreatingNewGroup = true
                selectedGroupName = "CREATE_NEW_GROUP"
            } else if selectedGroupName == "" || selectedGroupName == "CREATE_NEW_GROUP" {
                if isCreatingNewGroup {
                    selectedGroupName = "CREATE_NEW_GROUP"
                } else {
                    selectedGroupName = appState.groups.first?.name ?? ""
                }
            }
        }
    }
}

// 🟢 适配三列网格的卡片视图
struct LocationCard: View {
    let location: StorageLocation
    let kleinBlue: Color

    /// 根据整洁等级返回浅色背景色
    private var backgroundColor: Color {
        guard let score = location.cleanlinessScore else {
            return Color(.tertiarySystemBackground)
        }
        if score >= 75 {
            return Color.green.opacity(0.08)
        } else if score >= 55 {
            return Color.orange.opacity(0.08)
        } else {
            return Color.red.opacity(0.08)
        }
    }

    private var accentColor: Color {
        guard let score = location.cleanlinessScore else {
            return .secondary
        }
        if score >= 75 { return .green }
        if score >= 55 { return .orange }
        return .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 封面：固定高度，宽度受网格列约束
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    if let coverData = location.coverImageData, let uiImage = UIImage(data: coverData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: 90)
                            .clipped()
                    } else if location.inputType == .textInput {
                        Rectangle()
                            .fill(
                                LinearGradient(colors: [kleinBlue, kleinBlue.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .frame(width: geo.size.width, height: 90)
                            .overlay {
                                Image(systemName: "text.quote")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                    } else {
                        Rectangle()
                            .fill(.regularMaterial)
                            .frame(width: geo.size.width, height: 90)
                            .overlay {
                                Image(systemName: "archivebox")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
            }
            .frame(height: 90)

            // 信息区：浅色背景 + 整洁等级色彩
            VStack(alignment: .leading, spacing: 3) {
                Text(location.name)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 3) {
                    Image(systemName: "cube.box.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(accentColor)
                    Text("\(location.items.count)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(accentColor)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundColor)
        }
        .frame(maxWidth: .infinity)
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}

struct LocationDetailView: View {
    let initialLocation: StorageLocation
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: StorageItem?
    @State private var editingItem: StorageItem?
    @State private var editingItemImage: UIImage?
    @State private var swipedItemID: UUID?
    @State private var swipedItemSide: ItemSwipeSide?
    @State private var swipeTimer: Timer?
    @Binding var selectedTab: ContentView.Tab
    @State private var currentLocation: StorageLocation
    @State private var showDeleteConfirm = false
    @State private var showClearItemsConfirm = false
    @State private var showManualAdd = false

    init(location: StorageLocation, selectedTab: Binding<ContentView.Tab>) {
        self.initialLocation = location
        self._selectedTab = selectedTab
        self._currentLocation = State(initialValue: location)
    }
    
    private let kleinBlue = Color(red: 0.0, green: 0.18, blue: 0.65)

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    coverSection
                    goToDetectButton
                    
                    if let anchor = currentLocation.anchorItemName {
                        anchorSection(anchor: anchor)
                    }
                    
                    if let comment = currentLocation.funnyComment, !comment.isEmpty {
                        funnyCommentSection(comment: comment)
                    }

                    if let level = currentLocation.cleanlinessLevel, let score = currentLocation.cleanlinessScore {
                        cleanlinessScoreSection(level: level, score: score, problems: currentLocation.mainProblems)
                    }
                    
                    if let advice = currentLocation.organizingAdvice, !advice.isEmpty {
                        organizingAdviceSection(advice: advice)
                    }
                    
                    itemsSection
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .padding(.bottom, 48)
            }
            .navigationTitle(currentLocation.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .confirmationDialog("确定删除「\(currentLocation.name)」及其所有物品？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    appState.deleteRoom(currentLocation)
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            }
            .confirmationDialog("清除「\(currentLocation.name)」里的所有物品和识别记录？", isPresented: $showClearItemsConfirm, titleVisibility: .visible) {
                Button("清除物品", role: .destructive) {
                    clearLocationItems()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("只会清空当前收纳位的物品、图片、参照物、评分、建议和问题记录，不会删除收纳位或收纳组。")
            }
            .sheet(item: $selectedItem) { item in
                ItemDetailView(
                    item: item,
                    location: currentLocation,
                    onItemChanged: { _ in refreshLocation() },
                    onItemDeleted: { refreshLocation() }
                )
            }
            .sheet(item: $editingItem) { item in
                ItemEditSheet(item: item, backgroundImage: editingItemImage) { updated in
                    saveEditedItem(updated)
                }
            }
            .sheet(isPresented: $showManualAdd) {
                ManualAddItemView(location: currentLocation) {
                    refreshLocation()
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private var coverSection: some View {
        Group {
            if let coverData = currentLocation.coverImageData, let uiImage = UIImage(data: coverData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else if currentLocation.inputType == .textInput {
                Rectangle()
                    .fill(
                        LinearGradient(colors: [kleinBlue, kleinBlue.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        VStack {
                            Image(systemName: "text.quote")
                                .font(.system(size: 40))
                                .foregroundStyle(.white.opacity(0.8))
                            Text("文字输入")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
            } else {
                Rectangle()
                    .fill(.regularMaterial)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        VStack {
                            Image(systemName: "camera")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("点击下方按钮添加物品")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
            }
        }
    }

    private var goToDetectButton: some View {
        Button {
            appState.currentRoom = currentLocation
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                selectedTab = .detect
            }
        } label: {
            HStack {
                Image(systemName: "camera.viewfinder")
                Text("前往识别")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundStyle(.white)
            .cornerRadius(12)
        }
    }

    private func anchorSection(anchor: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("📍 参照物")
                .font(.headline)
            
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.blue)
                Text(anchor)
                    .font(.body)
                Spacer()
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)
        }
    }

    private func funnyCommentSection(comment: String) -> some View {
        let commentColor: Color = {
            if comment.contains("【绿】") { return .green }
            if comment.contains("【黄】") { return .orange }
            if comment.contains("【红】") { return .red }
            
            if comment.contains("整齐") || comment.contains("模范") || comment.contains("赏心悦目") || comment.contains("完美") {
                return .green
            } else if comment.contains("加油") || comment.contains("潜力") || comment.contains("差一点") || comment.contains("继续") {
                return .orange
            } else {
                return .red
            }
        }()
        
        let displayComment = comment
            .replacingOccurrences(of: "【绿】", with: "")
            .replacingOccurrences(of: "【黄】", with: "")
            .replacingOccurrences(of: "【红】", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        return Text(displayComment)
            .font(.body)
            .fontWeight(.medium)
            .foregroundStyle(commentColor)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(commentColor.opacity(0.1))
            .cornerRadius(10)
    }

    private func cleanlinessScoreSection(level: String, score: Int, problems: [String]?) -> some View {
        let scoreColor: Color = {
            if score >= 75 { return .green }
            if score >= 55 { return .orange }
            return .red
        }()

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(scoreColor)
                Text("整洁评分").font(.headline)
                Spacer()
                Text(level)
                    .font(.subheadline).bold()
                    .foregroundStyle(scoreColor)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5).fill(Color(.systemGray5))
                    RoundedRectangle(cornerRadius: 5).fill(scoreColor)
                        .frame(width: geo.size.width * CGFloat(score) / 100.0)
                }
            }
            .frame(height: 8)
            Text("\(score) / 100 分")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)

            if let problems, !problems.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("主要问题").font(.caption).bold().foregroundStyle(.secondary)
                    ForEach(problems, id: \.self) { p in
                        HStack(alignment: .top, spacing: 4) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.caption2).foregroundStyle(.orange)
                            Text(p).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func organizingAdviceSection(advice: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("💡 收纳建议")
                .font(.headline)
            
            Text(advice)
                .font(.body)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(10)
        }
    }

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("物品清单")
                    .font(.headline)
                Spacer()
                if !currentLocation.items.isEmpty || currentLocation.backgroundImageData != nil || currentLocation.coverImageData != nil {
                    Button {
                        showClearItemsConfirm = true
                    } label: {
                        Label("清除物品", systemImage: "trash.slash")
                            .font(.subheadline)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .foregroundStyle(.red)
                }
                Button {
                    showManualAdd = true
                } label: {
                    Label("手动添加", systemImage: "plus")
                        .font(.subheadline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            if currentLocation.items.isEmpty {
                Text("还没有物品，去识别标签添加吧！")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
            } else {
                ForEach(currentLocation.items) { item in
                    SwipeableItemRow(
                        item: item,
                        side: swipedItemID == item.id ? swipedItemSide : nil,
                        onOpen: { side in openSwipe(for: item, side: side) },
                        onClose: closeSwipe,
                        onDelete: { deleteItem(item) },
                        onEdit: { editItem(item) },
                        onToggleVerified: { toggleVerified(item) },
                        onTap: { selectedItem = item }
                    )
                        .id(item.id)
                }
            }
        }
    }

    private func refreshLocation() {
        appState.loadRooms()
        if let updated = appState.rooms.first(where: { $0.id == initialLocation.id }) {
            currentLocation = updated
        }
    }

    private func openSwipe(for item: StorageItem, side: ItemSwipeSide) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            swipedItemID = item.id
            swipedItemSide = side
        }
        swipeTimer?.invalidate()
        swipeTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            closeSwipe()
        }
    }

    private func closeSwipe() {
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                swipedItemID = nil
                swipedItemSide = nil
            }
        }
    }

    private func clearLocationItems() {
        var location = currentLocation
        location.clearRecognizedContent()
        ObjectStorageService().saveRoom(location)
        appState.currentRoom = location
        appState.loadRooms()
        currentLocation = location
        closeSwipe()
    }

    private func deleteItem(_ item: StorageItem) {
        var location = currentLocation
        location.items.removeAll { $0.id == item.id }
        location.updatedAt = Date()
        ObjectStorageService().saveRoom(location)
        appState.currentRoom = location
        appState.loadRooms()
        refreshLocation()
    }

    private func editItem(_ item: StorageItem) {
        let bg: UIImage? = {
            if let data = currentLocation.backgroundImageData ?? currentLocation.coverImageData {
                return UIImage(data: data)
            }
            return nil
        }()
        editingItem = item
        editingItemImage = bg
    }

    private func saveEditedItem(_ updated: StorageItem) {
        var location = currentLocation
        if let idx = location.items.firstIndex(where: { $0.id == updated.id }) {
            location.items[idx] = updated
            location.updatedAt = Date()
            ObjectStorageService().saveRoom(location)
            appState.currentRoom = location
            refreshLocation()
        }
    }

    private func toggleVerified(_ item: StorageItem) {
        var location = currentLocation
        if let idx = location.items.firstIndex(where: { $0.id == item.id }) {
            location.items[idx].isVerified.toggle()
            location.updatedAt = Date()
            ObjectStorageService().saveRoom(location)
            appState.currentRoom = location
            refreshLocation()
        }
    }
}

struct ItemRow: View {
    let item: StorageItem

    private var accentColor: Color {
        let palette: [Color] = [.blue, .green, .orange, .purple, .pink, .teal, .indigo]
        let key = item.category.isEmpty ? item.name : item.category
        let index = abs(key.hashValue) % palette.count
        return palette[index]
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(accentColor)
                .frame(width: 5)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(item.name)
                        .font(.subheadline)
                        .fontWeight(.bold)
                    if item.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
                
                Text(item.relativeLocation)
                    .font(.caption)
                    .foregroundStyle(accentColor)

                if !item.attributes.isEmpty {
                    Text(item.attributes)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                if !item.description.isEmpty {
                    Text(item.description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(item.category)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .foregroundStyle(accentColor)
                    .background(accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                
                Text(Double(item.confidence), format: .percent.precision(.fractionLength(0)))
                    .font(.caption2)
                    .foregroundStyle(item.confidence >= 0.8 ? .green : .orange)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(accentColor.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct SwipeableItemRow: View {
    let item: StorageItem
    let side: ItemSwipeSide?
    let onOpen: (ItemSwipeSide) -> Void
    let onClose: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void
    let onToggleVerified: () -> Void
    let onTap: () -> Void

    @State private var dragX: CGFloat = 0

    private let leadingWidth: CGFloat = 168
    private let trailingWidth: CGFloat = 84
    private let horizontalActivationDistance: CGFloat = 22
    private let horizontalBiasRatio: CGFloat = 1.45

    private var restingOffset: CGFloat {
        switch side {
        case .leading: return leadingWidth
        case .trailing: return -trailingWidth
        case .none: return 0
        }
    }

    private var displayOffset: CGFloat {
        min(max(restingOffset + dragX, -trailingWidth), leadingWidth)
    }

    private var leadingProgress: Double {
        Double(min(max(displayOffset / leadingWidth, 0), 1))
    }

    private var trailingProgress: Double {
        Double(min(max(-displayOffset / trailingWidth, 0), 1))
    }

    private func horizontalTranslation(from value: DragGesture.Value) -> CGFloat {
        let width = value.translation.width
        let height = value.translation.height
        guard abs(width) >= horizontalActivationDistance,
              abs(width) > abs(height) * horizontalBiasRatio else {
            return 0
        }
        return width
    }

    var body: some View {
        ZStack {
            ItemRow(item: item)
                .offset(x: displayOffset)
                .contentShape(Rectangle())
                .onTapGesture {
                    if side == nil {
                        onTap()
                    } else {
                        onClose()
                    }
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 18, coordinateSpace: .local)
                        .onChanged { value in
                            let horizontal = horizontalTranslation(from: value)
                            if horizontal != 0 {
                                dragX = horizontal
                            } else if side == nil {
                                dragX = 0
                            }
                        }
                        .onEnded { value in
                            let horizontal = horizontalTranslation(from: value)
                            guard horizontal != 0 else {
                                dragX = 0
                                return
                            }
                            let projected = restingOffset + horizontal
                            if projected > 64 {
                                onOpen(.leading)
                            } else if projected < -44 {
                                onOpen(.trailing)
                            } else {
                                onClose()
                            }
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                dragX = 0
                            }
                        }
                )
                .zIndex(1)
                .onChange(of: side) { newSide in
                    if newSide == nil {
                        dragX = 0
                    }
                }

            HStack(spacing: 8) {
                actionButton(title: "编辑", systemImage: "pencil", color: .blue) {
                    onEdit()
                    onClose()
                }
                actionButton(
                    title: item.isVerified ? "取消" : "验证",
                    systemImage: item.isVerified ? "xmark.circle" : "checkmark.seal.fill",
                    color: item.isVerified ? .gray : .green
                ) {
                    onToggleVerified()
                    onClose()
                }
                Spacer()
            }
            .padding(.leading, 4)
            .opacity(leadingProgress)
            .allowsHitTesting(side == .leading)
            .zIndex(2)

            HStack {
                Spacer()
                actionButton(title: "删除", systemImage: "trash", color: .red) {
                    onDelete()
                    onClose()
                }
                .frame(width: trailingWidth)
            }
            .opacity(trailingProgress)
            .allowsHitTesting(side == .trailing)
            .zIndex(2)
        }
        .clipped()
    }

    private func actionButton(title: String, systemImage: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(width: 74, height: 58)
            .foregroundStyle(.white)
            .background(color, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 物品全字段编辑

private func focusedItem(from result: AIRecognitionResult) -> AIItemResult? {
    result.items.min { lhs, rhs in
        let lhsDistance = hypot(Double((lhs.coordX ?? 500) - 500), Double((lhs.coordY ?? 500) - 500))
        let rhsDistance = hypot(Double((rhs.coordX ?? 500) - 500), Double((rhs.coordY ?? 500) - 500))
        return lhsDistance < rhsDistance
    }
}

struct ItemEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var llmManager: LLMManager
    let item: StorageItem
    let backgroundImage: UIImage?
    var onSave: (StorageItem) -> Void

    @State private var name: String
    @State private var category: String
    @State private var relativeLocation: String
    @State private var description: String
    @State private var attributes: String
    @State private var coordX: Float
    @State private var coordY: Float
    @State private var confidence: Float
    @State private var isRecognizing: Bool = false
    @State private var recognitionError: String?

    init(item: StorageItem, backgroundImage: UIImage? = nil, onSave: @escaping (StorageItem) -> Void) {
        self.item = item
        self.backgroundImage = backgroundImage
        self.onSave = onSave
        _name = State(initialValue: item.name)
        _category = State(initialValue: item.category)
        _relativeLocation = State(initialValue: item.relativeLocation)
        _description = State(initialValue: item.description)
        _attributes = State(initialValue: item.attributes)
        _coordX = State(initialValue: item.coordX ?? 500)
        _coordY = State(initialValue: item.coordY ?? 500)
        _confidence = State(initialValue: item.confidence)
    }

    var body: some View {
        NavigationView {
            Form {
                Section("物品信息") {
                    TextField("名称", text: $name)
                    TextField("分类", text: $category)
                    TextField("属性（如：品牌:小米; 颜色:白色）", text: $attributes)
                    TextField("相对位置", text: $relativeLocation)
                    TextField("描述", text: $description)
                }

                if let bg = backgroundImage {
                    Section("坐标定位与局部识别") {
                        InteractiveImageView(image: bg, coordX: $coordX, coordY: $coordY)
                            .frame(height: 250)
                            .listRowInsets(EdgeInsets())

                        Button {
                            Task { await recognizeRegion() }
                        } label: {
                            HStack {
                                Spacer()
                                if isRecognizing {
                                    ProgressView().padding(.trailing, 8)
                                } else {
                                    Image(systemName: "sparkles")
                                }
                                Text(isRecognizing ? "正在识别当前位置..." : "按当前位置重新识别")
                                Spacer()
                            }
                        }
                        .disabled(isRecognizing || llmManager.currentConfig.apiKey.isEmpty)

                        if let recognitionError {
                            Text(recognitionError)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                } else {
                    Section("坐标（0-1000）") {
                        HStack {
                            Text("X").foregroundStyle(.secondary).frame(width: 20)
                            TextField("0-1000", text: Binding(
                                get: { String(Int(coordX)) },
                                set: { coordX = Float($0) ?? 500 }
                            ))
                            .keyboardType(.numberPad)
                        }
                        HStack {
                            Text("Y").foregroundStyle(.secondary).frame(width: 20)
                            TextField("0-1000", text: Binding(
                                get: { String(Int(coordY)) },
                                set: { coordY = Float($0) ?? 500 }
                            ))
                            .keyboardType(.numberPad)
                        }
                    }
                }

                Section("识别信息") {
                    HStack {
                        Text("置信度")
                        Spacer()
                        Text(Double(confidence), format: .percent.precision(.fractionLength(0)))
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("坐标")
                        Spacer()
                        Text("\(Int(coordX)), \(Int(coordY))")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("创建时间")
                        Spacer()
                        Text(item.createdAt, style: .date)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("编辑物品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func save() {
        var updated = item
        updated.name = name.trimmingCharacters(in: .whitespaces)
        updated.category = category
        updated.relativeLocation = relativeLocation
        updated.description = description
        updated.attributes = attributes
        updated.confidence = confidence
        updated.coordX = coordX
        updated.coordY = coordY
        onSave(updated)
        dismiss()
    }

    private func recognizeRegion() async {
        guard let uiImage = backgroundImage else { return }
        guard let crop = ImageProcessingService.focusedCropWithInfo(from: uiImage, coordX: coordX, coordY: coordY) else {
            recognitionError = "无法截取当前位置图片"
            return
        }

        isRecognizing = true
        recognitionError = nil
        defer { isRecognizing = false }

        do {
            let config = llmManager.currentConfig
            let result = try await AIRecognitionService(
                apiKey: config.apiKey,
                baseURL: config.baseURL,
                model: config.model
            ).recognizeObject(
                imageData: crop.data,
                chipInstruction: AIRecognitionService.focusedRegionInstruction
            )

            guard let item = focusedItem(from: result) else {
                recognitionError = "当前位置没有识别到明确物品"
                return
            }

            name = item.name
            if !item.category.isEmpty { category = item.category }
            if !item.relativeLocation.isEmpty { relativeLocation = item.relativeLocation }
            if !item.description.isEmpty { description = item.description }
            attributes = item.attributes
            confidence = item.confidence
            if let localX = item.coordX, let localY = item.coordY {
                let mapped = ImageProcessingService.mapCoordinate((x: localX, y: localY), crop: crop)
                coordX = mapped.x
                coordY = mapped.y
            }
        } catch {
            recognitionError = error.localizedDescription
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var sourceType: UIImagePickerController.SourceType

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage { parent.image = uiImage }
            picker.dismiss(animated: true)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { picker.dismiss(animated: true) }
    }
}

// MARK: - 新增功能：手动添加物品与坐标映射
struct ManualAddItemView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var llmManager: LLMManager
    var location: StorageLocation
    var onSaved: () -> Void
    
    @State private var coordX: Float = 500
    @State private var coordY: Float = 500
    @State private var name: String = ""
    @State private var category: String = ""
    @State private var relativeLocation: String = ""
    @State private var description: String = ""
    @State private var attributes: String = ""
    
    @State private var isRecognizing: Bool = false
    
    var background: UIImage? {
        if let data = location.backgroundImageData ?? location.coverImageData {
            return UIImage(data: data)
        }
        return nil
    }
    
    var body: some View {
        NavigationView {
            Form {
                if let bg = background {
                    Section(header: Text("定位物品 (拖动图标)")) {
                        InteractiveImageView(image: bg, coordX: $coordX, coordY: $coordY)
                            .frame(height: 300)
                            .listRowInsets(EdgeInsets())
                        
                        Button {
                            Task { await recognizeRegion() }
                        } label: {
                            HStack {
                                Spacer()
                                if isRecognizing {
                                    ProgressView().padding(.trailing, 8)
                                } else {
                                    Image(systemName: "sparkles")
                                }
                                Text(isRecognizing ? "正在识别局部细节..." : "精细化局部识别")
                                Spacer()
                            }
                        }
                        .disabled(isRecognizing || llmManager.currentConfig.apiKey.isEmpty)
                    }
                }
                
                Section(header: Text("物品信息")) {
                    TextField("物品名称 (必填)", text: $name)
                    TextField("分类", text: $category)
                    TextField("属性（如：品牌:小米; 颜色:白色）", text: $attributes)
                    TextField("相对位置描述", text: $relativeLocation)
                    TextField("详细描述", text: $description)
                }
            }
            .navigationTitle("添加物品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveItem() }
                        .disabled(name.isEmpty || isRecognizing)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
    
    private func saveItem() {
        var updatedLocation = location
        let newItem = StorageItem(
            name: name,
            category: category.isEmpty ? "未分类" : category,
            relativeLocation: relativeLocation,
            description: description,
            attributes: attributes,
            confidence: 1.0,
            coordX: background != nil ? coordX : nil,
            coordY: background != nil ? coordY : nil
        )
        updatedLocation.items.append(newItem)
        updatedLocation.updatedAt = Date()
        
        let storageService = ObjectStorageService()
        // 保存后，原有逻辑自动重建该物品在系统全局与 Search Index 里的索引
        storageService.saveRoom(updatedLocation)
        
        onSaved()
        dismiss()
    }
    
    private func recognizeRegion() async {
        guard let uiImage = background else { return }
        guard let crop = ImageProcessingService.focusedCropWithInfo(from: uiImage, coordX: coordX, coordY: coordY) else {
            return
        }

        isRecognizing = true
        defer { isRecognizing = false }

        do {
            let config = llmManager.currentConfig
            let result = try await AIRecognitionService(
                apiKey: config.apiKey,
                baseURL: config.baseURL,
                model: config.model
            ).recognizeObject(
                imageData: crop.data,
                chipInstruction: AIRecognitionService.focusedRegionInstruction
            )
            if let item = focusedItem(from: result) {
                name = item.name
                if !item.category.isEmpty { category = item.category }
                if !item.relativeLocation.isEmpty { relativeLocation = item.relativeLocation }
                if !item.description.isEmpty { description = item.description }
                attributes = item.attributes
                if let localX = item.coordX, let localY = item.coordY {
                    let mapped = ImageProcessingService.mapCoordinate((x: localX, y: localY), crop: crop)
                    coordX = mapped.x
                    coordY = mapped.y
                }
            }
        } catch {
            print("局部识别失败: \(error)")
        }
    }
}

// 支持缩放、拖拽定位的图片视图
struct InteractiveImageView: View {
    let image: UIImage
    @Binding var coordX: Float
    @Binding var coordY: Float

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var imageOffset: CGSize = .zero
    @State private var lastImageOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let imageSize = CGSize(
                width: CGFloat(image.cgImage?.width ?? Int(image.size.width)),
                height: CGFloat(image.cgImage?.height ?? Int(image.size.height))
            )
            let viewSize = geo.size

            let imageRatio = imageSize.width > 0 && imageSize.height > 0 ? imageSize.width / imageSize.height : 1
            let viewRatio = viewSize.width > 0 && viewSize.height > 0 ? viewSize.width / viewSize.height : 1

            let renderWidth: CGFloat
            let renderHeight: CGFloat
            if imageRatio > viewRatio {
                renderWidth = viewSize.width
                renderHeight = viewSize.width / imageRatio
            } else {
                renderHeight = viewSize.height
                renderWidth = viewSize.height * imageRatio
            }

            let maxOffsetX = max((renderWidth * scale - viewSize.width) / 2, 0)
            let maxOffsetY = max((renderHeight * scale - viewSize.height) / 2, 0)
            let boundedOffset = CGSize(
                width: min(max(imageOffset.width, -maxOffsetX), maxOffsetX),
                height: min(max(imageOffset.height, -maxOffsetY), maxOffsetY)
            )
            let offsetX = (viewSize.width - renderWidth * scale) / 2 + boundedOffset.width
            let offsetY = (viewSize.height - renderHeight * scale) / 2 + boundedOffset.height

            let currentPinX = offsetX + renderWidth * scale * CGFloat(coordX) / 1000.0
            let currentPinY = offsetY + renderHeight * scale * CGFloat(coordY) / 1000.0

            let updateCoordinate: (CGPoint) -> Void = { point in
                let localX = point.x - offsetX
                let localY = point.y - offsetY
                let clampedX = max(0, min(localX, renderWidth * scale))
                let clampedY = max(0, min(localY, renderHeight * scale))
                coordX = Float((clampedX / (renderWidth * scale)) * 1000.0)
                coordY = Float((clampedY / (renderHeight * scale)) * 1000.0)
            }

            return ZStack(alignment: .topLeading) {
                Color.clear

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: renderWidth * scale, height: renderHeight * scale)
                    .position(x: viewSize.width / 2 + boundedOffset.width, y: viewSize.height / 2 + boundedOffset.height)
                    .gesture(
                        DragGesture(minimumDistance: 12, coordinateSpace: .local)
                            .onChanged { val in
                                guard scale > 1 else { return }
                                imageOffset = CGSize(
                                    width: min(max(lastImageOffset.width + val.translation.width, -maxOffsetX), maxOffsetX),
                                    height: min(max(lastImageOffset.height + val.translation.height, -maxOffsetY), maxOffsetY)
                                )
                            }
                            .onEnded { _ in
                                lastImageOffset = imageOffset
                            }
                    )

                // 拖拽光标（缩小到 20pt）
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.red)
                    .background(Circle().fill(Color.white).frame(width: 8, height: 8))
                    .shadow(radius: 3)
                    .position(x: currentPinX, y: currentPinY)
                    .gesture(
                        DragGesture()
                            .onChanged { val in
                                updateCoordinate(val.location)
                            }
                    )
            }
            .clipped()
            .contentShape(Rectangle())
            .gesture(
                MagnificationGesture()
                    .onChanged { newScale in
                        let nextScale = max(1.0, min(lastScale * newScale, 4.0))
                        scale = nextScale
                        if nextScale == 1.0 {
                            imageOffset = .zero
                            lastImageOffset = .zero
                        }
                    }
                    .onEnded { _ in
                        lastScale = scale
                        let finalMaxOffsetX = max((renderWidth * scale - viewSize.width) / 2, 0)
                        let finalMaxOffsetY = max((renderHeight * scale - viewSize.height) / 2, 0)
                        imageOffset = CGSize(
                            width: min(max(imageOffset.width, -finalMaxOffsetX), finalMaxOffsetX),
                            height: min(max(imageOffset.height, -finalMaxOffsetY), finalMaxOffsetY)
                        )
                        lastImageOffset = imageOffset
                    }
            )
        }
    }
}

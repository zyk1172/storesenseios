import SwiftUI

// 新增：排序枚举
enum SortType: String, CaseIterable {
    case name = "名称"
    case date = "创建时间"
}

struct ScanView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedTab: ContentView.Tab
    @State private var showCreateRoom = false
    @State private var newRoomName = ""
    @State private var selectedGroupName = ""
    @State private var showCreateGroup = false
    @State private var newGroupName = ""
    @State private var selectedLocation: StorageLocation?
    @State private var locationToDelete: StorageLocation?
    @State private var showDeleteConfirm = false
    @State private var showNoGroupAlert = false
    
    // 记录被折叠的收纳组名称
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
                            
                            // 新建菜单
                            Menu {
                                Button { showCreateGroup = true } label: {
                                    Label("新建收纳组", systemImage: "folder.badge.plus")
                                }
                                Button { 
                                    if appState.groups.isEmpty {
                                        showNoGroupAlert = true
                                    } else {
                                        selectedGroupName = appState.groups.first?.name ?? ""
                                        showCreateRoom = true 
                                    }
                                } label: {
                                    Label("新建收纳位", systemImage: "plus.circle")
                                }
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
            .sheet(isPresented: $showCreateGroup) {
                createGroupView
            }
            .sheet(item: $selectedLocation) { location in
                LocationDetailView(location: location, selectedTab: $selectedTab)
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
                "确定删除选中的收纳组和收纳位？",
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
                Text("删除收纳组将同时删除其内部的所有收纳位及其物品。此操作不可撤销。")
            }
            .alert("需要先建立收纳组", isPresented: $showNoGroupAlert) {
                Button("去创建收纳组") {
                    showCreateGroup = true
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("在创建收纳位之前，请先创建一个收纳组（例如：书房、主卧）。")
            }
        }
        .navigationViewStyle(.stack)
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "archivebox")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)
            Text("还没有收纳体系")
                .font(.headline)
            Text("请先建立一个收纳组，然后再创建你的收纳位")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("创建收纳组") { 
                showCreateGroup = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var locationListView: some View {
        ScrollView {
            LazyVStack(spacing: 20, pinnedViews: .sectionHeaders) {
                // 遍历经过排序的收纳组
                ForEach(sortedGroups, id: \.self) { groupName in
                    Section {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
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
                                            .font(.title2)
                                            .foregroundColor(selectedLocations.contains(location.id) ? .blue : .secondary.opacity(0.5))
                                            .background(Circle().fill(Color(.systemBackground)).padding(2))
                                            .padding(8)
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
                Text("收纳组大类排序")
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
        
        // 再删除选中的收纳组（顺带清理孤立的组）
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
        .contentShape(Rectangle()) // 确保整个区域可点击
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
                Section("收纳组") {
                    Picker("选择收纳组", selection: $selectedGroupName) {
                        ForEach(appState.groups) { group in
                            Text(group.name).tag(group.name)
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
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        if !newRoomName.isEmpty && !selectedGroupName.isEmpty {
                            _ = appState.createRoom(name: newRoomName, groupName: selectedGroupName)
                            newRoomName = ""
                            showCreateRoom = false
                        }
                    }
                    .disabled(newRoomName.isEmpty || selectedGroupName.isEmpty)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private var createGroupView: some View {
        NavigationView {
            Form {
                Section("收纳组名称") {
                    TextField("例如：书房、主卧", text: $newGroupName)
                }
            }
            .navigationTitle("新建收纳组")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showCreateGroup = false
                        newGroupName = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        if !newGroupName.isEmpty {
                            _ = appState.createGroup(name: newGroupName)
                            newGroupName = ""
                            showCreateGroup = false
                        }
                    }
                    .disabled(newGroupName.isEmpty)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

struct LocationCard: View {
    let location: StorageLocation
    let kleinBlue: Color
    
    // 计算距离创建过去的天数
    private func daysAgoString(from date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days == 0 {
            return String(localized: "今天创建")
        } else {
            return String(localized: "创建于 \(days) 天前")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 封面区域
            ZStack {
                if let coverData = location.coverImageData, let uiImage = UIImage(data: coverData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 100)
                        .clipped()
                } else if location.inputType == .textInput {
                    Rectangle()
                        .fill(kleinBlue)
                        .frame(height: 100)
                        .overlay {
                            Image(systemName: "text.quote")
                                .font(.system(size: 32))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 100)
                        .overlay {
                            Image(systemName: "archivebox")
                                .font(.system(size: 32))
                                .foregroundStyle(.secondary)
                        }
                }
            }
            
            // 信息区域
            VStack(alignment: .leading, spacing: 4) {
                Text(location.name)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                // 物品数量和时间组合在同一行
                HStack(spacing: 4) {
                    Text("\(location.items.count)个物品")
                        .foregroundStyle(.blue)
                    
                    Text("·")
                        .foregroundStyle(.secondary)
                    
                    Text(daysAgoString(from: location.createdAt))
                        .foregroundStyle(.secondary)
                }
                .font(.system(size: 10))
                .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
        }
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct LocationDetailView: View {
    let initialLocation: StorageLocation
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: StorageItem?
    @Binding var selectedTab: ContentView.Tab
    @State private var currentLocation: StorageLocation
    @State private var showDeleteConfirm = false
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
                    
                    if let advice = currentLocation.organizingAdvice, !advice.isEmpty {
                        organizingAdviceSection(advice: advice)
                    }
                    
                    itemsSection
                }
                .padding()
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
            .sheet(item: $selectedItem) { item in
                ItemDetailView(
                    item: item,
                    location: currentLocation,
                    onItemChanged: { _ in refreshLocation() },
                    onItemDeleted: { refreshLocation() }
                )
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
                    .scaledToFill()
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(16)
            } else if currentLocation.inputType == .textInput {
                Rectangle()
                    .fill(kleinBlue)
                    .frame(height: 200)
                    .cornerRadius(16)
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
                    .fill(Color(.systemGray5))
                    .frame(height: 200)
                    .cornerRadius(16)
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
            Text("📍 基准物品")
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
            if comment.contains("整齐") || comment.contains("模范") || comment.contains("赏心悦目") || comment.contains("完美") {
                return .green
            } else if comment.contains("加油") || comment.contains("潜力") || comment.contains("差一点") || comment.contains("继续") {
                return .orange
            } else {
                return .red
            }
        }()
        
        return Text(comment)
            .font(.body)
            .fontWeight(.medium)
            .foregroundStyle(commentColor)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(commentColor.opacity(0.1))
            .cornerRadius(10)
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
                    ItemRow(item: item)
                        .onTapGesture {
                            selectedItem = item
                        }
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
}

struct ItemRow: View {
    let item: StorageItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(.bold)
                
                Text(item.relativeLocation)
                    .font(.caption)
                    .foregroundStyle(.blue)
                
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
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(4)
                
                Text(Double(item.confidence), format: .percent.precision(.fractionLength(0)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
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
    var location: StorageLocation
    var onSaved: () -> Void
    
    @State private var coordX: Float = 500
    @State private var coordY: Float = 500
    @State private var name: String = ""
    @State private var category: String = ""
    @State private var relativeLocation: String = ""
    @State private var description: String = ""
    
    @State private var isRecognizing: Bool = false
    @AppStorage("openai_api_key") private var apiKey = ""
    @AppStorage("openai_base_url") private var baseURL = "https://api.openai.com/v1"
    @AppStorage("openai_model") private var model = "gpt-4o"
    
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
                        .disabled(isRecognizing || apiKey.isEmpty)
                    }
                }
                
                Section(header: Text("物品信息")) {
                    TextField("物品名称 (必填)", text: $name)
                    TextField("分类", text: $category)
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
        isRecognizing = true
        
        // 截取点击区域附近 40% 的图片，提供给 AI 进行更专注的识别
        let cropWidth = uiImage.size.width * 0.4
        let cropHeight = uiImage.size.height * 0.4
        let centerX = uiImage.size.width * CGFloat(coordX) / 1000.0
        let centerY = uiImage.size.height * CGFloat(coordY) / 1000.0
        
        let minX = max(0, centerX - cropWidth / 2)
        let minY = max(0, centerY - cropHeight / 2)
        let maxX = min(uiImage.size.width, centerX + cropWidth / 2)
        let maxY = min(uiImage.size.height, centerY + cropHeight / 2)
        
        let rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        
        // 兼容图片方向的正确裁剪
        let format = UIGraphicsImageRendererFormat()
        format.scale = uiImage.scale
        let renderer = UIGraphicsImageRenderer(size: rect.size, format: format)
        let croppedImage = renderer.image { _ in
            uiImage.draw(at: CGPoint(x: -rect.origin.x, y: -rect.origin.y))
        }
        
        guard let data = croppedImage.jpegData(compressionQuality: 0.8) else {
            isRecognizing = false
            return
        }
        
        do {
            let result = try await AIRecognitionService(apiKey: apiKey, baseURL: baseURL, model: model).recognizeObject(imageData: data)
            if let firstItem = result.items.first {
                name = firstItem.name
                if !firstItem.category.isEmpty { category = firstItem.category }
                if !firstItem.relativeLocation.isEmpty { relativeLocation = firstItem.relativeLocation }
                if !firstItem.description.isEmpty { description = firstItem.description }
            }
        } catch {
            print("局部识别失败: \(error)")
        }
        
        isRecognizing = false
    }
}

// 支持拖拽定位并计算千分比坐标的图片视图
struct InteractiveImageView: View {
    let image: UIImage
    @Binding var coordX: Float
    @Binding var coordY: Float

    var body: some View {
        GeometryReader { geo in
            let imageSize = image.size
            let viewSize = geo.size
            
            // 计算渲染比例
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
            
            let offsetX = (viewSize.width - renderWidth) / 2
            let offsetY = (viewSize.height - renderHeight) / 2
            
            let currentPinX = offsetX + renderWidth * CGFloat(coordX) / 1000.0
            let currentPinY = offsetY + renderHeight * CGFloat(coordY) / 1000.0

            // ⚠️ 就是这里加了 return，指明这段代码执行后返回这个 ZStack 视图
            return ZStack(alignment: .topLeading) {
                Color.clear 
                
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: viewSize.width, height: viewSize.height)
                
                // 拖拽光标
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.red)
                    .background(Circle().fill(Color.white).frame(width: 14, height: 14))
                    .shadow(radius: 4)
                    .position(x: currentPinX, y: currentPinY)
                    .gesture(
                        DragGesture()
                            .onChanged { val in
                                let localX = val.location.x - offsetX
                                let localY = val.location.y - offsetY
                                
                                // 限制拖动范围在图片内部
                                let clampedX = max(0, min(localX, renderWidth))
                                let clampedY = max(0, min(localY, renderHeight))
                                
                                coordX = Float((clampedX / renderWidth) * 1000.0)
                                coordY = Float((clampedY / renderHeight) * 1000.0)
                            }
                    )
            }
        }
        .clipped()
    }
}


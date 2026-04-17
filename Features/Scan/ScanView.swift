import SwiftUI

struct ScanView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedTab: ContentView.Tab
    @State private var showCreateRoom = false
    @State private var newRoomName = ""
    @State private var selectedLocation: StorageLocation?
    @State private var locationToDelete: StorageLocation?
    @State private var showDeleteConfirm = false
    
    // 克莱因蓝颜色
    private let kleinBlue = Color(red: 0.0, green: 0.18, blue: 0.65)

    var body: some View {
        NavigationView {
            VStack {
                if appState.rooms.isEmpty {
                    emptyStateView
                } else {
                    locationListView
                }
            }
            .navigationTitle("我的收纳位")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showCreateRoom = true } label: {
                        Image(systemName: "plus.circle")
                    }
                }
            }
            .sheet(isPresented: $showCreateRoom) {
                createRoomView
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
        }
        .navigationViewStyle(.stack)
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "archivebox")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)
            Text("还没有收纳位")
                .font(.headline)
            Text("点击右上角的 + 号创建你的第一个收纳位")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("立即创建") { showCreateRoom = true }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var locationListView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(appState.rooms) { location in
                    LocationCard(location: location, kleinBlue: kleinBlue)
                        .onTapGesture {
                            selectedLocation = location
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                locationToDelete = location
                                showDeleteConfirm = true
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                }
            }
            .padding()
        }
    }

    private var createRoomView: some View {
        NavigationView {
            Form {
                Section("收纳位名称") {
                    TextField("例如：左侧第一层抽屉", text: $newRoomName)
                }
            }
            .navigationTitle("新建收纳位")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showCreateRoom = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        if !newRoomName.isEmpty {
                            _ = appState.createRoom(name: newRoomName)
                            newRoomName = ""
                            showCreateRoom = false
                        }
                    }
                    .disabled(newRoomName.isEmpty)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

struct LocationCard: View {
    let location: StorageLocation
    let kleinBlue: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 封面区域 - 固定宽高比，避免不同尺寸图片导致重叠
            ZStack {
                if let coverData = location.coverImageData, let uiImage = UIImage(data: coverData) {
                    // 图片识别：显示压缩后的图片
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 120)
                        .clipped()
                } else if location.inputType == .textInput {
                    // 文字输入：显示克莱因蓝背景
                    Rectangle()
                        .fill(kleinBlue)
                        .frame(height: 120)
                        .overlay {
                            Image(systemName: "text.quote")
                                .font(.system(size: 30))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                } else {
                    // 默认：灰色背景
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 120)
                        .overlay {
                            Image(systemName: "archivebox")
                                .font(.system(size: 30))
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(maxWidth: .infinity)
            
            // 信息区域
            VStack(alignment: .leading, spacing: 4) {
                Text(location.name)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack {
                    Text("\(location.items.count) 个物品")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let anchor = location.anchorItemName {
                        Text(anchor)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .cornerRadius(4)
                    }
                }
                
                Text(location.updatedAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
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

    init(location: StorageLocation, selectedTab: Binding<ContentView.Tab>) {
        self.initialLocation = location
        self._selectedTab = selectedTab
        self._currentLocation = State(initialValue: location)
    }
    
    // 克莱因蓝颜色
    private let kleinBlue = Color(red: 0.0, green: 0.18, blue: 0.65)

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 封面区域
                    coverSection
                    
                    // 前往识别按钮
                    goToDetectButton
                    
                    // 基准物品
                    if let anchor = currentLocation.anchorItemName {
                        anchorSection(anchor: anchor)
                    }
                    
                    // 幽默评价
                    if let comment = currentLocation.funnyComment, !comment.isEmpty {
                        funnyCommentSection(comment: comment)
                    }
                    
                    // 收纳建议
                    if let advice = currentLocation.organizingAdvice, !advice.isEmpty {
                        organizingAdviceSection(advice: advice)
                    }
                    
                    // 物品列表
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
        }
        .navigationViewStyle(.stack)
    }

    private var coverSection: some View {
        Group {
            if let coverData = currentLocation.coverImageData, let uiImage = UIImage(data: coverData) {
                // 图片识别：显示压缩后的图片
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(16)
            } else if currentLocation.inputType == .textInput {
                // 文字输入：显示克莱因蓝背景
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
                // 默认：灰色背景
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
        // 根据评价内容判断颜色
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
            Text("物品清单")
                .font(.headline)
            
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
                
                Text("\(Int(item.confidence * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}

// 保留原有的ImagePicker组件
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

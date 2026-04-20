import SwiftUI
import Combine

struct DetectView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedImage: UIImage?
    @State private var isProcessing = false
    @State private var isDetectFinished = false
    @State private var result: AIRecognitionResult?
    @State private var error: String?
    
    @State private var detectionMode = 0 
    @State private var manualJSONText = ""
    @State private var showCopyToast = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var showTutorial = false

    @State private var apiKey = ""
    @AppStorage("openai_base_url") private var baseURL = "https://api.openai.com/v1"
    @AppStorage("openai_model") private var model = "gpt-4o"

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    imagePickerSection
                    
                    Picker("识别模式", selection: $detectionMode) {
                        Text("自动识别").tag(0)
                        Text("手动输入").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if detectionMode == 0 {
                        autoAIScreen
                    } else {
                        manualPasteScreen
                    }

                    if let result = result {
                        DetectionResultCard(result: result, selectedImage: selectedImage) {
                            // 保存后清空照片和结果
                            self.selectedImage = nil
                            self.result = nil
                        }
                        .transition(AnyTransition.move(edge: .bottom).combined(with: .opacity))
                    }

                    if let error = error {
                        errorView(error)
                    }
                }
                .padding()
            }
            .navigationTitle("识别物品")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            showTutorial = true
                        } label: {
                            Image(systemName: "questionmark.circle")
                                .font(.body)
                        }
                        
                        NavigationLink(destination: SettingsView()) {
                            Image(systemName: "gearshape")
                                .font(.body)
                        }
                    }
                }
            }
            .sheet(isPresented: $showTutorial) {
                TutorialView()
            }
            .overlay(alignment: .top) {
                if showCopyToast {
                    Text("提示词已复制")
                        .font(.subheadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.8))
                        .foregroundStyle(.white)
                        .cornerRadius(20)
                        .padding(.top, 10)
                        .transition(AnyTransition.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            self.apiKey = KeychainManager.shared.loadKey()
        }
    }

    // MARK: - Subviews
    
    private var imagePickerSection: some View {
        Group {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 250)
                    .cornerRadius(12)
                    .onTapGesture {
                        selectedImage = nil
                        result = nil
                    }
            } else {
                HStack(spacing: 16) {
                    // 左边：拍照识别
                    Button {
                        showCamera = true
                    } label: {
                        VStack(spacing: 12) {
                            Image(systemName: "camera")
                                .font(.system(size: 40))
                                .foregroundStyle(.blue)
                            Text("拍照识别")
                                .font(.headline)
                                .foregroundStyle(.blue)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 120, maxHeight: 180)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue, lineWidth: 2)
                        )
                    }
                    
                    // 右边：选择照片
                    Button {
                        showPhotoPicker = true
                    } label: {
                        VStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("选择照片")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 120, maxHeight: 180)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            ImagePicker(image: $selectedImage, sourceType: .camera)
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showPhotoPicker) {
            ImagePicker(image: $selectedImage, sourceType: .photoLibrary)
                .ignoresSafeArea()
        }
    }

    private var autoAIScreen: some View {
        VStack(spacing: 16) {
            // 开始AI识别按钮
            Button {
                Task { await detect() }
            } label: {
                HStack {
                    if isProcessing {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text("开始 AI 识别").fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isProcessing || selectedImage == nil || apiKey.isEmpty ? Color.gray : Color.blue)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
            .disabled(isProcessing || selectedImage == nil || apiKey.isEmpty)
            
            if isProcessing {
                AILoadingView(title: "正在识别物品...", isFinished: $isDetectFinished)
                    .padding(.top, 20)
            }
        }
        .padding(.horizontal)
    }

    private var manualPasteScreen: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("从网页版 AI 导入")
                    .font(.subheadline)
                    .fontWeight(.bold)
                Spacer()
                Button {
                    copyPrompt()
                } label: {
                    Label("复制提示词", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
            
            TextEditor(text: $manualJSONText)
                .font(.system(.caption, design: .monospaced))
                .frame(height: 120)
                .padding(8)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
            
            Button {
                processManualJSON()
            } label: {
                Text("解析并应用文字结果")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(manualJSONText.isEmpty ? Color.gray : Color.green)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }
            .disabled(manualJSONText.isEmpty)
        }
        .padding(.horizontal)
    }

    private func errorView(_ msg: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
            Text(msg).font(.subheadline).foregroundStyle(.red)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Actions

    private func copyPrompt() {
        // 显式引用类名以确保编译器识别静态属性
        UIPasteboard.general.string = AIRecognitionService.recognitionPrompt
        withAnimation { showCopyToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showCopyToast = false }
        }
    }

    private func detect() async {
        guard let data = selectedImage?.jpegData(compressionQuality: 0.8) else { return }
        isProcessing = true
        isDetectFinished = false
        error = nil
        do {
            let res = try await AIRecognitionService(apiKey: apiKey, baseURL: baseURL, model: model).recognizeObject(imageData: data)
            
            isDetectFinished = true
            // 等待半秒让100%动画走完
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            withAnimation { self.result = res }
        } catch {
            self.error = error.localizedDescription
        }
        isProcessing = false
    }

    private func processManualJSON() {
        error = nil
        let cleaned = manualJSONText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
        
        var targetString = cleaned
        if let start = cleaned.range(of: "{"), let end = cleaned.range(of: "}", options: .backwards) {
            targetString = String(cleaned[start.lowerBound..<end.upperBound])
        }

        guard let data = targetString.data(using: .utf8) else {
            error = String(localized: "无法读取输入的文本")
            return
        }

        do {
            let decoded = try JSONDecoder().decode(AIRecognitionResult.self, from: data)
            withAnimation { self.result = decoded }
        } catch {
            self.error = String(localized: "解析失败：请确保粘贴的是正确的 JSON 格式内容")
        }
    }
}

struct DetectionResultCard: View {
    let result: AIRecognitionResult
    let selectedImage: UIImage?
    @EnvironmentObject var appState: AppState
    @State private var saved = false
    var onSaved: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("识别结果").font(.headline)
                Spacer()
                
                // 保存按钮移到第一行
                if appState.currentRoom != nil {
                    Button {
                        save()
                    } label: {
                        // 使用 Label 闭包构造器来手动设置 Text 权重，以支持 iOS 16 以下系统
                        Label {
                            Text("保存")
                                .fontWeight(.bold)
                        } icon: {
                            Image(systemName: "square.and.arrow.down.fill")
                        }
                        .font(.subheadline)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .alert("已保存", isPresented: $saved) { 
                        Button("OK", role: .cancel) {
                            onSaved?()
                        }
                    }
                }
            }
            Divider()
            
            if let anchor = result.anchorObject {
                HStack {
                    Text("参照物").bold().frame(width: 80)
                    Text(anchor).foregroundStyle(.blue)
                }
                .font(.subheadline)
                .padding(.bottom, 8)
            }
            
            if !result.items.isEmpty {
                Text("识别到的物品：")
                    .font(.subheadline)
                    .fontWeight(.bold)
                ForEach(result.items, id: \.name) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.name).font(.headline)
                            Spacer()
                            Text(Double(item.confidence), format: .percent.precision(.fractionLength(0)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(item.relativeLocation).font(.caption).foregroundStyle(.blue)
                        if !item.description.isEmpty {
                            Text(item.description).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .padding(8)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(8)
                }
            }
            
            if appState.currentRoom == nil {
                Divider()
                Text("请先选择收纳位").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func save() {
        guard var location = appState.currentRoom else { return }
        
        // 覆盖模式：用本次识别结果替换所有物品
        location.items = result.items.map { item in
            StorageItem(
                name: item.name,
                category: item.category,
                relativeLocation: item.relativeLocation,
                description: item.description,
                confidence: item.confidence,
                coordX: item.coordX,
                coordY: item.coordY
            )
        }
        
        // 更新基础信息
        location.anchorItemName = result.anchorObject
        location.updatedAt = Date()
        
        // 保存收纳建议和幽默评价
        location.organizingAdvice = result.organizingAdvice
        location.funnyComment = result.funnyComment
        
        // 根据是否有图片设置输入类型和封面
        if let image = selectedImage {
            location.inputType = .imageRecognition
            // 缩放后存图，降低画质以减少存储占用
            let resized = resizeForStorage(image)
            if let coverData = resized.jpegData(compressionQuality: 0.2) {
                location.coverImageData = coverData
            }
            if let bgData = resized.jpegData(compressionQuality: 0.5) {
                location.backgroundImageData = bgData
            }
        } else {
            location.inputType = .textInput
        }
        
        ObjectStorageService().saveRoom(location)
        appState.currentRoom = location
        appState.loadRooms()
        saved = true
    }

    private func resizeForStorage(_ image: UIImage, maxDimension: CGFloat = 1024) -> UIImage {
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

// MARK: - 共享组件：五彩加载进度条
struct AILoadingView: View {
    let title: LocalizedStringKey
    @Binding var isFinished: Bool
    
    @State private var progress: Double = 0.0
    @State private var messageIndex = 0
    
    let messages: [LocalizedStringKey] = [
        "正在呼叫 AI，请稍候...",
        "AI 正在仔细观察...",
        "还在努力思考中，再给点耐心...",
        "处理了大量数据，即将完成...",
        "马上就好了，请别走开..."
    ]
    
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    let messageTimer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.headline)
            
            // 绚丽五彩的假进度条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray5))
                    
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.red, .orange, .yellow, .green, .blue, .purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * CGFloat(progress)))
                        .animation(.linear(duration: 0.1), value: progress)
                }
            }
            .frame(height: 12)
            
            HStack {
                Text(messages[messageIndex])
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
                    .id(messageIndex)
                
                Spacer()
                
                Text(progress, format: .percent.precision(.fractionLength(0)))
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(.primary)
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .onReceive(timer) { _ in
            if isFinished {
                withAnimation(.easeOut(duration: 0.3)) {
                    progress = 1.0
                }
            } else {
                if progress < 0.90 {
                    progress += (0.90 - progress) * 0.02 + 0.001
                } else if progress < 0.98 {
                    progress += 0.0005
                }
            }
        }
        .onReceive(messageTimer) { _ in
            if !isFinished, messageIndex < messages.count - 1 {
                withAnimation(.easeInOut) {
                    messageIndex += 1
                }
            }
        }
    }
}
// MARK: - 新手教学界面
struct TutorialView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .center, spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "cube.box.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.blue)
                        
                        Text("欢迎使用智能收纳助手")
                            .font(.largeTitle)
                            .bold()
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    
                    // 功能特色
                    VStack(alignment: .leading, spacing: 32) {
                        TutorialFeatureRow(
                            icon: "folder.badge.plus",
                            color: .blue,
                            title: "建立收纳空间",
                            description: "在「收纳位」标签中，必须先建立空间（如书房、主卧），然后再在其中创建专属的收纳位。"
                        )
                        TutorialFeatureRow(
                            icon: "camera.viewfinder",
                            color: .green,
                            title: "AI 智能识别",
                            description: "拍下或导入你整理好的物品照片，强大的 AI 会自动为你框选并记录所有物品及具体位置。"
                        )
                        TutorialFeatureRow(
                            icon: "magnifyingglass.circle.fill",
                            color: .purple,
                            title: "自然语言搜索",
                            description: "找东西时，只需在「搜索」中输入你想找的物品（如“喝水的杯子”），AI 会精准带你定位。"
                        )
                        TutorialFeatureRow(
                            icon: "gearshape.fill",
                            color: .orange,
                            title: "配置 API Key",
                            description: "在使用智能功能前，请确保在右上角设置图标中配置好支持视觉与对话大模型的 API Key。"
                        )
                        // 新增的隐私提示
                        TutorialFeatureRow(
                            icon: "lock.shield.fill",
                            color: .red,
                            title: "隐私安全提示",
                            description: "为保护您的隐私，请在拍照或选图前，确保照片中没有包含身份证、银行卡等敏感个人信息。图片只会被发送到您配置的 AI 模型提供商进行分析。"
                        )
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer(minLength: 40)
                    
                    // 按钮
                    Button {
                        dismiss()
                    } label: {
                        Text("开始体验")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(14)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

struct TutorialFeatureRow: View {
    let icon: String
    let color: Color
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    
    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(color)
                .frame(width: 48) // 固定宽度保证图标对齐
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}


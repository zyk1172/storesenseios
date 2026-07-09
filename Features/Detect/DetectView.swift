import SwiftUI
import Combine

struct DetectView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var llmManager: LLMManager
    @State private var selectedImage: UIImage?
    @State private var isProcessing = false
    @State private var isDetectFinished = false
    @State private var result: AIRecognitionResult?
    @State private var error: String?
    
    @State private var detectionMode = 0 
    @State private var manualJSONText = ""
    @State private var showCopyToast = false
    @State private var showTutorial = false

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
                        presentCamera()
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
                        presentPhotoLibrary()
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
                .background(isProcessing || selectedImage == nil || llmManager.currentConfig.apiKey.isEmpty ? Color.gray : Color.blue)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
            .disabled(isProcessing || selectedImage == nil || llmManager.currentConfig.apiKey.isEmpty)
            
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

    private func presentCamera() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = CameraProxy.shared
        picker.allowsEditing = false

        CameraProxy.shared.onImagePicked = { [weak rootVC] image in
            rootVC?.dismiss(animated: true) {
                if let root = rootVC {
                    presentMantisCrop(from: root, image: image, onCropped: { cropped in
                        selectedImage = cropped
                    }, onCancel: {})
                }
            }
        }
        rootVC.present(picker, animated: true)
    }

    private func presentPhotoLibrary() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = CameraProxy.shared
        picker.allowsEditing = false

        CameraProxy.shared.onImagePicked = { [weak rootVC] image in
            rootVC?.dismiss(animated: true) {
                if let root = rootVC {
                    presentMantisCrop(from: root, image: image, onCropped: { cropped in
                        selectedImage = cropped
                    }, onCancel: {})
                }
            }
        }
        rootVC.present(picker, animated: true)
    }

    private func presentCrop(_ image: UIImage) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }
        presentMantisCrop(from: rootVC, image: image, onCropped: { cropped in
            selectedImage = cropped
        }, onCancel: {})
    }

    private func copyPrompt() {
        // 显式引用类名以确保编译器识别静态属性
        UIPasteboard.general.string = AIRecognitionService.recognitionPrompt
        withAnimation { showCopyToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showCopyToast = false }
        }
    }

    private func detect() async {
        guard let image = selectedImage else { return }
        isProcessing = true
        isDetectFinished = false
        error = nil
        do {
            let config = llmManager.currentConfig
            let service = AIRecognitionService(apiKey: config.apiKey, baseURL: config.baseURL, model: config.model)

            // 处理图片：去 EXIF → 缩放
            let stripped = ImageProcessingService.stripMetadata(from: image)
            let resized = ImageProcessingService.resize(stripped, maxDimension: ImageProcessingService.maxDimension)

            let res: AIRecognitionResult
            let refItems = appState.currentRoom?.items

            // 暂时关闭四宫格/九宫格切分，先用整图验证坐标偏移问题。
#if false
            let pxW = CGFloat(resized.cgImage?.width ?? 0)
            let pxH = CGFloat(resized.cgImage?.height ?? 0)
            let area = pxW * pxH
            let threshold4 = ImageProcessingService.maxDimension * ImageProcessingService.maxDimension * 0.6
            let threshold9 = ImageProcessingService.maxDimension * ImageProcessingService.maxDimension * 1.2
            if area > threshold9 {
                // 生成整图参考（压缩到 1024px，用于定位判断）
                let fullRef = ImageProcessingService.drawCoordinateGrid(on: ImageProcessingService.resize(resized, maxDimension: 1024))
                let fullB64 = fullRef.jpegData(compressionQuality: 0.8)?.base64EncodedString()
                let chips = ImageProcessingService.gridSplitWithInfo(resized, rows: 3, cols: 3)
                res = try await service.recognizeMultipleImagesWithInfo(chips: chips, gridRows: 3, gridCols: 3, referenceItems: refItems, fullBase64Image: fullB64)
            } else if area > threshold4 {
                let fullRef = ImageProcessingService.drawCoordinateGrid(on: ImageProcessingService.resize(resized, maxDimension: 1024))
                let fullB64 = fullRef.jpegData(compressionQuality: 0.8)?.base64EncodedString()
                let chips = ImageProcessingService.gridSplitWithInfo(resized, rows: 2, cols: 2)
                res = try await service.recognizeMultipleImagesWithInfo(chips: chips, gridRows: 2, gridCols: 2, referenceItems: refItems, fullBase64Image: fullB64)
            } else {
                guard let data = resized.jpegData(compressionQuality: 0.85) else {
                    throw AIRecognitionError.invalidImage
                }
                res = try await service.recognizeObject(imageData: data, referenceItems: refItems)
            }
#else
            guard let data = resized.jpegData(compressionQuality: 0.9) else {
                throw AIRecognitionError.invalidImage
            }
            res = try await service.recognizeObject(imageData: data, referenceItems: refItems)
#endif

            isDetectFinished = true
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

    private var scoreColor: Color {
        guard let score = result.cleanlinessScore else { return .secondary }
        if score >= 75 { return .green }
        if score >= 55 { return .orange }
        return .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题行
            HStack {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("识别结果").font(.headline)
                Spacer()
                if appState.currentRoom != nil {
                    Button {
                        save()
                    } label: {
                        Label {
                            Text("保存").fontWeight(.bold)
                        } icon: {
                            Image(systemName: "square.and.arrow.down.fill")
                        }
                        .font(.subheadline)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .alert("已保存", isPresented: $saved) {
                        Button("OK", role: .cancel) { onSaved?() }
                    }
                }
            }
            Divider()

            // 整洁评分卡片
            if let level = result.cleanlinessLevel, let score = result.cleanlinessScore {
                VStack(spacing: 12) {
                    HStack {
                        Text("收纳整洁度").font(.headline)
                        Spacer()
                        Text(level)
                            .font(.headline)
                            .foregroundStyle(scoreColor)
                    }
                    // 分数条
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(.systemGray5))
                            RoundedRectangle(cornerRadius: 6)
                                .fill(scoreColor)
                                .frame(width: geo.size.width * CGFloat(score) / 100.0)
                        }
                    }
                    .frame(height: 10)
                    Text("\(score) / 100")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    // 五维度得分
                    if let dims = result.dimensionScores {
                        VStack(spacing: 6) {
                            dimensionRow(label: "分类归位", score: dims.categoryPlacement, max: 25)
                            dimensionRow(label: "空间利用", score: dims.spaceUsage, max: 20)
                            dimensionRow(label: "取用便利", score: dims.accessibility, max: 20)
                            dimensionRow(label: "视觉整洁", score: dims.visualTidiness, max: 20)
                            dimensionRow(label: "安全卫生", score: dims.safetyHygiene, max: 15)
                        }
                    }

                    // 主要问题
                    if let problems = result.mainProblems, !problems.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("主要问题").font(.caption).bold().foregroundStyle(.secondary)
                            ForEach(problems, id: \.self) { problem in
                                HStack(alignment: .top, spacing: 4) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                    Text(problem)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(12)
            }

            // 参照物
            if let anchor = result.anchorObject {
                HStack {
                    Text("参照物").bold().frame(width: 80)
                    Text(anchor).foregroundStyle(.blue)
                }
                .font(.subheadline)
            }

            // 物品列表
            if !result.items.isEmpty {
                Text("识别到的物品：").font(.subheadline).fontWeight(.bold)
                ForEach(Array(result.items.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.name).font(.headline)
                            Spacer()
                            Text(Double(item.confidence), format: .percent.precision(.fractionLength(0)))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Text(item.relativeLocation).font(.caption).foregroundStyle(.blue)
                        if !item.attributes.isEmpty {
                            Text(item.attributes).font(.caption2).foregroundStyle(.secondary)
                        }
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func dimensionRow(label: String, score: Int, max: Int) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .frame(width: 60, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemGray5))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(scoreColor.opacity(0.7))
                        .frame(width: geo.size.width * CGFloat(score) / CGFloat(max))
                }
            }
            .frame(height: 6)
            Text("\(score)/\(max)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)
        }
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
                attributes: item.attributes,
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
        location.cleanlinessLevel = result.cleanlinessLevel
        location.cleanlinessScore = result.cleanlinessScore
        location.mainProblems = result.mainProblems
        
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

// MARK: - 相机代理（单例，持有回调）

class CameraProxy: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    static let shared = CameraProxy()
    var onImagePicked: ((UIImage) -> Void)?

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        if let image = info[.originalImage] as? UIImage {
            onImagePicked?(image)
        }
        onImagePicked = nil
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        onImagePicked = nil
    }
}

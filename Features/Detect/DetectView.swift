import SwiftUI

struct DetectView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedImage: UIImage?
    @State private var isProcessing = false
    @State private var result: AIRecognitionResult?
    @State private var error: String?
    
    @State private var detectionMode = 0 
    @State private var manualJSONText = ""
    @State private var showCopyToast = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false

    @AppStorage("openai_api_key") private var apiKey = ""
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
                    NavigationLink(destination: SettingsView()) {
                        Text("设置")
                    }
                }
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
        error = nil
        do {
            result = try await AIRecognitionService(apiKey: apiKey, baseURL: baseURL, model: model).recognizeObject(imageData: data)
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
            error = "无法读取输入的文本"
            return
        }

        do {
            let decoded = try JSONDecoder().decode(AIRecognitionResult.self, from: data)
            withAnimation { self.result = decoded }
        } catch {
            self.error = "解析失败：请确保粘贴的是正确的 JSON 格式内容"
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
                    Text("基准物品").bold().frame(width: 80)
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
                            Text(String(format: "%.0f%%", item.confidence * 100))
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


import SwiftUI

struct DetectionConfirmView: View {
    let image: UIImage
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var llmManager: LLMManager
    @Environment(\.dismiss) private var dismiss
    @State private var isProcessing = false
    @State private var result: AIRecognitionResult?
    @State private var error: String?

    var body: some View {
        NavigationView {
            List {
                Section {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(12)
                        .listRowInsets(EdgeInsets())
                }
                
                if isProcessing {
                    HStack {
                        Spacer(); ProgressView(); Spacer()
                    }.listRowBackground(Color.clear)
                }

                if let res = result {
                    Section(header: Text("空间参考")) {
                        HStack {
                            Text("最显眼物品").bold()
                            Spacer()
                            Text(res.anchorObject ?? "自动选取").foregroundStyle(.blue)
                        }
                    }

                    Section(header: Text("识别到的物品")) {
                        ForEach(Array(res.items.enumerated()), id: \.offset) { _, item in
                            VStack(alignment: .leading) {
                                Text(item.name).font(.headline)
                                Text(item.relativeLocation).font(.subheadline).foregroundStyle(.blue)
                                if !item.attributes.isEmpty {
                                    Text(item.attributes).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("识别结果")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if result != nil {
                        Button(action: save) {
                            Text("确认更新").bold()
                        }
                    } else {
                        Button("开始分析") { Task { await detect() } }.disabled(isProcessing)
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func detect() async {
        isProcessing = true
        do {
            let config = llmManager.currentConfig
            let service = AIRecognitionService(apiKey: config.apiKey, baseURL: config.baseURL, model: config.model)

            let stripped = ImageProcessingService.stripMetadata(from: image)
            let resized = ImageProcessingService.resize(stripped, maxDimension: ImageProcessingService.maxDimension)

            let refItems = appState.currentRoom?.items

            // 暂时关闭四宫格/九宫格切分，先用整图验证坐标偏移问题。
#if false
            let pxW = CGFloat(resized.cgImage?.width ?? 0)
            let pxH = CGFloat(resized.cgImage?.height ?? 0)
            let area = pxW * pxH
            let threshold4 = ImageProcessingService.maxDimension * ImageProcessingService.maxDimension * 0.6
            let threshold9 = ImageProcessingService.maxDimension * ImageProcessingService.maxDimension * 1.2
            if area > threshold9 {
                let fullRef = ImageProcessingService.drawCoordinateGrid(on: ImageProcessingService.resize(resized, maxDimension: 1024))
                let fullB64 = fullRef.jpegData(compressionQuality: 0.8)?.base64EncodedString()
                let chips = ImageProcessingService.gridSplitWithInfo(resized, rows: 3, cols: 3)
                result = try await service.recognizeMultipleImagesWithInfo(chips: chips, gridRows: 3, gridCols: 3, referenceItems: refItems, fullBase64Image: fullB64)
            } else if area > threshold4 {
                let fullRef = ImageProcessingService.drawCoordinateGrid(on: ImageProcessingService.resize(resized, maxDimension: 1024))
                let fullB64 = fullRef.jpegData(compressionQuality: 0.8)?.base64EncodedString()
                let chips = ImageProcessingService.gridSplitWithInfo(resized, rows: 2, cols: 2)
                result = try await service.recognizeMultipleImagesWithInfo(chips: chips, gridRows: 2, gridCols: 2, referenceItems: refItems, fullBase64Image: fullB64)
            } else {
                guard let data = resized.jpegData(compressionQuality: 0.85) else {
                    throw AIRecognitionError.invalidImage
                }
                result = try await service.recognizeObject(imageData: data, referenceItems: refItems)
            }
#else
            guard let data = resized.jpegData(compressionQuality: 0.9) else {
                throw AIRecognitionError.invalidImage
            }
            result = try await service.recognizeObject(imageData: data, referenceItems: refItems)
#endif
        } catch {
            self.error = error.localizedDescription
        }
        isProcessing = false
    }

    private func save() {
        guard let res = result, var location = appState.currentRoom else { return }
        
        // 直接覆盖：用本次识别结果替换所有物品
        location.items = res.items.map { item in
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
        location.anchorItemName = res.anchorObject
        // 缩放后存图，降低画质以减少存储占用
        let resized = resizeForStorage(image)
        location.backgroundImageData = resized.jpegData(compressionQuality: 0.5)
        if let coverData = resized.jpegData(compressionQuality: 0.2) {
            location.coverImageData = coverData
        }
        location.inputType = .imageRecognition
        location.updatedAt = Date()
        
        // 保存收纳建议和幽默评价
        location.organizingAdvice = res.organizingAdvice
        location.funnyComment = res.funnyComment
        location.cleanlinessLevel = res.cleanlinessLevel
        location.cleanlinessScore = res.cleanlinessScore
        location.mainProblems = res.mainProblems
        
        // 保存并刷新
        ObjectStorageService().saveRoom(location)
        appState.currentRoom = location
        appState.loadRooms()
        dismiss()
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

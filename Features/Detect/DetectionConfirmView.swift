import SwiftUI

struct DetectionConfirmView: View {
    let image: UIImage
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var isProcessing = false
    @State private var result: AIRecognitionResult?
    @State private var error: String?

    @AppStorage("openai_api_key") private var apiKey = ""
    @AppStorage("openai_base_url") private var baseURL = "https://api.openai.com/v1"
    @AppStorage("openai_model") private var model = "gpt-4o"

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
                        ForEach(res.items, id: \.name) { item in
                            VStack(alignment: .leading) {
                                Text(item.name).font(.headline)
                                Text(item.relativeLocation).font(.subheadline).foregroundStyle(.blue)
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
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        isProcessing = true
        do {
            result = try await AIRecognitionService(apiKey: apiKey, baseURL: baseURL, model: model).recognizeObject(imageData: data)
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

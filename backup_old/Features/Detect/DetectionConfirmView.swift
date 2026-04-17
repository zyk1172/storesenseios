import SwiftUI

struct DetectionConfirmView: View {
    let image: UIImage
    let position: Position3D
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var isProcessing = false
    @State private var result: AIRecognitionResult?
    @State private var error: String?

    @AppStorage("openai_api_key") private var apiKey = ""
    @AppStorage("openai_base_url") private var baseURL = "https://api.openai.com/v1"
    @AppStorage("openai_model") private var model = "gpt-4o"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .cornerRadius(12)

                    if let result = result {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                Text("识别成功").font(.headline)
                            }
                            Divider()
                            Group {
                                HStack { Text("名称").bold().frame(width: 60); Text(result.name) }
                                HStack { Text("描述").bold().frame(width: 60); Text(result.description) }
                                HStack { Text("分类").bold().frame(width: 60); Text(result.category) }
                            }
                            .font(.subheadline)

                            Divider()

                            Button {
                                save(result)
                            } label: {
                                Label("保存到当前位置", systemImage: "plus.circle.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundStyle(.white)
                                    .cornerRadius(12)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    } else if isProcessing {
                        ProgressView("正在识别...").padding()
                    } else if let error = error {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 40)).foregroundStyle(.red)
                            Text("识别失败").font(.headline)
                            Text(error).font(.subheadline).foregroundStyle(.secondary)
                            Button {
                                Task { await detect() }
                            } label: {
                                Label("重试", systemImage: "arrow.clockwise")
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                    .background(Color.blue)
                                    .foregroundStyle(.white)
                                    .cornerRadius(8)
                            }
                        }
                        .padding()
                    } else {
                        Button {
                            Task { await detect() }
                        } label: {
                            Label("开始识别", systemImage: "sparkles")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .cornerRadius(12)
                        }
                        .disabled(apiKey.isEmpty)
                        .padding(.horizontal)
                    }
                }
                .padding()
            }
            .navigationTitle("识别物体")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func detect() async {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        isProcessing = true
        error = nil

        do {
            result = try await AIRecognitionService(apiKey: apiKey, baseURL: baseURL, model: model).recognizeObject(imageData: data)
        } catch {
            self.error = error.localizedDescription
        }

        isProcessing = false
    }

    private func save(_ result: AIRecognitionResult) {
        guard let thumbData = image.jpegData(compressionQuality: 0.3),
              let imgData = image.jpegData(compressionQuality: 0.8) else { return }

        var room = appState.currentRoom!
        room.addObject(DetectedObject(
            name: result.name,
            description: result.description,
            category: result.category,
            position: position,
            imageData: imgData,
            thumbnailData: thumbData,
            confidence: result.confidence,
            additionalInfo: result.additionalInfo
        ))

        ObjectStorageService().saveRoom(room)
        appState.currentRoom = room
        appState.loadRooms()
        dismiss()
    }
}
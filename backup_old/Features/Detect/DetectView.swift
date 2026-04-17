import SwiftUI
import PhotosUI

struct DetectView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedImage: UIImage?
    @State private var selectedItem: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var result: AIRecognitionResult?
    @State private var error: String?

    @AppStorage("openai_api_key") private var apiKey = ""
    @AppStorage("openai_base_url") private var baseURL = "https://api.openai.com/v1"
    @AppStorage("openai_model") private var model = "gpt-4o"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 300)
                            .cornerRadius(12)
                            .onTapGesture {
                                selectedImage = nil
                                result = nil
                            }
                    } else {
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            VStack(spacing: 12) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 48)).foregroundStyle(.secondary)
                                Text("点击选择照片").font(.headline)
                                Text("拍照后进行AI识别").font(.subheadline).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                    }

                    if selectedImage != nil {
                        Button {
                            Task { await detect() }
                        } label: {
                            HStack {
                                if isProcessing {
                                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "sparkles")
                                }
                                Text("AI 识别").fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isProcessing ? Color.gray : Color.blue)
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isProcessing || apiKey.isEmpty)
                        .padding(.horizontal)
                    }

                    if let result = result {
                        DetectionResultCard(result: result)
                    }

                    if let error = error {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                            Text(error).font(.subheadline).foregroundStyle(.red)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
            .navigationTitle("识别物体")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink("设置") { SettingsView() }
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                        result = nil
                        error = nil
                    }
                }
            }
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
}

struct DetectionResultCard: View {
    let result: AIRecognitionResult
    @EnvironmentObject var appState: AppState
    @State private var saved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("识别结果").font(.headline)
            }
            Divider()
            Group {
                HStack { Text("名称").bold().frame(width: 60); Text(result.name) }
                HStack { Text("描述").bold().frame(width: 60); Text(result.description) }
                HStack { Text("分类").bold().frame(width: 60); Text(result.category) }
                HStack { Text("置信度").bold().frame(width: 60); Text(String(format: "%.0f%%", result.confidence * 100)) }
            }
            .font(.subheadline)

            if !result.additionalInfo.isEmpty {
                Divider()
                ForEach(Array(result.additionalInfo.sorted(by: { $0.key < $1.key })), id: \.key) { k, v in
                    HStack { Text(k).bold().frame(width: 60); Text(v) }.font(.subheadline)
                }
            }

            Divider()

            if appState.currentRoom != nil {
                Button {
                    save()
                } label: {
                    Label("保存到当前房间", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .alert("已保存", isPresented: $saved) { Button("OK", role: .cancel) {} }
            } else {
                Text("请先选择房间").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func save() {
        guard var room = appState.currentRoom else { return }
        room.addObject(DetectedObject(
            name: result.name,
            description: result.description,
            category: result.category,
            position: .zero,
            confidence: result.confidence,
            additionalInfo: result.additionalInfo
        ))
        ObjectStorageService().saveRoom(room)
        appState.currentRoom = room
        appState.loadRooms()
        saved = true
    }
}
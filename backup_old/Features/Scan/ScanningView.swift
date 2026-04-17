import SwiftUI
import ARKit
import RealityKit

struct ScanningView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var scanCoordinator: ScanCoordinator
    @State private var showSaveAlert = false
    let room: Room

    var body: some View {
        ZStack {
            ARViewContainer(scanCoordinator: scanCoordinator)
                .edgesIgnoringSafeArea(.all)

            VStack {
                HStack {
                    Button("取消") { showSaveAlert = true }
                        .buttonStyle(.bordered)
                    Spacer()
                    VStack {
                        Text(room.name).font(.headline)
                        Text("扫描中...").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { } label: { Image(systemName: "cube") }
                        .buttonStyle(.bordered)
                }
                .padding()
                .background(.ultraThinMaterial)

                Spacer()

                HStack(spacing: 40) {
                    Button {
                        scanCoordinator.takePhotoForDetection()
                    } label: {
                        VStack {
                            Image(systemName: "camera.viewfinder").font(.title)
                            Text("拍照识别").font(.caption)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)

                    Button {
                        scanCoordinator.finishScanning()
                        appState.isScanning = false
                    } label: {
                        VStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title).foregroundStyle(.green)
                            Text("完成").font(.caption)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                }
                .padding()
            }
        }
        .sheet(item: $scanCoordinator.capturedImageForDetection) { data in
            if let image = UIImage(data: data.imageData) {
                DetectionConfirmView(image: image, position: data.position)
            }
        }
        .alert("保存扫描", isPresented: $showSaveAlert) {
            Button("取消", role: .cancel) {}
            Button("保存") {
                scanCoordinator.finishScanning()
                appState.isScanning = false
            }
        }
    }
}

struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var scanCoordinator: ScanCoordinator

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        let config = ARWorldTrackingConfiguration()
        config.environmentTexturing = .automatic

        // LiDAR 才支持 sceneReconstruction（Pro 机型）
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        config.environmentTexturing = .automatic

        if type(of: config).supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics = .sceneDepth
        }

        arView.session.run(config)
        scanCoordinator.setARView(arView)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}
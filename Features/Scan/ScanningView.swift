import SwiftUI
import ARKit
import RealityKit

struct ScanningView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var scanCoordinator: ScanCoordinator
    @State private var showSaveAlert = false
    let location: StorageLocation

    var body: some View {
        ZStack {
            // 1. 底层：AR 场景与 3D 网格渲染
            ARViewContainer(scanCoordinator: scanCoordinator)
                .edgesIgnoringSafeArea(.all)

            // 2. 中层：扫描准星
            Circle()
                .stroke(lineWidth: 2)
                .frame(width: 40, height: 40)
                .foregroundStyle(.white.opacity(0.6))
                .overlay { Circle().fill(.white).frame(width: 4, height: 4) }

            // 3. 顶层：UI 控制层
            VStack {
                HStack {
                    Button("退出") { showSaveAlert = true }
                        .buttonStyle(.bordered)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    
                    Spacer()
                    
                    VStack {
                        Text(location.name).font(.headline).foregroundStyle(.white)
                        // 显示地图建立进度
                        Text(scanCoordinator.mappingStatus)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.5))
                            .cornerRadius(4)
                            .foregroundStyle(.white)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "cube.fill")
                        .foregroundStyle(scanCoordinator.mappingStatus.contains("高") ? .green : .yellow)
                }
                .padding()

                Spacer()

                // 底部操作区
                HStack(spacing: 30) {
                    // 按钮：在已扫描好的位置识别物体
                    Button {
                        scanCoordinator.takePhotoForDetection()
                    } label: {
                        VStack {
                            ZStack {
                                Circle().fill(.white).frame(width: 64, height: 64)
                                Image(systemName: "camera.viewfinder").font(.title).foregroundStyle(.blue)
                            }
                            Text("识别物体").font(.caption).bold().foregroundStyle(.white)
                        }
                    }

                    // 按钮：保存并退出
                    Button {
                        scanCoordinator.finishScanning()
                        appState.isScanning = false
                    } label: {
                        VStack {
                            ZStack {
                                Circle().fill(.green).frame(width: 64, height: 64)
                                Image(systemName: "checkmark").font(.title).foregroundStyle(.white)
                            }
                            Text("完成").font(.caption).bold().foregroundStyle(.white)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
        // 🚀 修复错误：显式指定 data 类型
        .sheet(item: $scanCoordinator.capturedImageForDetection) { (data: CapturedImageData) in
            if let image = UIImage(data: data.imageData) {
                DetectionConfirmView(image: image)
            }
        }
        .alert("确定要退出吗？", isPresented: $showSaveAlert) {
            Button("取消", role: .cancel) {}
            Button("不保存退出", role: .destructive) {
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
        
        // 🚀 开启“3D 扫描仪”视觉效果：显示 ARKit 扫描出的物理网格
        arView.debugOptions.insert(.showSceneUnderstanding)
        
        // 配置环境理解，启用遮挡和物理交互
        arView.environment.sceneUnderstanding.options = [.occlusion, .physics]

        let config = ARWorldTrackingConfiguration()
        config.environmentTexturing = .automatic
        config.planeDetection = [.horizontal, .vertical]

        // 🚀 核心：启用网格重建（LiDAR 专用）
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }

        // 启用深度图，辅助射线检测
        if type(of: config).supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics = .sceneDepth
        }

        arView.session.run(config)
        scanCoordinator.setARView(arView)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}

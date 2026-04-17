import Foundation
import UIKit
import Combine
import RealityKit

@MainActor
class ScanCoordinator: NSObject, ObservableObject {
    @Published var isScanning = false
    @Published var capturedImageForDetection: CapturedImageData?
    @Published var mappingStatus: String = "准备就绪"
    
    // 兼容旧的 ARView 容器调用
    func setARView(_ view: ARView) {}

    // 🚀 修复：添加回缺失的方法以消除 View 层的报错 (no dynamic member)
    func takePhotoForDetection() {
        // 在 2D 模式下，照片捕获由 UI 层直接处理
        // 此处保留方法名以兼容尚未迁移的 AR 视图组件
        print("DEBUG: 旧的 3D 拍照逻辑被触发，请检查是否仍在使用旧的 ScanningView")
    }

    /// 处理捕获的照片
    func handleCapturedImage(_ image: UIImage) {
        if let data = image.jpegData(compressionQuality: 0.8) {
            // 🚀 修复：初始化不再传递 position 参数
            self.capturedImageForDetection = CapturedImageData(imageData: data)
            self.isScanning = false
        }
    }

    func startNewScan() {
        isScanning = true
        capturedImageForDetection = nil
    }

    func finishScanning() {
        isScanning = false
    }
}


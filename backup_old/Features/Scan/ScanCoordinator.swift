import Foundation
import ARKit
import RealityKit
import UIKit

class ScanCoordinator: NSObject, ObservableObject {
    @Published var isScanning = false
    @Published var capturedImageForDetection: CapturedImageData?
    private var arView: ARView?

    func setARView(_ view: ARView) {
        arView = view
        arView?.session.delegate = self
        isScanning = true
    }

    func takePhotoForDetection() {
        guard let frame = arView?.session.currentFrame else { return }
        let pos = Position3D(
            x: frame.camera.transform.columns.3.x,
            y: frame.camera.transform.columns.3.y,
            z: frame.camera.transform.columns.3.z
        )

        let ciImage = CIImage(cvPixelBuffer: frame.capturedImage)
        guard let cgImage = CIContext().createCGImage(ciImage, from: ciImage.extent) else { return }
        guard let data = UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.8) else { return }

        capturedImageForDetection = CapturedImageData(imageData: data, position: pos)
    }

    func finishScanning() {
        isScanning = false
        arView?.session.pause()
    }
}

struct CapturedImageData: Identifiable {
    let id = UUID()
    let imageData: Data
    let position: Position3D
}

extension ScanCoordinator: ARSessionDelegate {
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {}
}
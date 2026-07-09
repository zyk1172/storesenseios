import SwiftUI
import Mantis

/// 裁剪管理器：用 UIKit 方式 present CropViewController，避免 fullScreenCover 白屏
class CropCoordinator: NSObject, CropViewControllerDelegate {
    var onCropped: (UIImage) -> Void
    var onCancel: () -> Void

    init(onCropped: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
        self.onCropped = onCropped
        self.onCancel = onCancel
    }

    func cropViewControllerDidCrop(_ cropViewController: CropViewController,
                                   cropped: UIImage,
                                   transformation: Transformation,
                                   cropInfo: CropInfo) {
        cropViewController.dismiss(animated: true)
        onCropped(cropped)
    }

    func cropViewControllerDidCancel(_ cropViewController: CropViewController, original: UIImage) {
        cropViewController.dismiss(animated: true)
        onCancel()
    }

    func cropViewControllerDidFailToCrop(_ cropViewController: CropViewController, original: UIImage) {
        cropViewController.dismiss(animated: true)
        onCancel()
    }
}

/// 弹出 Mantis 裁剪界面的辅助函数
func presentMantisCrop(
    from source: UIViewController,
    image: UIImage,
    onCropped: @escaping (UIImage) -> Void,
    onCancel: @escaping () -> Void
) {
    var config = Mantis.Config()
    config.cropViewConfig.showAttachedRotationControlView = false
    config.presetFixedRatioType = .canUseMultiplePresetFixedRatio()

    let cropVC = Mantis.cropViewController(image: image, config: config)
    let coordinator = CropCoordinator(onCropped: onCropped, onCancel: onCancel)
    cropVC.delegate = coordinator

    // 用关联对象持有 coordinator，防止被释放
    objc_setAssociatedObject(cropVC, &AssociatedKeys.coordinator, coordinator, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

    source.present(cropVC, animated: true)
}

private struct AssociatedKeys {
    static var coordinator = "CropCoordinator"
}

/// 从 SwiftUI 视图中获取顶层 UIViewController
struct RootViewAccessor: UIViewRepresentable {
    var callback: (UIViewController) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                callback(rootVC)
            }
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

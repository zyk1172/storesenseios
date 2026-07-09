import Foundation
import UIKit
import ImageIO

/// 图片处理流水线：裁剪 → 去元数据 → 缩放 → 网格切分
struct ImageProcessingService {

    /// 缩放后长边最大像素
    static let maxDimension: CGFloat = 2048

    /// 网格切片的元数据
    struct ChipInfo {
        let data: Data
        /// 该切片左上角在原图中的像素位置
        let origin: CGPoint
        /// 该切片的像素宽高
        let size: CGSize
        /// 切片来源整图的像素宽高
        let fullSize: CGSize
    }

    /// 围绕用户选择点生成的局部识别切片。
    struct FocusedCropInfo {
        let data: Data
        let origin: CGPoint
        let size: CGSize
        let fullSize: CGSize
    }

    // MARK: - 主流程

    /// 完整处理链：去 EXIF → 缩放 → 可选切分 → 转 Data
    static func process(_ image: UIImage) -> [Data] {
        let stripped = stripMetadata(from: image)
        let resized = resize(stripped, maxDimension: maxDimension)

        // 暂时关闭四宫格/九宫格切分，先用整图验证 AI 返回坐标是否准确。
#if false
        let pxW = CGFloat(resized.cgImage?.width ?? 0)
        let pxH = CGFloat(resized.cgImage?.height ?? 0)
        let area = pxW * pxH
        let threshold4 = maxDimension * maxDimension * 0.6
        let threshold9 = maxDimension * maxDimension * 1.2
        if area > threshold9 {
            return gridSplit(resized, rows: 3, cols: 3)
        } else if area > threshold4 {
            return gridSplit(resized, rows: 2, cols: 2)
        }
#endif

        guard let data = resized.jpegData(compressionQuality: 0.85) else { return [] }
        return [data]
    }

    // MARK: - 去 EXIF / GPS / 元数据

    static func stripMetadata(from image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }

        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
            .union(.byteOrder32Little)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return image }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let cleanCG = context.makeImage() else { return image }
        // scale=1.0：CGContext 输出的是纯像素，不要继承原图 scale
        return UIImage(cgImage: cleanCG, scale: 1.0, orientation: .up)
    }

    // MARK: - 缩放（基于 CGImage 像素尺寸，不受 scale 影响）

    static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        guard let cgImage = image.cgImage else { return image }

        let pxW = CGFloat(cgImage.width)
        let pxH = CGFloat(cgImage.height)
        let ratio = min(maxDimension / pxW, maxDimension / pxH, 1.0)
        if ratio >= 1.0 { return image }

        let newSize = CGSize(width: pxW * ratio, height: pxH * ratio)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0  // 确保输出像素 = points，不受屏幕 scale 影响
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    // MARK: - 坐标网格叠加（仅用于发送给 AI 的图片）

    /// 在图片上叠加浅色坐标网格，帮助 AI 理解 0-1000 坐标系
    /// 细线每 5 单位，辅助线每 25 单位，主线每 50 单位 + 数字标注
    static func drawCoordinateGrid(on image: UIImage) -> UIImage {
        let size = image.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { ctx in
            image.draw(at: .zero)
            let c = ctx.cgContext

            let thinColor = UIColor(white: 0, alpha: 0.06).cgColor
            let midColor = UIColor.systemBlue.withAlphaComponent(0.10).cgColor
            let majorColor = UIColor(white: 0, alpha: 0.15).cgColor
            let labelColor = UIColor(white: 0, alpha: 0.25)
            let fontSize = max(size.width / 180.0, 7)
            let font = UIFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .regular)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: labelColor]

            // 细线：每 5 单位
            c.setStrokeColor(thinColor)
            c.setLineWidth(0.3)
            for i in 1..<200 {
                let x = size.width * CGFloat(i) / 200.0
                c.move(to: CGPoint(x: x, y: 0)); c.addLine(to: CGPoint(x: x, y: size.height))
                let y = size.height * CGFloat(i) / 200.0
                c.move(to: CGPoint(x: 0, y: y)); c.addLine(to: CGPoint(x: size.width, y: y))
            }
            c.strokePath()

            // 辅助线：每 25 单位，帮助读出 50 主刻度之间的中点
            c.setStrokeColor(midColor)
            c.setLineWidth(0.5)
            for i in 1..<40 where i % 2 != 0 {
                let val = i * 25
                let x = size.width * CGFloat(val) / 1000.0
                c.move(to: CGPoint(x: x, y: 0)); c.addLine(to: CGPoint(x: x, y: size.height))
                let y = size.height * CGFloat(val) / 1000.0
                c.move(to: CGPoint(x: 0, y: y)); c.addLine(to: CGPoint(x: size.width, y: y))
            }
            c.strokePath()

            // 主线：每 50 单位 + 数字标注
            c.setStrokeColor(majorColor)
            c.setLineWidth(0.8)
            for i in 1..<20 {
                let val = i * 50
                let x = size.width * CGFloat(val) / 1000.0
                c.move(to: CGPoint(x: x, y: 0)); c.addLine(to: CGPoint(x: x, y: size.height))
                let y = size.height * CGFloat(val) / 1000.0
                c.move(to: CGPoint(x: 0, y: y)); c.addLine(to: CGPoint(x: size.width, y: y))
                // 顶部标注
                ("\(val)" as NSString).draw(at: CGPoint(x: x + 2, y: 2), withAttributes: attrs)
                // 左侧标注
                ("\(val)" as NSString).draw(at: CGPoint(x: 2, y: y + 2), withAttributes: attrs)
            }
            c.strokePath()

            // 角落标注
            ("0" as NSString).draw(at: CGPoint(x: 2, y: 2), withAttributes: attrs)
            ("1000" as NSString).draw(at: CGPoint(x: size.width - fontSize * 3.5, y: 2), withAttributes: attrs)
            ("1000" as NSString).draw(at: CGPoint(x: 2, y: size.height - fontSize - 2), withAttributes: attrs)

            // 中心十字，给模型一个稳定的 500/500 参照。
            c.setStrokeColor(UIColor.systemRed.withAlphaComponent(0.28).cgColor)
            c.setLineWidth(1.0)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            c.move(to: CGPoint(x: center.x - 10, y: center.y))
            c.addLine(to: CGPoint(x: center.x + 10, y: center.y))
            c.move(to: CGPoint(x: center.x, y: center.y - 10))
            c.addLine(to: CGPoint(x: center.x, y: center.y + 10))
            c.strokePath()
            ("500,500" as NSString).draw(at: CGPoint(x: center.x + 4, y: center.y + 4), withAttributes: attrs)
        }
    }

    // MARK: - 网格切分（标准四宫格/九宫格）

    static func gridSplitWithInfo(_ image: UIImage, rows: Int, cols: Int, overlapRatio: CGFloat = 0.15) -> [ChipInfo] {
        guard let cgImage = image.cgImage else { return [] }

        let imgW = CGFloat(cgImage.width)
        let imgH = CGFloat(cgImage.height)
        let cellW = imgW / CGFloat(cols)
        let cellH = imgH / CGFloat(rows)
        let overlapX = cellW * overlapRatio
        let overlapY = cellH * overlapRatio

        var chips: [ChipInfo] = []
        for r in 0..<rows {
            for c in 0..<cols {
                let baseX = CGFloat(c) * cellW
                let baseY = CGFloat(r) * cellH
                let originX = max(0, baseX - overlapX)
                let originY = max(0, baseY - overlapY)
                let maxX = min(imgW, baseX + cellW + overlapX)
                let maxY = min(imgH, baseY + cellH + overlapY)
                let rect = CGRect(x: originX, y: originY, width: maxX - originX, height: maxY - originY).integral
                if let cropped = cgImage.cropping(to: rect) {
                    let chip = UIImage(cgImage: cropped, scale: image.scale, orientation: .up)
                    if let data = chip.jpegData(compressionQuality: 0.85) {
                        chips.append(
                            ChipInfo(
                                data: data,
                                origin: rect.origin,
                                size: rect.size,
                                fullSize: CGSize(width: imgW, height: imgH)
                            )
                        )
                    }
                }
            }
        }
        return chips
    }

    static func gridSplit(_ image: UIImage, rows: Int, cols: Int) -> [Data] {
        gridSplitWithInfo(image, rows: rows, cols: cols).map { $0.data }
    }

    /// 围绕 0-1000 坐标裁出较小区域，用于“添加/编辑物品”的单物品局部识别。
    static func focusedCropWithInfo(
        from image: UIImage,
        coordX: Float,
        coordY: Float,
        cropRatio: CGFloat = 0.24,
        minSide: CGFloat = 280,
        maxSide: CGFloat = 560
    ) -> FocusedCropInfo? {
        let normalized = stripMetadata(from: image)
        guard let cgImage = normalized.cgImage else { return nil }

        let imgW = CGFloat(cgImage.width)
        let imgH = CGFloat(cgImage.height)
        guard imgW > 0, imgH > 0 else { return nil }

        let safeX = CGFloat(min(max(coordX, 0), 1000)) / 1000.0
        let safeY = CGFloat(min(max(coordY, 0), 1000)) / 1000.0
        let centerX = imgW * safeX
        let centerY = imgH * safeY

        let shortestSide = min(imgW, imgH)
        let requestedSide = shortestSide * cropRatio
        let cropSide = min(max(requestedSide, minSide), maxSide, shortestSide)

        let minX = min(max(centerX - cropSide / 2, 0), max(imgW - cropSide, 0))
        let minY = min(max(centerY - cropSide / 2, 0), max(imgH - cropSide, 0))
        let rect = CGRect(x: minX, y: minY, width: cropSide, height: cropSide).integral

        guard let cropped = cgImage.cropping(to: rect) else { return nil }
        let chip = UIImage(cgImage: cropped, scale: 1.0, orientation: .up)
        guard let data = chip.jpegData(compressionQuality: 0.88) else { return nil }

        return FocusedCropInfo(
            data: data,
            origin: rect.origin,
            size: rect.size,
            fullSize: CGSize(width: imgW, height: imgH)
        )
    }

    // MARK: - 网格坐标映射

    /// 把标准网格切片内局部坐标 (0-1000) 映射到整图坐标 (0-1000)
    static func mapCoordinate(
        _ point: (x: Float, y: Float),
        chipIndex: Int,
        rows: Int,
        cols: Int
    ) -> (x: Float, y: Float) {
        let safeCols = max(cols, 1)
        let safeRows = max(rows, 1)
        let col = max(0, min(chipIndex % safeCols, safeCols - 1))
        let row = max(0, min(chipIndex / safeCols, safeRows - 1))
        let localX = min(max(point.x, 0), 1000) / 1000
        let localY = min(max(point.y, 0), 1000) / 1000
        let x = (Float(col) + localX) / Float(safeCols) * 1000
        let y = (Float(row) + localY) / Float(safeRows) * 1000
        return (min(max(x, 0), 1000), min(max(y, 0), 1000))
    }

    /// 把切片内局部坐标 (0-1000) 映射到整图坐标 (0-1000)
    static func mapCoordinate(
        _ point: (x: Float, y: Float),
        chip: ChipInfo
    ) -> (x: Float, y: Float) {
        guard chip.fullSize.width > 0, chip.fullSize.height > 0 else {
            return (min(max(point.x, 0), 1000), min(max(point.y, 0), 1000))
        }
        let localX = CGFloat(min(max(point.x, 0), 1000)) / 1000
        let localY = CGFloat(min(max(point.y, 0), 1000)) / 1000
        let pixelX = chip.origin.x + localX * chip.size.width
        let pixelY = chip.origin.y + localY * chip.size.height
        let fullX = Float(pixelX / chip.fullSize.width * 1000)
        let fullY = Float(pixelY / chip.fullSize.height * 1000)
        return (min(max(fullX, 0), 1000), min(max(fullY, 0), 1000))
    }

    static func mapCoordinate(
        _ point: (x: Float, y: Float),
        crop: FocusedCropInfo
    ) -> (x: Float, y: Float) {
        guard crop.fullSize.width > 0, crop.fullSize.height > 0 else {
            return (min(max(point.x, 0), 1000), min(max(point.y, 0), 1000))
        }
        let localX = CGFloat(min(max(point.x, 0), 1000)) / 1000
        let localY = CGFloat(min(max(point.y, 0), 1000)) / 1000
        let pixelX = crop.origin.x + localX * crop.size.width
        let pixelY = crop.origin.y + localY * crop.size.height
        let fullX = Float(pixelX / crop.fullSize.width * 1000)
        let fullY = Float(pixelY / crop.fullSize.height * 1000)
        return (min(max(fullX, 0), 1000), min(max(fullY, 0), 1000))
    }
}

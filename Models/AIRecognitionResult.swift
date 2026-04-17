import Foundation

struct AIRecognitionResult: Codable {
    /// AI 选定的最明显的"参考基准物"
    let anchorObject: String?
    /// 识别出的所有物品及其相对于 anchorObject 的位置
    let items: [AIItemResult]
    /// AI生成的收纳建议（200字以内）
    let organizingAdvice: String?
    /// AI生成的幽默评价（18字以内）
    let funnyComment: String?
}

struct AIItemResult: Codable {
    let name: String
    let category: String
    /// 比如："在[anchorObject]左边3厘米处"
    let relativeLocation: String
    let description: String
    let confidence: Float
    /// 物品在图片中的 X 坐标 (0-1000, 左上角为原点)
    let coordX: Float?
    /// 物品在图片中的 Y 坐标 (0-1000, 左上角为原点)
    let coordY: Float?
}

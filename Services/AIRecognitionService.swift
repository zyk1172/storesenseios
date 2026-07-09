import Foundation
import UIKit

private struct ChatCompletionsResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String
    }
}

final class AIRecognitionService {
    static let recognitionPrompt = """
    你是一个专业的家居收纳识别与评价助手。

    ═══════════════════════════════════════
    一、图片说明
    ═══════════════════════════════════════

    图片上叠加了浅色坐标网格（每5单位细线，每50单位主线+数字标注），坐标范围 0-1000。
    - 左上角为原点 (0, 0)，右下角为 (1000, 1000)
    - X 轴向右增大，Y 轴向下增大
    - 坐标必须对准物品的中心点（不是边缘）
    - 对每个物品，先想象它的可见外接矩形，再输出该矩形的中心点坐标；不要把坐标放到标签、阴影、边框或物品边缘。
    - 如果提供了多张图，第一张是整图参考图，第二张是本次需要识别的详细图；坐标规则以本次任务补充说明为准。

    ═══════════════════════════════════════
    二、物品识别规则
    ═══════════════════════════════════════

    1. 召回率优先：任务目标是尽可能多地列出可见独立物品，宁可把不太确定的小物件以较低 confidence 输出，也不要只输出最显眼的大件。
    2. 不要在 8 个或 10 个停止。请按 3x3 区域从左上到右下逐格扫描：左上、上中、右上、左中、中心、右中、左下、下中、右下。每个区域都检查桌面/柜格/角落/边缘/遮挡缝隙。
    3. 对杂乱或物品密集场景，目标输出 20-60 个物品；如果图片里明显超过 20 个可见物品，items 不应只有个位数。只有在画面确实物品很少时才可以少于 15 个。
    4. 输出独立可取用的最小合理单元：一支笔、一根数据线、一个瓶子、一个盒子、一本书、一包纸巾都要分开列出。不要把“文具”“杂物”“一堆线”“一叠书”这种集合当成单个物品，除非无法分辨单体。
    5. 必须包含小物件和边缘物件：数据线、橡皮、笔、纸片、便签、瓶盖、钥匙、硬币、纸巾、食物包装、耳机、充电器、遥控器、药盒、卡片、收纳袋等。
    6. 对不确定但可见的物品，使用通用名称并降低 confidence，例如“黑色小盒子”“透明塑料袋”“白色圆形瓶盖”；不要因为名称不确定就漏掉。
    7. 名称和属性分开：name 只写物品通用叫法，不要把品牌、型号、颜色、材质混进名称。例如看到“小米保温杯”，name 写“保温杯”，attributes 写“品牌:小米”；看到“Apple Watch 手表”，name 写“手表”，attributes 写“品牌:Apple; 系列:Watch”。
    8. attributes 写物品属性，格式用分号分隔，例如“品牌:小米; 颜色:白色; 材质:不锈钢; 型号:未知”。没有明显属性时输出空字符串。
    9. 食品/饮料：在 description 中注明预估保存期限。
    10. 选择最明显的物品作为 anchorObject 参照物。
    11. confidence 取值 0 到 1。
    12. 禁止重复识别同一物品，但不要把相邻的同类多个实体合并。例如两支笔、两瓶饮料、两本书应输出为两个物品，并用位置/颜色/大小区分。
    13. 被切分的物品应结合整图和切分图综合判断，在整图中找到中心位置输出坐标。

    ═══════════════════════════════════════
    三、收纳评价（5S 标准 + 量化评分）
    ═══════════════════════════════════════

    综合判断五个维度，每项严格不超过满分上限（总分100）：

    | 维度 | 满分 | 判断标准 |
    |------|------|----------|
    | 分类归位 | 25 | 同类集中、有固定位置、无跨类混放 |
    | 空间利用 | 20 | 无溢出边界、无过度堆叠、有留白 |
    | 取用便利 | 20 | 常用物品易拿、无需翻找搬动 |
    | 视觉整洁 | 20 | 物品对齐、无散落小件、无压迫感 |
    | 安全卫生 | 15 | 无垃圾污渍、无危险混放 |

    等级：90-100 非常整齐 | 75-89 整齐 | 55-74 一般 | 35-54 稍显杂乱 | 0-34 非常杂乱

    判断原则：
    - 物品多≠杂乱（分类清楚即可）；物品少≠整齐（有垃圾应降级）
    - 对生活场景宽容，不用样板间标准
    - 食品/药品/清洁剂/电子设备/插线板/液体/尖锐物混放要警惕
    - 结合场景功能判断（厨房/卫生间/书桌/冰箱标准不同）

    ═══════════════════════════════════════
    四、收纳建议
    ═══════════════════════════════════════

    organizingAdvice（200字以内）：
    - 引用 mainProblems 中的具体问题
    - 每个问题给出改进方法
    - 总体收纳建议

    funnyComment（20字以内）：
    根据等级给出幽默评价，开头带颜色标签：
    - 非常整齐/整齐："【绿】" | 一般："【黄】" | 稍显杂乱/非常杂乱："【红】"
    每次随机挑选不同表达。

    ═══════════════════════════════════════
    五、输出要求
    ═══════════════════════════════════════

    - items：物品清单（名称、分类、属性、坐标、描述、置信度）
    - totalItemCount：整图中物品总数（不重复计数）
    - 返回前自检：totalItemCount 必须接近 items.count；如果你估计图中有更多物品，请继续把缺失物品加入 items，不要只提高 totalItemCount。
    - cleanlinessLevel / cleanlinessScore / dimensionScores：整洁评分
    - organizingAdvice / funnyComment：建议和评价
    - mainProblems：主要问题列表
    - 评分数据只在识别整图时输出，切分图只输出 items
    """

    static let focusedRegionInstruction = """
    【局部单物品识别规则】
    这次不是整图盘点，不要尽可能多识别物品。只识别图片中心红色十字或 500,500 坐标附近的一个目标物品。
    - items 最多返回 1 个物品。
    - 如果画面里有多个物品，只选择中心点最接近红色十字的那个；不要输出边缘、背景或更显眼但不在中心的物品。
    - coordX/coordY 输出这个目标物品在当前局部图 0-1000 坐标系下的中心点。
    - anchorObject、organizingAdvice、funnyComment、cleanlinessLevel、cleanlinessScore、dimensionScores、mainProblems、totalItemCount 都返回 null。
    """

    private let apiKey: String
    private let baseURL: String
    private let model: String

        /// 语言代码到完整输出语言指令的映射（强制用目标语言输出）
    static let languageInstructions: [String: String] = [
        "zh-Hans": "请严格用简体中文输出所有文本内容，包括物品名称、分类、描述、建议、评价、等级名称、主要问题等。不要使用任何英文。",
        "zh-Hant": "請嚴格用繁體中文輸出所有文字內容，包括物品名稱、分類、描述、建議、評價、等級名稱、主要問題等。不要使用任何英文。",
        "en": "CRITICAL: Output ALL text content in English ONLY. This includes item names, categories, descriptions, advice, comments, cleanliness level names, main problems. Do NOT use ANY Chinese characters. Every single text field must be in English.",
        "ja": "重要：すべてのテキスト内容を日本語のみで出力。品名、カテゴリ、説明、アドバイス、コメント、清潔度レベル名、主な問題など、すべて日本語。中国語は一切使用しない。",
        "ko": "중요: 모든 텍스트를 한국어로만 출력. 품목명, 카테고리, 설명, 조언, 코멘트, 청결도 레벨명, 주요 문제 등 모든 텍스트가 한국어. 중국어 절대 사용 금지.",
        "es": "IMPORTANTE: TODO el texto SOLO en español. Nombres, categorías, descripciones, consejos, comentarios, nivel de limpieza, problemas. NO uses NINGÚN carácter chino.",
        "fr": "IMPORTANT : Tout le texte UNIQUEMENT en français. Noms, catégories, descriptions, conseils, commentaires, niveau de propreté, problèmes. N'utilisez AUCUN caractère chinois.",
        "de": "WICHTIG: Alles AUSSCHLIESSLICH auf Deutsch. Namen, Kategorien, Beschreibungen, Ratschläge, Kommentare, Sauberkeitsgrad, Probleme. KEINE chinesischen Zeichen."
    ]

    init(apiKey: String, baseURL: String = "https://api.openai.com/v1", model: String = "gpt-4o") {
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        self.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 单张图片识别（带重试）
    func recognizeObject(
        imageData: Data,
        language: String? = nil,
        referenceItems: [StorageItem]? = nil,
        fullBase64Image: String? = nil,
        chipInstruction: String? = nil
    ) async throws -> AIRecognitionResult {
        // 最多重试 2 次，处理首次可能的瞬时失败
        var lastError: Error?
        for attempt in 0..<2 {
            do {
                return try await recognizeObjectOnce(
                    imageData: imageData,
                    language: language,
                    referenceItems: referenceItems,
                    fullBase64Image: fullBase64Image,
                    chipInstruction: chipInstruction
                )
            } catch {
                lastError = error
                if attempt == 0 {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
            }
        }
        throw lastError!
    }

    private func recognizeObjectOnce(imageData: Data, language: String?, referenceItems: [StorageItem]?, fullBase64Image: String?, chipInstruction: String?) async throws -> AIRecognitionResult {
        guard let image = UIImage(data: imageData) else {
            throw AIRecognitionError.invalidImage
        }

        let resized = resizeImage(image, maxDimension: 2048)
        // 叠加坐标网格帮助 AI 定位
        let gridded = ImageProcessingService.drawCoordinateGrid(on: resized)
        guard let normalizedData = gridded.jpegData(compressionQuality: 0.8) else {
            throw AIRecognitionError.invalidImage
        }

        let url = try makeCompletionsURL()
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 600
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: makeRequestBody(
            base64Image: normalizedData.base64EncodedString(),
            language: language,
            referenceItems: referenceItems,
            fullBase64Image: fullBase64Image,
            chipInstruction: chipInstruction
        ))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIRecognitionError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw AIRecognitionError.httpError(httpResponse.statusCode, message: extractErrorMessage(from: data))
        }

        let decoded = try JSONDecoder().decode(ChatCompletionsResponse.self, from: data)
        guard let rawContent = decoded.choices.first?.message.content,
              !rawContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIRecognitionError.emptyResponse
        }

        let cleanContent = stripCodeFence(from: rawContent)
        guard let jsonData = cleanContent.data(using: .utf8) else {
            throw AIRecognitionError.parsingError
        }

        do {
            return try JSONDecoder().decode(AIRecognitionResult.self, from: jsonData)
        } catch {
            print("解析失败: \(error)")
            throw AIRecognitionError.parsingError
        }
    }

    /// 多张子图识别 + 坐标映射 + 去重合并
    func recognizeMultipleImages(
        imageDataList: [Data],
        gridRows: Int,
        gridCols: Int,
        language: String? = nil
    ) async throws -> AIRecognitionResult {
        guard !imageDataList.isEmpty else {
            throw AIRecognitionError.invalidImage
        }

        // 单图直接走原逻辑
        if imageDataList.count == 1 {
            return try await recognizeObject(imageData: imageDataList[0], language: language)
        }

        // 多图：逐张识别
        var allItems: [AIItemResult] = []
        var anchorObject: String?
        var organizingAdvice: String?
        var funnyComment: String?
        var cleanlinessLevel: String?
        var cleanlinessScore: Int?
        var dimensionScores: DimensionScores?
        var mainProblems: [String]?

        for (index, data) in imageDataList.enumerated() {
            let result = try await recognizeObject(imageData: data, language: language)

            // 映射坐标回原图
            let mappedItems = result.items.map { item -> AIItemResult in
                var mapped = item
                if let cx = item.coordX, let cy = item.coordY {
                    let m = ImageProcessingService.mapCoordinate(
                        (x: cx, y: cy),
                        chipIndex: index,
                        rows: gridRows,
                        cols: gridCols
                    )
                    mapped = AIItemResult(
                        name: item.name,
                        category: item.category,
                        relativeLocation: item.relativeLocation,
                        description: item.description,
                        attributes: item.attributes,
                        confidence: item.confidence,
                        coordX: m.x,
                        coordY: m.y
                    )
                }
                return mapped
            }
            allItems.append(contentsOf: mappedItems)

            if anchorObject == nil, let anchor = result.anchorObject {
                anchorObject = anchor
            }
            if organizingAdvice == nil, let advice = result.organizingAdvice {
                organizingAdvice = advice
            }
            if funnyComment == nil, let comment = result.funnyComment {
                funnyComment = comment
            }
            // 取第一张图的评价数据作为整体评估
            if cleanlinessLevel == nil { cleanlinessLevel = result.cleanlinessLevel }
            if cleanlinessScore == nil { cleanlinessScore = result.cleanlinessScore }
            if dimensionScores == nil { dimensionScores = result.dimensionScores }
            if mainProblems == nil { mainProblems = result.mainProblems }
        }

        let merged = Self.deduplicateItems(allItems)

        return AIRecognitionResult(
            anchorObject: anchorObject,
            items: merged,
            organizingAdvice: organizingAdvice,
            funnyComment: funnyComment,
            cleanlinessLevel: cleanlinessLevel,
            cleanlinessScore: cleanlinessScore,
            dimensionScores: dimensionScores,
            mainProblems: mainProblems,
            totalItemCount: nil
        )
    }

    /// 多张子图识别（带切片元数据，精确坐标映射）
    func recognizeMultipleImagesWithInfo(
        chips: [ImageProcessingService.ChipInfo],
        gridRows: Int,
        gridCols: Int,
        language: String? = nil,
        referenceItems: [StorageItem]? = nil,
        fullBase64Image: String? = nil
    ) async throws -> AIRecognitionResult {
        guard !chips.isEmpty else {
            throw AIRecognitionError.invalidImage
        }

        if chips.count == 1 {
            return try await recognizeObject(imageData: chips[0].data, language: language, referenceItems: referenceItems, fullBase64Image: fullBase64Image)
        }

        var allItems: [AIItemResult] = []
        var anchorObject: String?
        var organizingAdvice: String?
        var funnyComment: String?
        var cleanlinessLevel: String?
        var cleanlinessScore: Int?
        var dimensionScores: DimensionScores?
        var mainProblems: [String]?
        var totalItemCount: Int?

        for (index, chip) in chips.enumerated() {
            let result = try await recognizeObject(
                imageData: chip.data,
                language: language,
                referenceItems: referenceItems,
                fullBase64Image: fullBase64Image,
                chipInstruction: Self.makeChipInstruction(chip: chip, index: index, total: chips.count)
            )

            let mappedItems = result.items.map { item -> AIItemResult in
                var mapped = item
                if let cx = item.coordX, let cy = item.coordY {
                    let m = ImageProcessingService.mapCoordinate((x: cx, y: cy), chip: chip)
                    mapped = AIItemResult(
                        name: item.name,
                        category: item.category,
                        relativeLocation: item.relativeLocation,
                        description: item.description,
                        attributes: item.attributes,
                        confidence: item.confidence,
                        coordX: m.x,
                        coordY: m.y
                    )
                }
                return mapped
            }
            allItems.append(contentsOf: mappedItems)

            // 评分数据只取第一个结果（整图），后续切片不取评分
            if index == 0 {
                if anchorObject == nil { anchorObject = result.anchorObject }
                if organizingAdvice == nil { organizingAdvice = result.organizingAdvice }
                if funnyComment == nil { funnyComment = result.funnyComment }
                cleanlinessLevel = result.cleanlinessLevel
                cleanlinessScore = result.cleanlinessScore
                dimensionScores = result.dimensionScores
                mainProblems = result.mainProblems
                totalItemCount = result.totalItemCount
            }
        }

        let merged = Self.deduplicateItems(allItems)
        return AIRecognitionResult(
            anchorObject: anchorObject,
            items: merged,
            organizingAdvice: organizingAdvice,
            funnyComment: funnyComment,
            cleanlinessLevel: cleanlinessLevel,
            cleanlinessScore: cleanlinessScore,
            dimensionScores: dimensionScores,
            mainProblems: mainProblems,
            totalItemCount: totalItemCount
        )
    }

    nonisolated static func deduplicateForTesting(_ items: [AIItemResult]) -> [AIItemResult] {
        deduplicateItems(items)
    }

    /// 按坐标、名称/别名、类别综合去重；远距离同名物品保留为多个。
    private nonisolated static func deduplicateItems(_ items: [AIItemResult]) -> [AIItemResult] {
        var merged: [AIItemResult] = []

        for item in items.sorted(by: itemSortKey) {
            if let duplicateIndex = merged.firstIndex(where: { isDuplicate($0, item) }) {
                merged[duplicateIndex] = mergeItems(merged[duplicateIndex], item)
            } else {
                merged.append(item)
            }
        }

        return merged.sorted {
            let ax = $0.coordX ?? 1001
            let bx = $1.coordX ?? 1001
            if abs(ax - bx) > 0.01 { return ax < bx }
            let ay = $0.coordY ?? 1001
            if abs(ay - ($1.coordY ?? 1001)) > 0.01 { return ay < ($1.coordY ?? 1001) }
            return $0.name < $1.name
        }
    }

    /// 归一化名称：去空格、标点、转小写
    private nonisolated static func normalizeName(_ name: String) -> String {
        name.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")
            .replacingOccurrences(of: "·", with: "")
            .replacingOccurrences(of: "（", with: "(")
            .replacingOccurrences(of: "）", with: ")")
    }

    /// 计算两个物品坐标之间的距离
    private nonisolated static func coordinateDistance(_ a: AIItemResult, _ b: AIItemResult) -> Float {
        guard let ax = a.coordX, let ay = a.coordY,
              let bx = b.coordX, let by = b.coordY else {
            return Float.greatestFiniteMagnitude
        }
        let dx = ax - bx
        let dy = ay - by
        return (dx * dx + dy * dy).squareRoot()
    }

    private nonisolated static func itemSortKey(_ a: AIItemResult, _ b: AIItemResult) -> Bool {
        if a.confidence != b.confidence { return a.confidence > b.confidence }
        return a.description.count > b.description.count
    }

    private nonisolated static func isDuplicate(_ a: AIItemResult, _ b: AIItemResult) -> Bool {
        let distance = coordinateDistance(a, b)
        guard distance <= 120 else { return false }

        let aName = normalizeName(a.name)
        let bName = normalizeName(b.name)
        if aName == bName { return true }

        let sameCategory = !a.category.isEmpty && !b.category.isEmpty && normalizeName(a.category) == normalizeName(b.category)
        guard sameCategory else { return false }

        return namesLookEquivalent(a, b) || descriptionsCrossReferenceNames(a, b)
    }

    private nonisolated static func namesLookEquivalent(_ a: AIItemResult, _ b: AIItemResult) -> Bool {
        let aName = normalizeName(a.name)
        let bName = normalizeName(b.name)
        if aName.contains(bName) || bName.contains(aName) { return true }

        let synonymGroups = [
            ["纸巾", "抽纸", "面巾纸", "纸巾盒"],
            ["数据线", "充电线", "线缆", "电源线"],
            ["充电器", "电源适配器", "适配器"],
            ["耳机", "蓝牙耳机", "有线耳机"],
            ["便签", "便利贴", "标签纸"]
        ]
        return synonymGroups.contains { group in
            group.contains { aName.contains($0) } && group.contains { bName.contains($0) }
        }
    }

    private nonisolated static func descriptionsCrossReferenceNames(_ a: AIItemResult, _ b: AIItemResult) -> Bool {
        let aText = normalizeName(a.name + a.description + a.attributes)
        let bText = normalizeName(b.name + b.description + b.attributes)
        let aName = normalizeName(a.name)
        let bName = normalizeName(b.name)
        return aText.contains(bName) || bText.contains(aName)
    }

    private nonisolated static func mergeItems(_ a: AIItemResult, _ b: AIItemResult) -> AIItemResult {
        let primary = qualityScore(b) > qualityScore(a) ? b : a
        let secondary = primary.name == a.name && primary.coordX == a.coordX && primary.coordY == a.coordY ? b : a
        return AIItemResult(
            name: primary.name,
            category: primary.category.isEmpty ? secondary.category : primary.category,
            relativeLocation: primary.relativeLocation.isEmpty ? secondary.relativeLocation : primary.relativeLocation,
            description: primary.description.isEmpty ? secondary.description : primary.description,
            attributes: primary.attributes.isEmpty ? secondary.attributes : primary.attributes,
            confidence: max(a.confidence, b.confidence),
            coordX: primary.coordX ?? secondary.coordX,
            coordY: primary.coordY ?? secondary.coordY
        )
    }

    private nonisolated static func qualityScore(_ item: AIItemResult) -> Float {
        item.confidence * 100 + Float(min(item.description.count + item.attributes.count, 100)) * 0.2
    }

    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let pxW = CGFloat(cgImage.width)
        let pxH = CGFloat(cgImage.height)
        let ratio = min(maxDimension / pxW, maxDimension / pxH, 1.0)
        if ratio >= 1.0 { return image }
        let newSize = CGSize(width: pxW * ratio, height: pxH * ratio)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private func makeCompletionsURL() throws -> URL {
        var normalized = baseURL
        while normalized.hasSuffix("/") {
            normalized.removeLast()
        }

        guard !normalized.isEmpty,
              let url = URL(string: normalized + "/chat/completions") else {
            throw AIRecognitionError.invalidURL
        }
        return url
    }

    private func makeRequestBody(base64Image: String, language: String? = nil, referenceItems: [StorageItem]? = nil, fullBase64Image: String? = nil, chipInstruction: String? = nil) -> [String: Any] {
        let schema: [String: Any] = [
            "name": "storage_recognition",
            "strict": true,
            "schema": [
                "type": "object",
                "properties": [
                    "anchorObject": [
                        "anyOf": [
                            ["type": "string"],
                            ["type": "null"]
                        ]
                    ],
                    "items": [
                        "type": "array",
                        "items": [
                        "type": "object",
                        "properties": [
                            "name": ["type": "string"],
                            "category": ["type": "string"],
                            "relativeLocation": ["type": "string"],
                            "description": ["type": "string"],
                            "attributes": ["type": "string"],
                            "confidence": ["type": "number"],
                            "coordX": ["anyOf": [["type": "number"], ["type": "null"]]],
                            "coordY": ["anyOf": [["type": "number"], ["type": "null"]]]
                        ],
                        "required": ["name", "category", "relativeLocation", "description", "attributes", "confidence", "coordX", "coordY"],
                        "additionalProperties": false
                    ]
                ],
                    "organizingAdvice": [
                        "anyOf": [
                            ["type": "string"],
                            ["type": "null"]
                        ]
                    ],
                    "funnyComment": [
                        "anyOf": [
                            ["type": "string"],
                            ["type": "null"]
                        ]
                    ],
                    "cleanlinessLevel": [
                        "anyOf": [
                            ["type": "string"],
                            ["type": "null"]
                        ]
                    ],
                    "cleanlinessScore": [
                        "anyOf": [
                            ["type": "integer"],
                            ["type": "null"]
                        ]
                    ],
                    "dimensionScores": [
                        "anyOf": [
                            [
                                "type": "object",
                                "properties": [
                                    "categoryPlacement": ["type": "integer"],
                                    "spaceUsage": ["type": "integer"],
                                    "accessibility": ["type": "integer"],
                                    "visualTidiness": ["type": "integer"],
                                    "safetyHygiene": ["type": "integer"]
                                ],
                                "required": ["categoryPlacement", "spaceUsage", "accessibility", "visualTidiness", "safetyHygiene"],
                                "additionalProperties": false
                            ],
                            ["type": "null"]
                        ]
                    ],
                    "mainProblems": [
                        "anyOf": [
                            [
                                "type": "array",
                                "items": ["type": "string"]
                            ],
                            ["type": "null"]
                        ]
                    ],
                    "totalItemCount": [
                        "anyOf": [
                            ["type": "integer"],
                            ["type": "null"]
                        ]
                    ]
                ],
                "required": ["anchorObject", "items", "organizingAdvice", "funnyComment", "cleanlinessLevel", "cleanlinessScore", "dimensionScores", "mainProblems", "totalItemCount"],
                "additionalProperties": false
            ]
        ]

        // 根据语言获取对应语言的完整提示词
        let rawLang = language ?? Locale.current.languageCode ?? "en"
        let lang: String
        switch rawLang {
        case "zh": lang = "zh-Hans"
        case "ja": lang = "ja"
        case "ko": lang = "ko"
        case "es": lang = "es"
        case "fr": lang = "fr"
        case "de": lang = "de"
        default: lang = rawLang
        }
        let langInstruction = Self.languageInstructions[lang] ?? Self.languageInstructions["en"]!
        var fullPrompt = Self.recognitionPrompt + "\n\n" + langInstruction
        
        // 如果有已知物品作为参考，追加到提示词中
        if let refs = referenceItems, !refs.isEmpty {
            // 已验证的物品优先列出
            let verified = refs.filter { $0.isVerified }
            let unverified = refs.filter { !$0.isVerified }
            
            if !verified.isEmpty {
                let vList = verified.map { "\($0.name)（\($0.category)\($0.attributes.isEmpty ? "" : "；\($0.attributes)")）" }.joined(separator: "、")
                fullPrompt += "\n\n\u{2605} 已验证物品（描述和定位准确，优先参考）：\( vList )。这些物品如果在图中仍然可见，请优先使用这些通用名称和属性。"
            }
            if !unverified.isEmpty {
                let uList = unverified.map { "\($0.name)（\($0.category)\($0.attributes.isEmpty ? "" : "；\($0.attributes)")）" }.joined(separator: "、")
                fullPrompt += "\n\n\u{2606} 历史物品（仅供参考）：\( uList )。"
            }
            fullPrompt += "\n\n请结合图片内容重新识别。如果某些物品不再可见，不要列出；如果看到新物品，请正常添加。"
        }

        if let chipInstruction, !chipInstruction.isEmpty {
            fullPrompt += "\n\n\(chipInstruction)"
        }

        // 构建图片内容：整图在前（用于定位），切片在后（用于识别）
        var imageContent: [[String: Any]] = []
        if let fullB64 = fullBase64Image {
            imageContent.append(["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(fullB64)", "detail": "high"]])
        }
        imageContent.append(["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64Image)", "detail": "high"]])

        return [
            "model": model,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": fullPrompt]
                    ] + imageContent
                ]
            ],
            "response_format": [
                "type": "json_schema",
                "json_schema": schema
            ],
            "max_tokens": 12000
        ]
    }

    private static func makeChipInstruction(chip: ImageProcessingService.ChipInfo, index: Int, total: Int) -> String {
        let minX = Int((chip.origin.x / chip.fullSize.width * 1000).rounded())
        let minY = Int((chip.origin.y / chip.fullSize.height * 1000).rounded())
        let maxX = Int(((chip.origin.x + chip.size.width) / chip.fullSize.width * 1000).rounded())
        let maxY = Int(((chip.origin.y + chip.size.height) / chip.fullSize.height * 1000).rounded())
        return """
        【本次切片识别规则】
        当前是第 \(index + 1)/\(total) 张切片。第一张整图只用于判断物品完整形态和全局位置，第二张详细图才是本次要输出的范围。
        只输出中心点落在第二张详细图内的物品；中心点不在当前切片内的物品即使在整图中可见也不要输出。
        coordX/coordY 必须使用第二张详细图上的 0-1000 局部网格坐标，不要输出整图坐标。程序会把局部坐标映射回整图。
        当前切片约覆盖整图坐标 X \(minX)-\(maxX)，Y \(minY)-\(maxY)。如果物品跨越切片边缘，只要中心点在当前切片内就输出一次。
        """
    }

    private func stripCodeFence(from content: String) -> String {
        content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractErrorMessage(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let error = object["error"] as? [String: Any],
           let message = error["message"] as? String,
           !message.isEmpty {
            return message
        }

        if let message = object["message"] as? String,
           !message.isEmpty {
            return message
        }

        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum AIRecognitionError: LocalizedError {
    case invalidImage
    case invalidURL
    case invalidResponse
    case httpError(Int, message: String?)
    case emptyResponse
    case parsingError

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "无法处理图片数据"
        case .invalidURL:
            return "API 地址无效，请检查设置页中的 Base URL"
        case .invalidResponse:
            return "服务器返回了无效响应"
        case .httpError(let statusCode, let message):
            if let message, !message.isEmpty {
                return "请求失败（\(statusCode)）：\(message)"
            }
            return "请求失败，HTTP 状态码：\(statusCode)"
        case .emptyResponse:
            return "AI 没有返回可用内容"
        case .parsingError:
            return "AI 返回内容无法解析为预期 JSON"
        }
    }
}

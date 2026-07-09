//
//  findTests.swift
//  findTests
//
//  Created by 郑云凯 on 2026/4/14.
//

import Testing
import UIKit
@testable import StoreSense

struct findTests {

    @Test func mapCoordinateConvertsChipLocalCoordinatesToFullImageCoordinates() {
        let mapped = ImageProcessingService.mapCoordinate(
            (x: 500, y: 500),
            chipIndex: 3,
            rows: 2,
            cols: 2
        )

        #expect(abs(mapped.x - 750) < 0.01)
        #expect(abs(mapped.y - 750) < 0.01)
    }

    @Test func gridSplitUsesOverlapToAvoidCuttingBoundaryObjects() throws {
        let image = try makeImage(width: 200, height: 100)
        let chips = ImageProcessingService.gridSplitWithInfo(image, rows: 1, cols: 2)

        #expect(chips.count == 2)
        #expect(chips[0].size.width > 100)
        #expect(chips[1].origin.x < 100)
    }

    @Test func recognitionPostProcessorMergesNearbyAliasItemsButKeepsSeparateCopies() {
        let items = [
            AIItemResult(name: "纸巾", category: "生活用品", relativeLocation: "左侧", description: "白色抽纸", confidence: 0.80, coordX: 420, coordY: 500),
            AIItemResult(name: "白色抽纸", category: "生活用品", relativeLocation: "左侧", description: "纸巾盒", confidence: 0.90, coordX: 430, coordY: 505),
            AIItemResult(name: "纸巾", category: "生活用品", relativeLocation: "右侧", description: "另一包纸巾", confidence: 0.85, coordX: 760, coordY: 500)
        ]

        let merged = AIRecognitionService.deduplicateForTesting(items)

        #expect(merged.count == 2)
        #expect(merged.contains { $0.coordX.map { abs($0 - 430) < 1 } ?? false })
        #expect(merged.contains { $0.coordX.map { abs($0 - 760) < 1 } ?? false })
    }

    @Test func recognitionPromptRequiresRecallFirstDenseInventory() {
        let prompt = AIRecognitionService.recognitionPrompt

        #expect(prompt.contains("召回率优先"))
        #expect(prompt.contains("不要在 8 个或 10 个停止"))
        #expect(prompt.contains("3x3"))
    }

    @Test func storageItemDecodesOldDataWithoutAttributes() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "name": "保温杯",
          "category": "杯具",
          "description": "银色杯子",
          "relativeLocation": "左侧",
          "confidence": 0.9,
          "createdAt": 1000,
          "coordX": 500,
          "coordY": 400,
          "isVerified": false
        }
        """

        let item = try JSONDecoder().decode(StorageItem.self, from: Data(json.utf8))

        #expect(item.name == "保温杯")
        #expect(item.attributes.isEmpty)
    }

    @Test func clearRecognizedContentRemovesItemsImagesAndAIRecordsFromLocationOnly() {
        var location = StorageLocation(name: "左侧抽屉", groupName: "书房")
        location.items = [
            StorageItem(name: "保温杯", category: "杯具", relativeLocation: "左侧", description: "", attributes: "品牌:小米", confidence: 0.9)
        ]
        location.backgroundImageData = Data([1, 2, 3])
        location.coverImageData = Data([4, 5, 6])
        location.anchorItemName = "保温杯"
        location.inputType = .imageRecognition
        location.organizingAdvice = "建议"
        location.funnyComment = "评价"
        location.cleanlinessLevel = "整齐"
        location.cleanlinessScore = 90
        location.mainProblems = ["无"]

        location.clearRecognizedContent()

        #expect(location.items.isEmpty)
        #expect(location.backgroundImageData == nil)
        #expect(location.coverImageData == nil)
        #expect(location.anchorItemName == nil)
        #expect(location.inputType == nil)
        #expect(location.organizingAdvice == nil)
        #expect(location.funnyComment == nil)
        #expect(location.cleanlinessLevel == nil)
        #expect(location.cleanlinessScore == nil)
        #expect(location.mainProblems == nil)
    }

    @Test func recognitionSchemaSeparatesItemNameFromAttributes() {
        let prompt = AIRecognitionService.recognitionPrompt

        #expect(prompt.contains("name 只写物品通用叫法"))
        #expect(prompt.contains("attributes"))
        #expect(prompt.contains("品牌:小米"))
    }

    private func makeImage(width: Int, height: Int) throws -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return image
    }
}

import Foundation
import CoreSpotlight
import MobileCoreServices
import UIKit

// 导入StorageModels模块
// 注意：StorageItem和StorageLocation在StorageModels.swift中定义
// 这里假设它们在同一个模块中

class SearchIndexService {
    static let shared = SearchIndexService()
    
    private let domainIdentifier = "zhengyk.StoreSense"
    private let userActivityType = "zhengyk.StoreSense.search"
    
    // 为所有物品建立搜索索引
    func indexAllItems() {
        let storageService = ObjectStorageService()
        let rooms = storageService.fetchAllRooms()
        
        var searchableItems: [CSSearchableItem] = []
        
        for room in rooms {
            for item in room.items {
                let searchableItem = createSearchableItem(for: item, in: room)
                searchableItems.append(searchableItem)
            }
        }
        
        // 删除旧索引并添加新索引
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domainIdentifier]) { error in
            if let error = error {
                print("删除搜索索引失败: \(error)")
            }
            
            CSSearchableIndex.default().indexSearchableItems(searchableItems) { error in
                if let error = error {
                    print("索引物品失败: \(error)")
                } else {
                    print("成功索引 \(searchableItems.count) 个物品")
                }
            }
        }
    }
    
    // 为单个物品创建搜索索引
    func indexItem(_ item: StorageItem, in room: StorageLocation) {
        let searchableItem = createSearchableItem(for: item, in: room)
        
        CSSearchableIndex.default().indexSearchableItems([searchableItem]) { error in
            if let error = error {
                print("索引物品失败: \(error)")
            } else {
                print("成功索引物品: \(item.name)")
            }
        }
    }
    
    // 删除物品的搜索索引
    func removeItemIndex(_ item: StorageItem) {
        let identifier = "\(domainIdentifier).\(item.id.uuidString)"
        
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [identifier]) { error in
            if let error = error {
                print("删除物品索引失败: \(error)")
            }
        }
    }
    
    // 删除房间的所有物品索引
    func removeRoomIndex(_ room: StorageLocation) {
        var identifiers: [String] = []
        
        for item in room.items {
            identifiers.append("\(domainIdentifier).\(item.id.uuidString)")
        }
        
        if !identifiers.isEmpty {
            CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: identifiers) { error in
                if let error = error {
                    print("删除房间索引失败: \(error)")
                }
            }
        }
    }
    
    // 清空所有索引
    func clearAllIndexes() {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domainIdentifier]) { error in
            if let error = error {
                print("清空索引失败: \(error)")
            } else {
                print("已清空所有搜索索引")
            }
        }
    }
    
    // 创建可搜索的物品
    private func createSearchableItem(for item: StorageItem, in room: StorageLocation) -> CSSearchableItem {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .item)
        
        // 基本信息
        attributeSet.title = item.name
        attributeSet.contentDescription = "在「\(room.name)」的\(item.relativeLocation)"
        
        // 添加详细描述
        var fullDescription = "位置：\(room.name)\n相对位置：\(item.relativeLocation)\n分类：\(item.category)"
        if !item.description.isEmpty {
            fullDescription += "\n描述：\(item.description)"
        }
        attributeSet.textContent = fullDescription
        
        // 关键词 - 用于搜索
        var keywords = [item.name, item.category, room.name]
        if !item.description.isEmpty {
            keywords.append(item.description)
        }
        attributeSet.keywords = keywords
        
        // 添加缩略图（如果有）
        if let coverData = room.coverImageData,
           let thumbnail = UIImage(data: coverData)?.resize(to: CGSize(width: 100, height: 100)) {
            attributeSet.thumbnailData = thumbnail.jpegData(compressionQuality: 0.8)
        }
        
        // 添加元数据
        attributeSet.metadataModificationDate = item.createdAt
        attributeSet.domainIdentifier = domainIdentifier
        
        // 创建可搜索项目
        let identifier = "\(domainIdentifier).\(item.id.uuidString)"
        let item = CSSearchableItem(
            uniqueIdentifier: identifier,
            domainIdentifier: domainIdentifier,
            attributeSet: attributeSet
        )
        
        return item
    }
    
    // 创建NSUserActivity用于Siri和Spotlight搜索
    func createUserActivity(for item: StorageItem, in room: StorageLocation) -> NSUserActivity {
        let activity = NSUserActivity(activityType: userActivityType)
        
        activity.title = item.name
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        activity.isEligibleForPublicIndexing = false
        
        // 设置用户信息
        activity.userInfo = ["identifier": "\(domainIdentifier).\(item.id.uuidString)"]
        
        // 设置属性
        let attributeSet = CSSearchableItemAttributeSet(contentType: .item)
        attributeSet.title = item.name
        attributeSet.contentDescription = "在「\(room.name)」的\(item.relativeLocation)"
        
        var fullDescription = "位置：\(room.name)\n相对位置：\(item.relativeLocation)\n分类：\(item.category)"
        if !item.description.isEmpty {
            fullDescription += "\n描述：\(item.description)"
        }
        attributeSet.textContent = fullDescription
        
        // 添加关键词
        var keywords = [item.name, item.category, room.name]
        if !item.description.isEmpty {
            keywords.append(item.description)
        }
        attributeSet.keywords = keywords
        
        // 添加缩略图
        if let coverData = room.coverImageData,
           let thumbnail = UIImage(data: coverData)?.resize(to: CGSize(width: 100, height: 100)) {
            attributeSet.thumbnailData = thumbnail.jpegData(compressionQuality: 0.8)
        }
        
        activity.contentAttributeSet = attributeSet
        
        return activity
    }
    
    // 为物品创建并激活NSUserActivity
    func activateUserActivity(for item: StorageItem, in room: StorageLocation) {
        let activity = createUserActivity(for: item, in: room)
        activity.becomeCurrent()
    }
}

// UIImage扩展用于调整大小
extension UIImage {
    func resize(to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

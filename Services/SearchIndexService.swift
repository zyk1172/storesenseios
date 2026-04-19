import Foundation
import CoreSpotlight
import MobileCoreServices
import UIKit
import NaturalLanguage

// 导入StorageModels模块
// 注意：StorageItem和StorageLocation在StorageModels.swift中定义

class SearchIndexService {
    static let shared = SearchIndexService()
    
    private let domainIdentifier = "zhengyk.StoreSense"
    private let userActivityType = "zhengyk.StoreSense.search"
    
    // 为所有物品建立搜索索引（新增 feedback 回调）
    func indexAllItems(completion: ((Bool) -> Void)? = nil) {
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
            
            if searchableItems.isEmpty {
                completion?(true)
                return
            }
            
            CSSearchableIndex.default().indexSearchableItems(searchableItems) { error in
                if let error = error {
                    print("索引物品失败: \(error)")
                    completion?(false)
                } else {
                    print("成功索引 \(searchableItems.count) 个物品")
                    completion?(true)
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
    func clearAllIndexes(completion: ((Bool) -> Void)? = nil) {
        // 【关键修复2】：连同旧的、错误的 Siri 建议（固定显示的空详情幽灵物品）一起全部抹除！
        NSUserActivity.deleteAllSavedUserActivities {
            CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [self.domainIdentifier]) { error in
                if let error = error {
                    print("清空索引失败: \(error)")
                    completion?(false)
                } else {
                    print("已清空所有搜索索引")
                    completion?(true)
                }
            }
        }
    }
    
    // MARK: - 核心修复：全子串拆分法（N-Gram）
    
    /// 获取物品名称的【所有连续组合】，彻底解决任何字数匹配问题
    private func getAllSubstrings(for text: String) -> [String] {
        var tokens = Set<String>()
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        tokens.insert(cleanText)
        
        // 生成所有可能的连续子串 (长度 1 到 N)
        // 比如 "显示器" -> "显", "示", "器", "显示", "示器", "显示器"
        if cleanText.count <= 30 {
            let chars = Array(cleanText)
            for i in 0..<chars.count {
                for j in i..<chars.count {
                    let sub = String(chars[i...j])
                    if !sub.isEmpty {
                        tokens.insert(sub)
                    }
                }
            }
        } else {
            // 如果名字异常长，回退到自然语言分词，防止内存爆炸
            let tokenizer = NLTokenizer(unit: .word)
            tokenizer.string = cleanText
            tokenizer.enumerateTokens(in: cleanText.startIndex..<cleanText.endIndex) { range, _ in
                tokens.insert(String(cleanText[range]))
                return true
            }
        }
        return Array(tokens)
    }
    
    /// 对分类、位置、描述进行分词，作为次级搜索“关键字”
    private func getKeywords(for item: StorageItem, in room: StorageLocation) -> [String] {
        var keywords = Set<String>()
        keywords.insert(item.category)
        keywords.insert(room.name)
        
        if !item.description.isEmpty {
            let tokenizer = NLTokenizer(unit: .word)
            tokenizer.string = item.description
            tokenizer.enumerateTokens(in: item.description.startIndex..<item.description.endIndex) { range, _ in
                let word = String(item.description[range])
                if word.count > 1 { keywords.insert(word) }
                return true
            }
        }
        return Array(keywords)
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
        
        // 【关键修复1】：将名字拆解出的所有可能子串放入 AlternateNames，打破 4 个字的字数限制
        let nameTokens = getAllSubstrings(for: item.name)
        attributeSet.alternateNames = nameTokens
        
        // 混合其他关键字
        var allKeywords = Set(nameTokens)
        getKeywords(for: item, in: room).forEach { allKeywords.insert($0) }
        attributeSet.keywords = Array(allKeywords)
        
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
        let searchableItem = CSSearchableItem(
            uniqueIdentifier: identifier,
            domainIdentifier: domainIdentifier,
            attributeSet: attributeSet
        )
        
        return searchableItem
    }
    
    // 创建NSUserActivity用于Siri和Spotlight搜索
    func createUserActivity(for item: StorageItem, in room: StorageLocation) -> NSUserActivity {
        let activity = NSUserActivity(activityType: userActivityType)
        
        activity.title = item.name
        // 关闭冗余搜索通道，只保留预测，避免与上面 CoreSpotlight 发生冲突
        activity.isEligibleForSearch = false
        activity.isEligibleForPrediction = true
        activity.isEligibleForPublicIndexing = false
        
        // 设置用户信息
        activity.userInfo = ["identifier": "\(domainIdentifier).\(item.id.uuidString)"]
        
        // 设置属性
        let attributeSet = CSSearchableItemAttributeSet(contentType: .item)
        attributeSet.title = item.name
        attributeSet.contentDescription = "在「\(room.name)」的\(item.relativeLocation)"
        
        // 同样应用所有子串
        let nameTokens = getAllSubstrings(for: item.name)
        attributeSet.alternateNames = nameTokens
        
        var allKeywords = Set(nameTokens)
        getKeywords(for: item, in: room).forEach { allKeywords.insert($0) }
        attributeSet.keywords = Array(allKeywords)
        
        if let coverData = room.coverImageData,
           let thumbnail = UIImage(data: coverData)?.resize(to: CGSize(width: 100, height: 100)) {
            attributeSet.thumbnailData = thumbnail.jpegData(compressionQuality: 0.8)
        }
        
        activity.contentAttributeSet = attributeSet
        
        return activity
    }
    
    // 为物品创建并激活NSUserActivity
    func activateUserActivity(for item: StorageItem, in room: StorageLocation) {
        // 【关键修复2】：这里不再调用 activity.becomeCurrent() ！！！
        // 之前的代码每次保存时在后台静默激活这个，导致系统以为你在高频查看这个物品，
        // 从而将其变成“幽灵推荐”固定在搜索里。现在直接废弃该行为，杜绝污染。
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

//
//  SecurityHelpers.swift
//  StoreSense
//
//  Created by 郑云凯 on 2026/4/21.
//
import Foundation
import Security
import CryptoKit

// MARK: - Keychain 管理器
class KeychainManager {
    static let shared = KeychainManager()
    
    private let service = "com.zhengyk.StoreSense"
    private let account = "openai_api_key"
    
    // 保存 Key 到钥匙串
    func saveKey(_ key: String) {
        let data = Data(key.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        SecItemDelete(query as CFDictionary) // 先删旧的
        
        guard !key.isEmpty else { return }
        
        var newQuery = query
        newQuery[kSecValueData as String] = data
        SecItemAdd(newQuery as CFDictionary, nil)
    }
    
    // 从钥匙串读取 Key
    func loadKey() -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(decoding: data, as: UTF8.self)
        }
        
        return ""
    }
}

// MARK: - 本地备份加密器 (AES-GCM)
struct CryptoHelper {
    // 派生一个固定的 256 位对称密钥，专门用于备份文件的本地加解密
    private static var backupSymmetricKey: SymmetricKey {
        let keyString = "com.zhengyk.StoreSense.LocalBackup.SecureKey.v1"
        let hash = SHA256.hash(data: Data(keyString.utf8))
        return SymmetricKey(data: hash)
    }
    
    // 加密为 Base64 密文
    static func encrypt(_ plainText: String) -> String? {
        guard !plainText.isEmpty, let data = plainText.data(using: .utf8) else { return nil }
        do {
            let sealedBox = try AES.GCM.seal(data, using: backupSymmetricKey)
            return sealedBox.combined?.base64EncodedString()
        } catch {
            print("加密失败: \(error)")
            return nil
        }
    }
    
    // 解密恢复为明文
    static func decrypt(_ encryptedString: String) -> String? {
        guard let data = Data(base64Encoded: encryptedString) else {
            // 如果不是合法的 Base64，说明这可能是旧版本备份中的明文 Key，直接返回
            return encryptedString
        }
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let decryptedData = try AES.GCM.open(sealedBox, using: backupSymmetricKey)
            return String(data: decryptedData, encoding: .utf8)
        } catch {
            // 解密失败（可能是用户自己填写的特殊 Base64 明文），为了兼容性直接返回原字符串
            return encryptedString
        }
    }
}


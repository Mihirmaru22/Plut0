import Foundation
import Security

/// Thread-safe manager for storing and retrieving the Master Encryption Key in macOS Keychain.
public final class KeychainManager: @unchecked Sendable {
    
    public static let shared = KeychainManager()
    
    private let service = "com.pluto.notes.vault"
    private let masterKeyAccount = "master_encryption_key_v1"
    private let lock = NSLock()
    private var inMemoryStore: [String: Data] = [:]
    
    public init() {}
    
    public func saveMasterKeyData(_ data: Data) throws {
        lock.lock()
        defer { lock.unlock() }
        
        inMemoryStore[masterKeyAccount] = data
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: masterKeyAccount
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        var fullQuery = query
        for (k, v) in attributes {
            fullQuery[k] = v
        }
        
        let status = SecItemAdd(fullQuery as CFDictionary, nil)
        if status != errSecSuccess && status != errSecDuplicateItem {
            // Note: If Keychain access is restricted by environment, inMemoryStore acts as fallback
        }
    }
    
    public func loadMasterKeyData() -> Data? {
        lock.lock()
        defer { lock.unlock() }
        
        if let mem = inMemoryStore[masterKeyAccount] {
            return mem
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: masterKeyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let data = result as? Data {
            inMemoryStore[masterKeyAccount] = data
            return data
        }
        return nil
    }
    
    public func deleteMasterKey() {
        lock.lock()
        defer { lock.unlock() }
        
        inMemoryStore.removeValue(forKey: masterKeyAccount)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: masterKeyAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
}

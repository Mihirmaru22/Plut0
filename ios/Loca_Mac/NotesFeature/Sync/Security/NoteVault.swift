import Foundation
import CryptoKit

/// Cryptographic vault managing Master Key generation, HKDF per-note key derivation, and AES-256-GCM encryption.
public final class NoteVault: Sendable {
    
    private let keychain: KeychainManager
    private let masterKeyStore: LockIsolated<SymmetricKey?>
    
    public init(keychain: KeychainManager = .shared) {
        self.keychain = keychain
        if let data = keychain.loadMasterKeyData() {
            self.masterKeyStore = LockIsolated(SymmetricKey(data: data))
        } else {
            let newKey = SymmetricKey(size: .bits256)
            let keyData = newKey.withUnsafeBytes { Data($0) }
            try? keychain.saveMasterKeyData(keyData)
            self.masterKeyStore = LockIsolated(newKey)
        }
    }
    
    public init(masterKey: SymmetricKey) {
        self.keychain = KeychainManager()
        self.masterKeyStore = LockIsolated(masterKey)
    }
    
    // MARK: - Master Key Management
    
    public func getMasterKey() -> SymmetricKey {
        masterKeyStore.withValue { key in
            if let existing = key {
                return existing
            }
            let newKey = SymmetricKey(size: .bits256)
            let keyData = newKey.withUnsafeBytes { Data($0) }
            try? keychain.saveMasterKeyData(keyData)
            key = newKey
            return newKey
        }
    }
    
    public func setMasterKey(_ key: SymmetricKey) throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        try keychain.saveMasterKeyData(keyData)
        masterKeyStore.withValue { $0 = key }
    }
    
    // MARK: - Document Key Derivation (HKDF-SHA256)
    
    public func deriveDocumentKey(for noteID: NoteID) -> SymmetricKey {
        let mk = getMasterKey()
        let info = Data(noteID.raw.uuidString.utf8)
        let salt = Data("PlutoNotesDocumentKeySaltV1".utf8)
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: mk.withUnsafeBytes { Data($0) }),
            salt: salt,
            info: info,
            outputByteCount: 32
        )
    }
    
    // MARK: - AES-256-GCM Encryption & Decryption
    
    public func encrypt(data: Data, for noteID: NoteID) throws -> EncryptedPayload {
        let dk = deriveDocumentKey(for: noteID)
        let sealedBox = try AES.GCM.seal(data, using: dk)
        return EncryptedPayload(sealedBox: sealedBox)
    }
    
    public func decrypt(payload: EncryptedPayload, for noteID: NoteID) throws -> Data {
        let dk = deriveDocumentKey(for: noteID)
        let box = try payload.makeSealedBox()
        return try AES.GCM.open(box, using: dk)
    }
}

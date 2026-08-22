#if canImport(Testing)
import Foundation
import Testing
import CryptoKit

@Suite("Notes Feature - Crypto Vault & E2EE Tests")
struct CryptoVaultTests {
    
    @Test func testAESGCMEncryptionAndEntropy() throws {
        let masterKey = SymmetricKey(size: .bits256)
        let vault = NoteVault(masterKey: masterKey)
        let noteID = NoteID()
        
        let secretText = "Top Secret Strategy Brief: Project Sovereign 2026"
        let secretData = Data(secretText.utf8)
        
        let encryptedPayload = try vault.encrypt(data: secretData, for: noteID)
        
        // 1. Verify encrypted payload does NOT contain any plain text substring
        let cipherString = String(data: encryptedPayload.ciphertext, encoding: .utf8) ?? ""
        #expect(!cipherString.contains("Top Secret"))
        #expect(!cipherString.contains("Project Sovereign"))
        
        // 2. Decrypt and verify identical round-trip
        let decryptedData = try vault.decrypt(payload: encryptedPayload, for: noteID)
        let decryptedText = String(data: decryptedData, encoding: .utf8)
        #expect(decryptedText == secretText)
    }
    
    @Test func testIncorrectKeyFailsDecryption() throws {
        let key1 = SymmetricKey(size: .bits256)
        let key2 = SymmetricKey(size: .bits256)
        
        let vault1 = NoteVault(masterKey: key1)
        let vault2 = NoteVault(masterKey: key2)
        let noteID = NoteID()
        
        let secretData = Data("Classified".utf8)
        let encrypted = try vault1.encrypt(data: secretData, for: noteID)
        
        // Vault2 with different Master Key must fail authentication tag check
        #expect(throws: Error.self) {
            try vault2.decrypt(payload: encrypted, for: noteID)
        }
    }
    
    @Test func testCurve25519DevicePairingProtocol() throws {
        let deviceAMasterKey = SymmetricKey(size: .bits256)
        
        // Step 1: Device B initiates pairing
        let (privateKeyB, offer) = DevicePairingProtocol.initiatePairing()
        
        // Step 2: Device A authorizes and encrypts Master Key with derived pairing secret
        let response = try DevicePairingProtocol.authorizePairing(offer: offer, masterKey: deviceAMasterKey)
        
        // Step 3: Device B finalizes pairing and receives the identical Master Key
        let pairedMasterKey = try DevicePairingProtocol.finalizePairing(
            privateKey: privateKeyB,
            pairingCode: offer.pairingCode,
            response: response
        )
        
        // Verify key equality
        let originalKeyData = deviceAMasterKey.withUnsafeBytes { Data($0) }
        let pairedKeyData = pairedMasterKey.withUnsafeBytes { Data($0) }
        #expect(originalKeyData == pairedKeyData)
        
        // Verify that Device B's vault can now decrypt data encrypted by Device A
        let vaultA = NoteVault(masterKey: deviceAMasterKey)
        let vaultB = NoteVault(masterKey: pairedMasterKey)
        let noteID = NoteID()
        
        let payload = try vaultA.encrypt(data: Data("Shared State".utf8), for: noteID)
        let decrypted = try vaultB.decrypt(payload: payload, for: noteID)
        #expect(String(data: decrypted, encoding: .utf8) == "Shared State")
    }
}
#endif

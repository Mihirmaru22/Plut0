import Foundation
import CryptoKit

/// Curve25519 Diffie-Hellman Key Agreement Protocol enabling zero-knowledge device pairing without exposing keys.
public enum DevicePairingProtocol {
    
    public struct PairingOffer: Codable, Sendable {
        public let ephemeralPublicKeyData: Data
        public let pairingCode: String
        
        public init(publicKey: Curve25519.KeyAgreement.PublicKey, pairingCode: String) {
            self.ephemeralPublicKeyData = publicKey.rawRepresentation
            self.pairingCode = pairingCode
        }
    }
    
    public struct PairingResponse: Codable, Sendable {
        public let ephemeralPublicKeyData: Data
        public let encryptedMasterKeyPayload: EncryptedPayload
        
        public init(publicKey: Curve25519.KeyAgreement.PublicKey, encryptedPayload: EncryptedPayload) {
            self.ephemeralPublicKeyData = publicKey.rawRepresentation
            self.encryptedMasterKeyPayload = encryptedPayload
        }
    }
    
    /// Step 1 (Device A - Initiator): Generates an ephemeral key pair and pairing code.
    public static func initiatePairing() -> (privateKey: Curve25519.KeyAgreement.PrivateKey, offer: PairingOffer) {
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        let randomInt = Int.random(in: 100000...999999)
        let offer = PairingOffer(publicKey: privateKey.publicKey, pairingCode: "\(randomInt)")
        return (privateKey, offer)
    }
    
    /// Step 2 (Device B - Authorizer): Accepts Device A's offer, derives shared secret, and encrypts the Master Key.
    public static func authorizePairing(
        offer: PairingOffer,
        masterKey: SymmetricKey
    ) throws -> PairingResponse {
        let remotePublicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: offer.ephemeralPublicKeyData)
        let localPrivateKey = Curve25519.KeyAgreement.PrivateKey()
        
        let sharedSecret = try localPrivateKey.sharedSecretFromKeyAgreement(with: remotePublicKey)
        let pairingKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data("PlutoNotesDevicePairingSaltV1".utf8),
            sharedInfo: Data(offer.pairingCode.utf8),
            outputByteCount: 32
        )
        
        let masterKeyData = masterKey.withUnsafeBytes { Data($0) }
        let sealedBox = try AES.GCM.seal(masterKeyData, using: pairingKey)
        let payload = EncryptedPayload(sealedBox: sealedBox)
        
        return PairingResponse(publicKey: localPrivateKey.publicKey, encryptedPayload: payload)
    }
    
    /// Step 3 (Device A - Finalizer): Decrypts the Master Key using the shared secret and imports it.
    public static func finalizePairing(
        privateKey: Curve25519.KeyAgreement.PrivateKey,
        pairingCode: String,
        response: PairingResponse
    ) throws -> SymmetricKey {
        let remotePublicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: response.ephemeralPublicKeyData)
        let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: remotePublicKey)
        let pairingKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data("PlutoNotesDevicePairingSaltV1".utf8),
            sharedInfo: Data(pairingCode.utf8),
            outputByteCount: 32
        )
        
        let box = try response.encryptedMasterKeyPayload.makeSealedBox()
        let masterKeyData = try AES.GCM.open(box, using: pairingKey)
        return SymmetricKey(data: masterKeyData)
    }
}

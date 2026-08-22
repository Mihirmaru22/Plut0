import Foundation
import CryptoKit

/// Binary envelope containing an AES-GCM sealed box (Nonce + Ciphertext + Auth Tag).
public struct EncryptedPayload: Hashable, Codable, Sendable {
    public let nonceData: Data
    public let ciphertext: Data
    public let tag: Data
    
    public init(nonceData: Data, ciphertext: Data, tag: Data) {
        self.nonceData = nonceData
        self.ciphertext = ciphertext
        self.tag = tag
    }
    
    public init(sealedBox: AES.GCM.SealedBox) {
        self.nonceData = Data(sealedBox.nonce)
        self.ciphertext = sealedBox.ciphertext
        self.tag = sealedBox.tag
    }
    
    public var combined: Data {
        var data = Data()
        data.append(nonceData)
        data.append(ciphertext)
        data.append(tag)
        return data
    }
    
    public func makeSealedBox() throws -> AES.GCM.SealedBox {
        let nonce = try AES.GCM.Nonce(data: nonceData)
        return try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
    }
}

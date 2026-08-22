import Foundation

/// Wire protocol messages exchanged between the Mac Notes Engine and the Zero-Knowledge Relay Server.
public enum SyncMessage: Codable, Sendable {
    case auth(deviceID: String, token: String)
    case pushDelta(messageID: UUID, noteID: NoteID, encryptedPayload: EncryptedPayload, vectorClock: CRDTVectorClock, deviceID: String)
    case pullDelta(noteID: NoteID, sinceVectorClock: CRDTVectorClock?)
    case broadcastDelta(messageID: UUID, noteID: NoteID, encryptedPayload: EncryptedPayload, vectorClock: CRDTVectorClock, deviceID: String)
    case ack(messageID: UUID, noteID: NoteID)
    case pairRequest(offer: DevicePairingProtocol.PairingOffer)
    case pairResponse(response: DevicePairingProtocol.PairingResponse)
    case ping
    case pong
}

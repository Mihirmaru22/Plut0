import { WebSocketServer, WebSocket } from 'ws';

interface StoredDelta {
  messageId: string;
  noteId: string;
  encryptedPayload: any;
  vectorClock: any;
  deviceId: string;
  receivedAt: number;
}

const PORT = parseInt(process.env.PORT || '8787', 10);
const wss = new WebSocketServer({ port: PORT });

// Active connections indexed by device ID
const clients = new Map<string, WebSocket>();
// Encrypted delta store (Zero-Knowledge)
const deltaStore = new Map<string, StoredDelta[]>();

console.log(`[Pluto Relay Server] Zero-knowledge E2EE sync relay listening on ws://localhost:${PORT}`);

wss.on('connection', (ws: WebSocket) => {
  let authenticatedDeviceId: string | null = null;

  ws.on('message', (rawMessage: Buffer) => {
    try {
      const message = JSON.parse(rawMessage.toString());
      
      // 1. Auth Handshake
      if (message.auth) {
        authenticatedDeviceId = message.auth.deviceID;
        if (authenticatedDeviceId) {
          clients.set(authenticatedDeviceId, ws);
          console.log(`[Auth] Device connected: ${authenticatedDeviceId}`);
        }
        return;
      }

      // 2. Push Delta from Client
      if (message.pushDelta) {
        const { messageID, noteID, encryptedPayload, vectorClock, deviceID } = message.pushDelta;
        const delta: StoredDelta = {
          messageId: messageID,
          noteId: noteID.raw,
          encryptedPayload,
          vectorClock,
          deviceId: deviceID,
          receivedAt: Date.now(),
        };

        // Store encrypted blob
        const existing = deltaStore.get(noteID.raw) || [];
        existing.push(delta);
        deltaStore.set(noteID.raw, existing);

        // Acknowledge receipt to sender immediately (ACK Gating)
        const ackMsg = JSON.stringify({
          ack: {
            messageID,
            noteID,
          }
        });
        ws.send(ackMsg);

        // Broadcast to all other connected devices (Zero Knowledge)
        const broadcastMsg = JSON.stringify({
          broadcastDelta: {
            messageID,
            noteID,
            encryptedPayload,
            vectorClock,
            deviceID,
          }
        });

        for (const [devId, clientSocket] of clients.entries()) {
          if (devId !== deviceID && clientSocket.readyState === WebSocket.OPEN) {
            clientSocket.send(broadcastMsg);
          }
        }
        console.log(`[Relay] Broadcasted encrypted delta for note: ${noteID.raw} from ${deviceID}`);
        return;
      }

      // 3. Pull Deltas
      if (message.pullDelta) {
        const { noteID } = message.pullDelta;
        const deltas = deltaStore.get(noteID.raw) || [];
        for (const delta of deltas) {
          ws.send(JSON.stringify({
            broadcastDelta: {
              messageID: delta.messageId,
              noteID: { raw: delta.noteId },
              encryptedPayload: delta.encryptedPayload,
              vectorClock: delta.vectorClock,
              deviceID: delta.deviceId,
            }
          }));
        }
        return;
      }

      // 4. Device Pairing Handshake Relay
      if (message.pairRequest || message.pairResponse) {
        // Forward pairing messages to all other open clients
        for (const [devId, clientSocket] of clients.entries()) {
          if (clientSocket !== ws && clientSocket.readyState === WebSocket.OPEN) {
            clientSocket.send(rawMessage.toString());
          }
        }
      }

    } catch (err) {
      console.error('[Error] Failed to parse message:', err);
    }
  });

  ws.on('close', () => {
    if (authenticatedDeviceId) {
      clients.delete(authenticatedDeviceId);
      console.log(`[Disconnect] Device disconnected: ${authenticatedDeviceId}`);
    }
  });
});

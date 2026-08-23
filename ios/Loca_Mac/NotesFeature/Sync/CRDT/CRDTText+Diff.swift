import Foundation

extension CRDTText {
    /// Apply a character-level diff against `newText`, preserving existing atom IDs and origins for unchanged characters.
    public mutating func applyDiff(
        to newText: String,
        deviceID: String,
        counter: inout UInt64
    ) {
        let oldText = self.string
        guard oldText != newText else { return }
        
        // Compute character diff
        let diff = Diff.compute(from: oldText, to: newText)
        
        // Apply deletes first (right-to-left to preserve index positions)
        for delete in diff.deletes.reversed() {
            self.delete(at: delete.position, length: delete.length)
        }
        
        // Apply inserts at target positions
        for insert in diff.inserts {
            self.insert(String(insert.character), at: insert.position, deviceID: deviceID, counter: &counter)
        }
    }
    
    /// Apply character-level diff with automatic counter discovery for local device.
    public mutating func applyDiff(
        to newText: String,
        deviceID: String
    ) {
        var localCounter = atoms.filter { $0.id.deviceID == deviceID }.map { $0.id.counter }.max() ?? UInt64(atoms.count)
        applyDiff(to: newText, deviceID: deviceID, counter: &localCounter)
    }
}

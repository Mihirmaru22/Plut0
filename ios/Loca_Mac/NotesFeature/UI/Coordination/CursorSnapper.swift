import Foundation

/// Mathematical hard-snapping calculator for adjusting local cursor selections during remote sync merges with zero animation delay.
public enum CursorSnapper {
    
    /// Calculates the new cursor position after a remote text insertion or deletion.
    public static func snapCursor(
        currentRange: NSRange,
        remoteChangeLocation: Int,
        deltaLength: Int,
        totalNewLength: Int
    ) -> NSRange {
        guard totalNewLength >= 0 else { return NSRange(location: 0, length: 0) }
        
        var newLocation = currentRange.location
        var newLength = currentRange.length
        
        // If remote change happened before or at our cursor position, shift cursor accordingly
        if remoteChangeLocation <= currentRange.location {
            newLocation = max(0, currentRange.location + deltaLength)
        } else if remoteChangeLocation < currentRange.location + currentRange.length {
            // Remote change happened inside our active selection
            newLength = max(0, currentRange.length + deltaLength)
        }
        
        // Clamp to valid document bounds
        let clampedLocation = min(max(0, newLocation), totalNewLength)
        let clampedLength = min(max(0, newLength), totalNewLength - clampedLocation)
        
        return NSRange(location: clampedLocation, length: clampedLength)
    }
}

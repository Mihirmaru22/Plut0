#if canImport(Testing)
import Foundation
import Testing

@Suite("Notes Feature - Cursor Hard Snapping Tests")
struct CursorHardSnapTests {
    
    @Test func testCursorShiftOnPrecedingRemoteInsert() {
        // Local cursor is at position 10
        let currentRange = NSRange(location: 10, length: 0)
        
        // Remote delta inserted 5 characters at position 2 (preceding local cursor)
        let snapped = CursorSnapper.snapCursor(
            currentRange: currentRange,
            remoteChangeLocation: 2,
            deltaLength: 5,
            totalNewLength: 30
        )
        
        // Cursor must hard-snap to 10 + 5 = 15
        #expect(snapped.location == 15)
        #expect(snapped.length == 0)
    }
    
    @Test func testCursorUnchangedOnSucceedingRemoteInsert() {
        // Local cursor is at position 5
        let currentRange = NSRange(location: 5, length: 0)
        
        // Remote delta inserted 10 characters at position 20 (after local cursor)
        let snapped = CursorSnapper.snapCursor(
            currentRange: currentRange,
            remoteChangeLocation: 20,
            deltaLength: 10,
            totalNewLength: 35
        )
        
        // Cursor remains at 5
        #expect(snapped.location == 5)
        #expect(snapped.length == 0)
    }
    
    @Test func testCursorClampedToDocumentBoundsOnLargeDelete() {
        // Local cursor is at position 20
        let currentRange = NSRange(location: 20, length: 0)
        
        // Remote delta deleted 18 characters, leaving document total length at 5
        let snapped = CursorSnapper.snapCursor(
            currentRange: currentRange,
            remoteChangeLocation: 0,
            deltaLength: -18,
            totalNewLength: 5
        )
        
        // Cursor clamped to 5
        #expect(snapped.location == 2)
        #expect(snapped.length == 0)
    }
}
#endif

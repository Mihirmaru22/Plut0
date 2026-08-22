#if canImport(Testing)
import Foundation
import Testing

@Suite("Notes Feature - Autosave Coordinator Debouncing Tests")
struct AutosaveCoordinatorTests {
    
    @Test func testMaterializationDebouncing() async throws {
        let coordinator = AutosaveCoordinator(materializationDebounceInterval: 0.05)
        let noteID = NoteID()
        let executionCount = LockIsolated<Int>(0)
        
        // Rapidly schedule 10 materialization actions
        for _ in 1...10 {
            await coordinator.scheduleMaterialization(for: noteID) {
                executionCount.withValue { $0 += 1 }
            }
        }
        
        // Wait for debounce timer (100ms > 50ms interval)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Exactly 1 execution occurred (debounced)
        #expect(executionCount.value == 1)
    }
    
    @Test func testSyncPushBatching() async throws {
        let coordinator = AutosaveCoordinator(syncBatchInterval: 0.05)
        let noteID = NoteID()
        let pushCount = LockIsolated<Int>(0)
        
        // Rapidly schedule 5 sync pushes
        for _ in 1...5 {
            await coordinator.scheduleSyncPush(for: noteID) {
                pushCount.withValue { $0 += 1 }
            }
        }
        
        // Wait for batch interval
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Exactly 1 batch executed
        #expect(pushCount.value == 1)
    }
}
#endif

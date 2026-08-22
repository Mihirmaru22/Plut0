import Foundation

/// Logical Vector Clock tracking causal order and state versions across distributed devices.
public struct CRDTVectorClock: Hashable, Codable, Sendable, Comparable {
    public private(set) var clock: [String: UInt64]
    
    public init(clock: [String: UInt64] = [:]) {
        self.clock = clock
    }
    
    /// Increments the local clock counter for the given device ID.
    public mutating func increment(for deviceID: String) -> UInt64 {
        let current = clock[deviceID, default: 0]
        let next = current + 1
        clock[deviceID] = next
        return next
    }
    
    /// Merges another vector clock by taking the element-wise maximum.
    public mutating func merge(with other: CRDTVectorClock) {
        for (deviceID, counter) in other.clock {
            let current = clock[deviceID, default: 0]
            clock[deviceID] = max(current, counter)
        }
    }
    
    /// Returns true if this vector clock dominates or equals the other clock.
    public func dominates(_ other: CRDTVectorClock) -> Bool {
        for (deviceID, otherCounter) in other.clock {
            let localCounter = clock[deviceID, default: 0]
            if localCounter < otherCounter {
                return false
            }
        }
        return true
    }
    
    public static func < (lhs: CRDTVectorClock, rhs: CRDTVectorClock) -> Bool {
        // Summary clock comparison based on sum of counters with tie-breaking
        let sumL = lhs.clock.values.reduce(0, +)
        let sumR = rhs.clock.values.reduce(0, +)
        if sumL != sumR {
            return sumL < sumR
        }
        return lhs.clock.description < rhs.clock.description
    }
}

import Foundation

/// Fast LCS-based character diff engine computing granular deletes and inserts for CRDT buffers.
public struct Diff: Sendable {
    
    public struct Delete: Sendable {
        public let position: Int
        public let length: Int
        
        public init(position: Int, length: Int = 1) {
            self.position = position
            self.length = length
        }
    }
    
    public struct Insert: Sendable {
        public let position: Int
        public let character: Character
        
        public init(position: Int, character: Character) {
            self.position = position
            self.character = character
        }
    }
    
    public let deletes: [Delete]
    public let inserts: [Insert]
    
    public init(deletes: [Delete], inserts: [Insert]) {
        self.deletes = deletes
        self.inserts = inserts
    }
    
    public static func compute(from old: String, to new: String) -> Diff {
        let oldChars = Array(old)
        let newChars = Array(new)
        
        if oldChars.isEmpty {
            let inserts = newChars.enumerated().map { Insert(position: $0.offset, character: $0.element) }
            return Diff(deletes: [], inserts: inserts)
        }
        
        if newChars.isEmpty {
            let deletes = (0..<oldChars.count).map { Delete(position: $0, length: 1) }
            return Diff(deletes: deletes, inserts: [])
        }
        
        let lcs = longestCommonSubsequence(oldChars, newChars)
        
        var deletes: [Delete] = []
        var inserts: [Insert] = []
        
        var oldIdx = 0
        var newIdx = 0
        var lcsIdx = 0
        
        while oldIdx < oldChars.count || newIdx < newChars.count {
            if lcsIdx < lcs.count && oldIdx < oldChars.count && oldChars[oldIdx] == lcs[lcsIdx] && newIdx < newChars.count && newChars[newIdx] == lcs[lcsIdx] {
                // Match - advance both
                oldIdx += 1
                newIdx += 1
                lcsIdx += 1
            } else if oldIdx < oldChars.count && (lcsIdx >= lcs.count || oldChars[oldIdx] != lcs[lcsIdx]) {
                // Delete from old
                deletes.append(Delete(position: oldIdx, length: 1))
                oldIdx += 1
            } else if newIdx < newChars.count && (lcsIdx >= lcs.count || newChars[newIdx] != lcs[lcsIdx]) {
                // Insert from new
                inserts.append(Insert(position: newIdx, character: newChars[newIdx]))
                newIdx += 1
            }
        }
        
        return Diff(deletes: deletes, inserts: inserts)
    }
    
    private static func longestCommonSubsequence(_ a: [Character], _ b: [Character]) -> [Character] {
        let m = a.count
        let n = b.count
        guard m > 0 && n > 0 else { return [] }
        
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 1...m {
            for j in 1...n {
                if a[i-1] == b[j-1] {
                    dp[i][j] = dp[i-1][j-1] + 1
                } else {
                    dp[i][j] = max(dp[i-1][j], dp[i][j-1])
                }
            }
        }
        
        var lcs: [Character] = []
        var i = m
        var j = n
        while i > 0 && j > 0 {
            if a[i-1] == b[j-1] {
                lcs.append(a[i-1])
                i -= 1
                j -= 1
            } else if dp[i-1][j] >= dp[i][j-1] {
                i -= 1
            } else {
                j -= 1
            }
        }
        
        return lcs.reversed()
    }
}

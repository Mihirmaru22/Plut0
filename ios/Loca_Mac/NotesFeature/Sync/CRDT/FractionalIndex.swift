import Foundation

/// Mathematical arbitrary-precision fractional index generator for deterministic CRDT block ordering.
public enum FractionalIndex {
    
    private static let alphabet = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
    private static let charToValue: [Character: Int] = {
        var map = [Character: Int]()
        for (index, char) in alphabet.enumerated() {
            map[char] = index
        }
        return map
    }()
    
    public static let initial: String = "a0"
    
    /// Generates a fractional index string strictly between `lower` and `upper` (lower < result < upper).
    public static func between(_ lower: String?, _ upper: String?) -> String {
        // Case 1: First item in empty list
        guard let low = lower else {
            if let up = upper {
                return decrement(up)
            }
            return initial
        }
        
        // Case 2: Append at end
        guard let up = upper else {
            return increment(low)
        }
        
        // Case 3: Insert between low and up
        if low >= up {
            // Safety fallback: if inputs are out of order, append mid-char to lower
            return low + "V"
        }
        
        let lowChars = Array(low)
        let upChars = Array(up)
        var result = ""
        var index = 0
        
        while true {
            let lowVal = index < lowChars.count ? (charToValue[lowChars[index]] ?? 0) : 0
            let upVal = index < upChars.count ? (charToValue[upChars[index]] ?? alphabet.count) : alphabet.count
            
            if lowVal == upVal {
                result.append(lowChars[index])
                index += 1
                continue
            }
            
            let diff = upVal - lowVal
            if diff > 1 {
                let midVal = lowVal + diff / 2
                result.append(alphabet[midVal])
                return result
            } else {
                // Adjacent characters: append lower char and continue to next position
                if index < lowChars.count {
                    result.append(lowChars[index])
                } else {
                    result.append(alphabet[0])
                }
                index += 1
                
                // Add midpoint on next character
                let nextLow = index < lowChars.count ? (charToValue[lowChars[index]] ?? 0) : 0
                let nextMid = (nextLow + alphabet.count) / 2
                let chosenVal = max(nextMid, nextLow + 1) % alphabet.count
                result.append(alphabet[chosenVal])
                return result
            }
        }
    }
    
    public static func increment(_ string: String) -> String {
        var chars = Array(string)
        var i = chars.count - 1
        
        while i >= 0 {
            let val = charToValue[chars[i]] ?? 0
            if val + 1 < alphabet.count {
                chars[i] = alphabet[val + 1]
                return String(chars)
            }
            chars[i] = alphabet[0]
            i -= 1
        }
        return "a" + String(chars)
    }
    
    public static func decrement(_ string: String) -> String {
        var chars = Array(string)
        var i = chars.count - 1
        
        while i >= 0 {
            let val = charToValue[chars[i]] ?? 0
            if val > 0 {
                chars[i] = alphabet[val - 1]
                return String(chars)
            }
            chars[i] = alphabet[alphabet.count - 1]
            i -= 1
        }
        return String(chars) + "V"
    }
}

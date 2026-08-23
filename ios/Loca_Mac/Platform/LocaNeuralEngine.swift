import Foundation
import NaturalLanguage
import SwiftUI

// MARK: - LocaNeuralEngine (Apple Silicon & ANE On-Device Intelligence)

/// Local-First Apple Neural Engine & NaturalLanguage Processing Engine.
/// Provides zero-latency, 100% private, on-device semantic analysis,
/// journal sentiment calibration, keyword extraction, and intelligent task parsing.
enum LocaNeuralEngine {

    // MARK: - 1. On-Device Journal Sentiment & Semantic Tone Analyzer

    struct JournalToneReport {
        let averageSentiment: Double      // -1.0 (Low Energy/Reflective) to +1.0 (High Clarity/Optimism)
        let toneLabel: String             // e.g. "High Clarity & Optimism", "Balanced & Focused", "Reflective Calm"
        let toneIcon: String
        let toneColor: Color
        let topKeywords: [String]         // Extracted semantic key concepts (nouns/verbs)
        let totalEntriesAnalyzed: Int
        let correlationInsight: String    // Correlation between journal state & execution
    }

    /// Analyzes an array of JournalNote objects using Apple's Neural Engine sentiment models.
    static func analyzeJournalNotes(_ notes: [JournalNote], habitCompletionRate: Double = 0.0) -> JournalToneReport {
        let activeNotes = notes.filter { !$0.isArchived && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !activeNotes.isEmpty else {
            return JournalToneReport(
                averageSentiment: 0.0,
                toneLabel: "No Journal Logs Yet",
                toneIcon: "pencil.line",
                toneColor: DS.Color.textSecondary,
                topKeywords: [],
                totalEntriesAnalyzed: 0,
                correlationInsight: "Log daily reflections to unlock on-device Neural Engine sentiment and habit correlation insights."
            )
        }

        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        var sentimentSum: Double = 0.0
        var allText = ""

        for note in activeNotes {
            allText += " " + note.text
            tagger.string = note.text
            let (sentimentTag, _) = tagger.tag(at: note.text.startIndex, unit: .paragraph, scheme: .sentimentScore)
            if let scoreStr = sentimentTag?.rawValue, let score = Double(scoreStr) {
                sentimentSum += score
            }
        }

        let avgSentiment = (sentimentSum / Double(activeNotes.count)).clamped(to: -1.0...1.0)
        let keywords = extractTopKeywords(from: allText, maxCount: 5)

        // Determine Tone Category
        let toneLabel: String
        let toneIcon: String
        let toneColor: Color

        if avgSentiment >= 0.35 {
            toneLabel = "High Clarity & Optimism"
            toneIcon = "sparkles"
            toneColor = DS.Color.success
        } else if avgSentiment >= 0.05 {
            toneLabel = "Steady & Focused Drive"
            toneIcon = "bolt.fill"
            toneColor = Color(red: 0.20, green: 0.65, blue: 0.95)
        } else if avgSentiment >= -0.25 {
            toneLabel = "Calm & Reflective Equilibrium"
            toneIcon = "leaf.fill"
            toneColor = Color(red: 0.68, green: 0.45, blue: 0.98)
        } else {
            toneLabel = "Deep Introspection & Calibration"
            toneIcon = "moon.stars.fill"
            toneColor = Color(red: 0.95, green: 0.68, blue: 0.22)
        }

        // Compute Correlation with Habit Execution
        let correlation: String
        if habitCompletionRate >= 0.8 && avgSentiment >= 0.2 {
            correlation = "High habit execution strongly correlates with elevated mental clarity and forward momentum."
        } else if habitCompletionRate >= 0.8 && avgSentiment < 0.2 {
            correlation = "Strong physical and habit discipline maintained even during reflective, introspective cycles."
        } else if habitCompletionRate < 0.5 && avgSentiment < 0.0 {
            correlation = "Rest and mental calibration detected. Focus on 1–2 core baseline habits to rebuild momentum."
        } else {
            correlation = "Steady baseline compounding. Daily journal logs reflect balanced cognitive state."
        }

        return JournalToneReport(
            averageSentiment: avgSentiment,
            toneLabel: toneLabel,
            toneIcon: toneIcon,
            toneColor: toneColor,
            topKeywords: keywords,
            totalEntriesAnalyzed: activeNotes.count,
            correlationInsight: correlation
        )
    }

    /// Single note on-device sentiment tagger.
    static func analyzeSingleNoteText(_ text: String) -> Double {
        guard !text.isEmpty else { return 0.0 }
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        let (sentimentTag, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
        if let scoreStr = sentimentTag?.rawValue, let score = Double(scoreStr) {
            return score.clamped(to: -1.0...1.0)
        }
        return 0.0
    }

    /// On-device keyword & entity extraction using Apple's NLTagger nameTypeOrLexicalClass.
    static func extractTopKeywords(from text: String, maxCount: Int = 5) -> [String] {
        guard !text.isEmpty else { return [] }
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
        tagger.string = text

        var wordFrequencies: [String: Int] = [:]
        let stopWords: Set<String> = ["the", "and", "with", "that", "this", "from", "have", "were", "been", "will", "today", "yesterday", "time", "done", "make", "just", "into", "some", "more", "very", "also"]

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitPunctuation, .omitWhitespace, .omitOther]) { tag, tokenRange in
            if let tag = tag, (tag == .noun || tag == .verb || tag == .adjective) {
                let rawWord = String(text[tokenRange]).lowercased()
                if rawWord.count >= 4 && !stopWords.contains(rawWord) {
                    wordFrequencies[rawWord, default: 0] += 1
                }
            }
            return true
        }

        let sortedWords = wordFrequencies.sorted { $0.value > $1.value }
        return Array(sortedWords.prefix(maxCount).map { $0.key.capitalized })
    }

    // MARK: - 2. Smart Task NLP with Apple NSDataDetector & Linguistic Entity Recognition

    struct SmartTaskResult {
        var cleanTitle: String
        var dueDate: Date?
        var startTime: Date?
        var durationMinutes: Int
        var priority: Int
        var detectedTags: [String]
    }

    /// Enhanced Natural Language Task Parser leveraging Apple's NSDataDetector & regex patterns.
    static func parseSmartTask(_ rawInput: String) -> SmartTaskResult {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return SmartTaskResult(cleanTitle: rawInput, dueDate: nil, startTime: nil, durationMinutes: 0, priority: 0, detectedTags: [])
        }

        var text = trimmed
        var detectedDueDate: Date? = nil
        var detectedStartTime: Date? = nil
        var detectedDuration: Int = 0
        var detectedPriority: Int = 0
        var detectedTags: [String] = []

        // 1. Detect Priority (standalone "!", "!!", "!!!", or "#p1", "#p2", "#p3")
        let words = text.components(separatedBy: .whitespaces)
        var wordsToKeep: [String] = []

        for w in words {
            if w == "!" || w.lowercased() == "#p1" || w.lowercased() == "p1" {
                detectedPriority = 1
            } else if w == "!!" || w.lowercased() == "#p2" || w.lowercased() == "p2" {
                detectedPriority = 2
            } else if w == "!!!" || w.lowercased() == "#p3" || w.lowercased() == "p3" {
                detectedPriority = 3
            } else if w.hasPrefix("#") && w.count > 1 {
                detectedTags.append(String(w.dropFirst()))
            } else {
                wordsToKeep.append(w)
            }
        }
        text = wordsToKeep.joined(separator: " ")

        // 2. Detect Duration ("30m", "45min", "1h", "1.5h", "0.5hr", "90min", "2hr", "for 45m")
        if let durationRange = text.range(of: #"(?:for\s+)?(\d+(?:\.\d+)?)\s*(m|min|mins|minutes|h|hr|hrs|hours)\b"#, options: [.regularExpression, .caseInsensitive]) {
            let matched = String(text[durationRange])
            if let mins = parseDurationString(matched) {
                detectedDuration = mins
                text.removeSubrange(durationRange)
            }
        }

        // Normalize compound prepositions before Date recognition
        text = normalizePrepositions(text)

        // 3. Apple NSDataDetector for Date & Time Recognition
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
            let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: (text as NSString).length))
            if let firstMatch = matches.first, let detectedDate = firstMatch.date {
                let cal = Calendar.current
                detectedDueDate = cal.startOfDay(for: detectedDate)

                // Check if time components were present in match with strict word boundaries and digit validation
                let matchedSubstring = (text as NSString).substring(with: firstMatch.range)
                let timePattern = #"(?i)(?:\b\d{1,2}(?::\d{2})?\s*(?:am|pm)\b|\b\d{1,2}:\d{2}\b|\bat\s+\d{1,2}(?::\d{2})?\b|\b(?:noon|midnight|tonight)\b)"#
                let hasExplicitTime = firstMatch.timeZone != nil || matchedSubstring.range(of: timePattern, options: .regularExpression) != nil

                if hasExplicitTime {
                    detectedStartTime = detectedDate
                }

                if let swiftRange = Range(firstMatch.range, in: text) {
                    text.removeSubrange(swiftRange)
                }
            }
        }

        // 4. Clean and normalize remaining title
        var cleanTitle = text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip trailing punctuation
        cleanTitle = cleanTitle.replacingOccurrences(
            of: #"[!?.,;:]+$"#,
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip leading/trailing prepositions
        for prep in [" at", " on", " for", " by", " in", " the"] {
            if cleanTitle.hasSuffix(prep) {
                cleanTitle = String(cleanTitle.dropLast(prep.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let trimmedPrep = prep.trimmingCharacters(in: .whitespaces)
            if cleanTitle.lowercased().hasPrefix(trimmedPrep + " ") {
                cleanTitle = String(cleanTitle.dropFirst(trimmedPrep.count + 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        cleanTitle = cleanTitle.replacingOccurrences(
            of: #"[!?.,;:]+$"#,
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        if cleanTitle.isEmpty { cleanTitle = trimmed }

        return SmartTaskResult(
            cleanTitle: cleanTitle,
            dueDate: detectedDueDate,
            startTime: detectedStartTime,
            durationMinutes: detectedDuration,
            priority: detectedPriority,
            detectedTags: detectedTags
        )
    }

    private static func normalizePrepositions(_ text: String) -> String {
        var result = text

        // "on next Tuesday" -> "next Tuesday"
        result = result.replacingOccurrences(
            of: #"\bon\s+(next|this|last)\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b"#,
            with: "$1 $2",
            options: [.regularExpression, .caseInsensitive]
        )

        // "by tomorrow morning" -> "tomorrow morning"
        result = result.replacingOccurrences(
            of: #"\bby\s+(today|tomorrow|tonight)\b"#,
            with: "$1",
            options: [.regularExpression, .caseInsensitive]
        )

        // "on tomorrow" -> "tomorrow"
        result = result.replacingOccurrences(
            of: #"\bon\s+(today|tomorrow|tonight)\b"#,
            with: "$1",
            options: [.regularExpression, .caseInsensitive]
        )

        return result
    }

    private static func parseDurationString(_ raw: String) -> Int? {
        let s = raw.lowercased()
            .replacingOccurrences(of: "for ", with: "")
            .trimmingCharacters(in: .whitespaces)

        for suffix in ["hours", "hour", "hrs", "hr", "h"] {
            if s.hasSuffix(suffix) {
                let n = String(s.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
                if let d = Double(n), d > 0 { return Int((d * 60).rounded()) }
            }
        }
        for suffix in ["minutes", "minute", "mins", "min", "m"] {
            if s.hasSuffix(suffix) {
                let n = String(s.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
                if let d = Double(n), d > 0 { return Int(d.rounded()) }
            }
        }
        return nil
    }

    // MARK: - 3. Apple Intelligence Writing Tools: 3-Bullet Executive Summarizer

    struct ExecutiveBrief {
        let periodLabel: String
        let bulletPoints: [ExecutiveBullet]
        let sentimentScore: Double
        let totalEntriesCount: Int
    }

    struct ExecutiveBullet: Identifiable {
        let id = UUID()
        let category: String
        let icon: String
        let color: Color
        let text: String
    }

    static func generateExecutiveSummary(notes: [JournalNote], periodLabel: String = "Past 7 Days") -> ExecutiveBrief {
        let active = notes.filter { !$0.isArchived && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !active.isEmpty else {
            return ExecutiveBrief(
                periodLabel: periodLabel,
                bulletPoints: [
                    ExecutiveBullet(category: "Momentum", icon: "sparkles", color: DS.Color.streak, text: "No journal reflections logged yet for this period. Capture daily wins to unlock Apple Intelligence summaries."),
                    ExecutiveBullet(category: "Focus", icon: "bolt.fill", color: DS.Color.active, text: "Maintain steady habit execution to establish baseline momentum."),
                    ExecutiveBullet(category: "Reflection", icon: "moon.fill", color: DS.Color.textSecondary, text: "Evening reflections help calibrate energy and eliminate cognitive friction.")
                ],
                sentimentScore: 0.0,
                totalEntriesCount: 0
            )
        }

        // 1. Separate wins/moments
        let winNotes = active.filter { $0.noteKind == JournalNote.NoteKind.win }

        var bullets: [ExecutiveBullet] = []

        // Bullet 1: Wins & Primary Momentum
        if !winNotes.isEmpty {
            let winSnippets = winNotes.compactMap { sanitizeSnippet($0.text) }.filter { !$0.isEmpty }
            let summaryText = winSnippets.prefix(2).joined(separator: "; ")
            let detailPart = summaryText.isEmpty ? "" : " — \(summaryText)"
            bullets.append(ExecutiveBullet(
                category: "Momentum & Key Wins",
                icon: "sparkles",
                color: DS.Color.streak,
                text: "Celebrated \(winNotes.count) core win\(winNotes.count == 1 ? "" : "s")\(detailPart)."
            ))
        } else {
            let cleanSnippet = sanitizeSnippet(active.first?.text ?? "")
            let detailPart = cleanSnippet.isEmpty ? "" : " — \(cleanSnippet)"
            bullets.append(ExecutiveBullet(
                category: "Momentum",
                icon: "sparkles",
                color: DS.Color.streak,
                text: "Steady progression across active habits\(detailPart)."
            ))
        }

        // Bullet 2: Cognitive Focus & Dominant Themes
        let allText = active.map(\.text).joined(separator: " ")
        let keywords = extractTopKeywords(from: allText, maxCount: 4)
        let themeText = keywords.isEmpty ? "High focus and structured daily workflows" : "Primary focus centered around \(keywords.joined(separator: ", "))"
        bullets.append(ExecutiveBullet(
            category: "Cognitive Focus & Flow",
            icon: "bolt.fill",
            color: DS.Color.active,
            text: "\(themeText) with dedicated deep work execution."
        ))

        // Bullet 3: Reflection & Forward Calibration
        let avgSentiment = analyzeJournalNotes(active).averageSentiment
        let calText: String
        if avgSentiment >= 0.2 {
            calText = "Mental clarity and forward velocity remain high. Continue compounding on primary objectives."
        } else if avgSentiment >= -0.1 {
            calText = "Balanced equilibrium observed. Protect rest intervals between high-intensity sprints."
        } else {
            calText = "Introspective cycle detected. Recommend prioritizing sleep recovery and trimming non-essential tasks."
        }
        bullets.append(ExecutiveBullet(
            category: "Reflection & Calibration",
            icon: "leaf.fill",
            color: Color(red: 0.68, green: 0.45, blue: 0.98),
            text: calText
        ))

        return ExecutiveBrief(
            periodLabel: periodLabel,
            bulletPoints: bullets,
            sentimentScore: avgSentiment,
            totalEntriesCount: active.count
        )
    }

    private static func sanitizeSnippet(_ text: String, maxLength: Int = 120) -> String {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard var clean = lines.first else { return "" }

        let prefixes = ["• ", "○ ", "● ", "☐ ", "☑ ", "“ ", "> ", "- ", "* "]
        for p in prefixes {
            if clean.hasPrefix(p) {
                clean.removeFirst(p.count)
                break
            }
        }

        if let regex = try? NSRegularExpression(pattern: "^[0-9]+\\.\\s*"),
           let match = regex.firstMatch(in: clean, range: NSRange(location: 0, length: clean.utf16.count)) {
            clean = (clean as NSString).substring(from: match.range.length)
        }

        clean = clean.replacingOccurrences(of: "\\", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if clean.count > maxLength {
            clean = String(clean.prefix(maxLength)).trimmingCharacters(in: .whitespaces) + "…"
        }

        return clean
    }
}

// MARK: - Double Clamping Helper

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}

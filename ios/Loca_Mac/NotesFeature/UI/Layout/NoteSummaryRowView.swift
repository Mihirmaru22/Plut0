import SwiftUI

/// Note list item displaying summary metadata, title, preview snippet, date, and pin badge.
public struct NoteSummaryRowView: View {
    
    public let summary: NoteSummary
    public let isSelected: Bool
    
    public init(summary: NoteSummary, isSelected: Bool = false) {
        self.summary = summary
        self.isSelected = isSelected
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                if summary.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.orange)
                }
                
                Text(summary.title.isEmpty ? "New Note" : summary.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(summary.title.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
                
                Spacer()
                
                Text(formatDate(summary.updatedAt))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            
            if !summary.preview.isEmpty {
                Text(summary.preview)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
    
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}

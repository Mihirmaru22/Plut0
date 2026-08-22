import SwiftUI

/// Stateful rich-text formatting bar for inline styling and block conversion with visual ON states.
public struct NotesFormattingToolbar: View {
    
    public let state: FormattingState
    public let onToggleBold: () -> Void
    public let onToggleItalic: () -> Void
    public let onToggleBlockType: (EditorBlockType) -> Void
    
    public init(
        state: FormattingState,
        onToggleBold: @escaping () -> Void,
        onToggleItalic: @escaping () -> Void,
        onToggleBlockType: @escaping (EditorBlockType) -> Void
    ) {
        self.state = state
        self.onToggleBold = onToggleBold
        self.onToggleItalic = onToggleItalic
        self.onToggleBlockType = onToggleBlockType
    }
    
    public var body: some View {
        HStack(spacing: 3) {
            // Inline marks group (Combine with each other and with any block type)
            toolbarButton(
                title: "B",
                icon: nil,
                isActive: state.isBold,
                help: "Bold (⌘B)",
                isBoldFont: true,
                action: {
                    DispatchQueue.main.async {
                        onToggleBold()
                    }
                }
            )
            
            toolbarButton(
                title: "I",
                icon: nil,
                isActive: state.isItalic,
                help: "Italic (⌘I)",
                isItalicFont: true,
                action: {
                    DispatchQueue.main.async {
                        onToggleItalic()
                    }
                }
            )
            
            Divider()
                .frame(height: 14)
                .padding(.horizontal, 2)
            
            // Exclusive Headings Group
            toolbarButton(
                title: "H1",
                icon: nil,
                isActive: state.blockType == .h1,
                help: "Heading 1",
                action: {
                    DispatchQueue.main.async {
                        onToggleBlockType(.h1)
                    }
                }
            )
            
            toolbarButton(
                title: "H2",
                icon: nil,
                isActive: state.blockType == .h2,
                help: "Heading 2",
                action: {
                    DispatchQueue.main.async {
                        onToggleBlockType(.h2)
                    }
                }
            )
            
            toolbarButton(
                title: "H3",
                icon: nil,
                isActive: state.blockType == .h3,
                help: "Heading 3",
                action: {
                    DispatchQueue.main.async {
                        onToggleBlockType(.h3)
                    }
                }
            )
            
            Divider()
                .frame(height: 14)
                .padding(.horizontal, 2)
            
            // Lists & Paragraph Group
            toolbarButton(
                title: nil,
                icon: "checklist",
                isActive: state.blockType == .checklist,
                help: "Checklist",
                action: {
                    DispatchQueue.main.async {
                        onToggleBlockType(.checklist)
                    }
                }
            )
            
            toolbarButton(
                title: nil,
                icon: "list.bullet",
                isActive: state.blockType == .bullet,
                help: "Bullet List",
                action: {
                    DispatchQueue.main.async {
                        onToggleBlockType(.bullet)
                    }
                }
            )
            
            toolbarButton(
                title: nil,
                icon: "paragraph",
                isActive: state.blockType == .paragraph,
                help: "Normal Paragraph",
                action: {
                    DispatchQueue.main.async {
                        onToggleBlockType(.paragraph)
                    }
                }
            )
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 1)
    }
    
    private func toolbarButton(
        title: String?,
        icon: String?,
        isActive: Bool,
        help: String,
        isBoldFont: Bool = false,
        isItalicFont: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                if isActive {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.accentColor.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(Color.accentColor.opacity(0.4), lineWidth: 0.8)
                        )
                }
                
                Group {
                    if let title = title {
                        Text(title)
                            .font(.system(size: 11, weight: isBoldFont ? .heavy : .semibold))
                            .italic(isItalicFont)
                    } else if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .foregroundColor(isActive ? .accentColor : .primary.opacity(0.85))
            }
            .frame(width: 26, height: 22)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
        .accessibilityValue(isActive ? "Selected" : "Not selected")
    }
}

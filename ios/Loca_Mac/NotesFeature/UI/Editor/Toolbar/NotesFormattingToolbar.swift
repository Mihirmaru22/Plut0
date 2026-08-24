import SwiftUI

/// Stateful rich-text formatting bar for inline styling and block conversion with visual ON states.
public struct NotesFormattingToolbar: View {
    
    public let state: FormattingState
    public let onToggleBold: () -> Void
    public let onToggleItalic: () -> Void
    public let onToggleBlockType: (EditorBlockType) -> Void
    public var onAISummary: (() -> Void)? = nil
    
    public init(
        state: FormattingState,
        onToggleBold: @escaping () -> Void,
        onToggleItalic: @escaping () -> Void,
        onToggleBlockType: @escaping (EditorBlockType) -> Void,
        onAISummary: (() -> Void)? = nil
    ) {
        self.state = state
        self.onToggleBold = onToggleBold
        self.onToggleItalic = onToggleItalic
        self.onToggleBlockType = onToggleBlockType
        self.onAISummary = onAISummary
    }
    
    public var body: some View {
        PlutoGlassCluster(spacing: 3) {
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
                .opacity(0.2)
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
                .opacity(0.2)
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
            
            // Optional AI Summary button
            if let onAISummary = onAISummary {
                Divider()
                    .frame(height: 14)
                    .opacity(0.2)
                    .padding(.horizontal, 2)
                
                Button(action: onAISummary) {
                    HStack(spacing: 3) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10.5, weight: .bold))
                        Text("AI")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                    }
                }
                .buttonStyle(
                    PlutoGlassButtonStyle(
                        shape: RoundedRectangle(cornerRadius: 6, style: .continuous),
                        tint: DS.Theme.amber,
                        isProminent: false
                    )
                )
                .help("AI Note Synthesis (⌘J)")
            }
        }
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
            .frame(width: 14, height: 14)
        }
        .buttonStyle(
            PlutoGlassButtonStyle(
                shape: RoundedRectangle(cornerRadius: 6, style: .continuous),
                tint: isActive ? Color.accentColor : nil,
                isProminent: isActive
            )
        )
        .help(help)
        .accessibilityLabel(help)
        .accessibilityValue(isActive ? "Selected" : "Not selected")
    }
}


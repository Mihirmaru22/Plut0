import SwiftUI

/// Compact typography formatting popover matching Apple Journal's sensory design.
/// Provides live active pill highlights and tactile formatting triggers for B, I, Lists, and Headings.
public struct PlutoTypographyPopover: View {
    
    @ObservedObject public var state: EditorBridgeState
    
    public init(state: EditorBridgeState) {
        self.state = state
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // Row 1: Inline Styles (B, I, U, S)
            HStack(spacing: 3) {
                formatBtn("B", isActive: state.formattingState.isBold) {
                    state.toggleBold()
                    Haptics.impact(.light)
                }
                formatBtn("I", isActive: state.formattingState.isItalic) {
                    state.toggleItalic()
                    Haptics.impact(.light)
                }
                formatBtn("U", isActive: state.formattingState.isUnderline) {
                    let sel = state.bridge.lastKnownSelection
                    state.bridge.toggleInlineMark(type: "underline", in: sel)
                    state.requestFormatRefresh()
                    Haptics.impact(.light)
                }
                formatBtn("S", isActive: state.formattingState.isStrikethrough) {
                    let sel = state.bridge.lastKnownSelection
                    state.bridge.toggleInlineMark(type: "strikethrough", in: sel)
                    state.requestFormatRefresh()
                    Haptics.impact(.light)
                }
            }
            .padding(2)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
            
            // Row 2: Block Styles (Headings & Lists)
            HStack(spacing: 3) {
                formatBlockBtn("H1", isActive: state.formattingState.blockType == .h1) {
                    state.toggleBlockType(.h1)
                    Haptics.impact(.light)
                }
                formatBlockBtn("H2", isActive: state.formattingState.blockType == .h2) {
                    state.toggleBlockType(.h2)
                    Haptics.impact(.light)
                }
                formatBlockBtn("H3", isActive: state.formattingState.blockType == .h3) {
                    state.toggleBlockType(.h3)
                    Haptics.impact(.light)
                }
                formatIconBtn("checklist", isActive: state.formattingState.blockType == .checklist) {
                    state.toggleBlockType(.checklist)
                    Haptics.impact(.light)
                }
                formatIconBtn("list.bullet", isActive: state.formattingState.blockType == .bullet) {
                    state.toggleBlockType(.bullet)
                    Haptics.impact(.light)
                }
                formatIconBtn("paragraph", isActive: state.formattingState.blockType == .paragraph) {
                    state.toggleBlockType(.paragraph)
                    Haptics.impact(.light)
                }
            }
            .padding(2)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
        }
        .padding(8)
        .background(DS.Theme.sidebar)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func formatBtn(_ title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: title == "B" ? .bold : (title == "I" ? .medium : .regular)))
                .italic(title == "I")
                .underline(title == "U")
                .strikethrough(title == "S")
                .foregroundStyle(isActive ? Color.white : DS.Color.textSecondary)
                .frame(width: 32, height: 26)
                .background(
                    isActive
                        ? Color(red: 0.38, green: 0.45, blue: 0.98)
                        : Color.white.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 4)
                )
        }
        .buttonStyle(.plain)
    }
    
    private func formatBlockBtn(_ title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(isActive ? Color.white : DS.Color.textSecondary)
                .frame(width: 28, height: 26)
                .background(
                    isActive
                        ? Color(red: 0.38, green: 0.45, blue: 0.98)
                        : Color.white.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 4)
                )
        }
        .buttonStyle(.plain)
    }
    
    private func formatIconBtn(_ icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: isActive ? .bold : .regular))
                .foregroundStyle(isActive ? Color.white : DS.Color.textSecondary)
                .frame(width: 28, height: 26)
                .background(
                    isActive
                        ? Color(red: 0.38, green: 0.45, blue: 0.98)
                        : Color.white.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 4)
                )
        }
        .buttonStyle(.plain)
    }
}

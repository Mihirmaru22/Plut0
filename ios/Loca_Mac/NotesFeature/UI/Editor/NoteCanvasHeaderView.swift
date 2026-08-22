import SwiftUI

/// Top header for the Editor Canvas featuring editable document title, folder chip, pin toggle, burger sidebar toggle, and E2EE status badge.
public struct NoteCanvasHeaderView: View {
    
    @Binding public var title: String
    public let folderName: String?
    public let isPinned: Bool
    public let isNavigatorVisible: Bool
    public let onToggleNavigator: () -> Void
    public let onTogglePin: () -> Void
    public let onTitleChanged: (String) -> Void
    
    public init(
        title: Binding<String>,
        folderName: String? = nil,
        isPinned: Bool,
        isNavigatorVisible: Bool = true,
        onToggleNavigator: @escaping () -> Void = {},
        onTogglePin: @escaping () -> Void,
        onTitleChanged: @escaping (String) -> Void
    ) {
        self._title = title
        self.folderName = folderName
        self.isPinned = isPinned
        self.isNavigatorVisible = isNavigatorVisible
        self.onToggleNavigator = onToggleNavigator
        self.onTogglePin = onTogglePin
        self.onTitleChanged = onTitleChanged
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Burger Toggle Button for Middle Notes Menu
                Button(action: onToggleNavigator) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isNavigatorVisible ? Color.secondary : Color.accentColor)
                        .frame(width: 26, height: 26)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .help(isNavigatorVisible ? "Hide Notes List (⌘⌥S)" : "Show Notes List (⌘⌥S)")
                
                // Folder pill
                if let folder = folderName {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 10))
                        Text(folder)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
                    .foregroundStyle(.secondary)
                }
                
                // Pin button
                Button(action: onTogglePin) {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 12))
                        .foregroundStyle(isPinned ? Color.orange : Color.secondary)
                }
                .buttonStyle(.plain)
                .help(isPinned ? "Unpin Note" : "Pin Note")
                
                Spacer()
                
                // E2EE Status Pill
                HStack(spacing: 4) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                    Text("E2EE Sync")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.green.opacity(0.1))
                .clipShape(Capsule())
            }
            
            // Large Editable Title
            TextField("Note Title", text: $title)
                .font(.system(size: 24, weight: .bold))
                .textFieldStyle(.plain)
                .onChange(of: title) { _, newTitle in
                    onTitleChanged(newTitle)
                }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
}

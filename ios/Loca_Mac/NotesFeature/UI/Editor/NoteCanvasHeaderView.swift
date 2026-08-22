import SwiftUI

/// Minimalist top bar for the Editor Canvas providing optional burger toggle and folder indicator.
public struct NoteCanvasHeaderView: View {
    
    public let folderName: String?
    public let isNavigatorVisible: Bool
    public let onToggleNavigator: () -> Void
    
    public init(
        folderName: String? = nil,
        isNavigatorVisible: Bool = true,
        onToggleNavigator: @escaping () -> Void = {}
    ) {
        self.folderName = folderName
        self.isNavigatorVisible = isNavigatorVisible
        self.onToggleNavigator = onToggleNavigator
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            if !isNavigatorVisible {
                Button(action: onToggleNavigator) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Show Notes List (⌘⌥S)")
            }
            
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
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, !isNavigatorVisible || folderName != nil ? 12 : 6)
        .padding(.bottom, !isNavigatorVisible || folderName != nil ? 4 : 0)
    }
}

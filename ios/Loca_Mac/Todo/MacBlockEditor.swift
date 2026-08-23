//
//  MacBlockEditor.swift
//  PLUTO
//
//  Rich Block-Based Document & Note Editor for Mac Todo Details.
//  Supports Paragraphs, Headings (H1/H2/H3), Bullet Lists, Numbered Lists,
//  Checklists, Quotes, and Dividers with real-time SwiftData synchronization.
//

import SwiftUI
import SwiftData
import AppKit

// MARK: - MacBlockEditor

struct MacBlockEditor: View {

    @Bindable var item: TodoItem
    @Binding var activeBlockID: UUID?
    var allItems: [TodoItem]
    var onSave: () -> Void

    @State private var blocks: [TodoContentBlock] = []
    @State private var hoveredBlockID: UUID? = nil
    @FocusState private var focusedFieldID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            if blocks.isEmpty {
                emptyStatePlaceholder
            } else {
                ForEach($blocks) { $block in
                    blockRow(for: $block)
                        .id(block.id)
                }
            }

            // Quick Add Block Bar
            addBlockBar
        }
        .padding(.vertical, DS.Space.xs)
        .onAppear {
            loadBlocks()
        }
        .onChange(of: item.id) { _, _ in
            loadBlocks()
        }
        .onChange(of: activeBlockID) { _, newID in
            if let newID {
                focusedFieldID = newID
            }
        }
    }

    // MARK: - Block Loading & Persistence

    private func loadBlocks() {
        let loaded = item.effectiveContentBlocks
        if loaded.isEmpty {
            let initial = TodoContentBlock(type: .paragraph, text: "")
            self.blocks = [initial]
            persistChanges()
        } else {
            self.blocks = loaded
        }
    }

    private func persistChanges() {
        item.contentBlocks = blocks

        // Sync plain text notes summary for backwards compatibility / search
        let plainSummary = blocks
            .filter { $0.type != .divider }
            .map(\.text)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")
        item.notes = plainSummary.isEmpty ? nil : plainSummary

        onSave()
    }

    // MARK: - Empty State Placeholder

    private var emptyStatePlaceholder: some View {
        Button {
            let newBlock = TodoContentBlock(type: .paragraph, text: "")
            blocks.append(newBlock)
            activeBlockID = newBlock.id
            focusedFieldID = newBlock.id
            persistChanges()
        } label: {
            HStack(spacing: DS.Space.sm) {
                Image(systemName: "text.alignleft")
                    .foregroundStyle(DS.Color.textTertiary)
                Text("Add a note, checklist, or heading…")
                    .font(DS.Text.body)
                    .foregroundStyle(DS.Color.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, DS.Space.sm)
            .padding(.horizontal, DS.Space.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Block Row Renderer

    @ViewBuilder
    private func blockRow(for block: Binding<TodoContentBlock>) -> some View {
        let blockID = block.wrappedValue.id
        let isHovered = hoveredBlockID == blockID

        HStack(alignment: .top, spacing: DS.Space.xs) {
            // Drag / Block Type Menu Handle
            Menu {
                blockTypeMenu(for: block)
            } label: {
                Image(systemName: blockTypeIcon(block.wrappedValue.type))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isHovered ? DS.Color.textSecondary : DS.Color.textTertiary.opacity(0.3))
                    .frame(width: 18, height: 22)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 18)

            // Block Content
            blockContent(for: block)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Quick Delete Button on Hover
            if isHovered && blocks.count > 1 {
                Button {
                    deleteBlock(id: blockID)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(DS.Color.textTertiary)
                        .padding(4)
                        .background(Color.primary.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.primary.opacity(0.03) : Color.clear)
        )
        .onHover { isHovering in
            hoveredBlockID = isHovering ? blockID : nil
        }
    }

    // MARK: - Block Specific Content

    @ViewBuilder
    private func blockContent(for block: Binding<TodoContentBlock>) -> some View {
        switch block.wrappedValue.type {
        case .paragraph:
            TextField("Type something…", text: block.text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(DS.Text.body)
                .foregroundStyle(DS.Color.textPrimary)
                .focused($focusedFieldID, equals: block.wrappedValue.id)
                .onChange(of: block.wrappedValue.text) { _, _ in persistChanges() }
                .onSubmit { handleBlockReturn(after: block.wrappedValue.id) }

        case .h1:
            TextField("Heading 1", text: block.text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(DS.Color.textPrimary)
                .focused($focusedFieldID, equals: block.wrappedValue.id)
                .onChange(of: block.wrappedValue.text) { _, _ in persistChanges() }
                .onSubmit { handleBlockReturn(after: block.wrappedValue.id) }

        case .h2:
            TextField("Heading 2", text: block.text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DS.Color.textPrimary)
                .focused($focusedFieldID, equals: block.wrappedValue.id)
                .onChange(of: block.wrappedValue.text) { _, _ in persistChanges() }
                .onSubmit { handleBlockReturn(after: block.wrappedValue.id) }

        case .h3:
            TextField("Heading 3", text: block.text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.Color.textPrimary)
                .focused($focusedFieldID, equals: block.wrappedValue.id)
                .onChange(of: block.wrappedValue.text) { _, _ in persistChanges() }
                .onSubmit { handleBlockReturn(after: block.wrappedValue.id) }

        case .bullet:
            HStack(alignment: .firstTextBaseline, spacing: DS.Space.xs) {
                Text("•")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(DS.Color.textSecondary)
                TextField("List item", text: block.text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(DS.Text.body)
                    .foregroundStyle(DS.Color.textPrimary)
                    .focused($focusedFieldID, equals: block.wrappedValue.id)
                    .onChange(of: block.wrappedValue.text) { _, _ in persistChanges() }
                    .onSubmit { handleBlockReturn(after: block.wrappedValue.id, inheritType: .bullet) }
            }

        case .numbered:
            let index = (blocks.firstIndex(where: { $0.id == block.wrappedValue.id }) ?? 0) + 1
            HStack(alignment: .firstTextBaseline, spacing: DS.Space.xs) {
                Text("\(index).")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(DS.Color.textSecondary)
                    .frame(minWidth: 16, alignment: .trailing)
                TextField("Numbered item", text: block.text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(DS.Text.body)
                    .foregroundStyle(DS.Color.textPrimary)
                    .focused($focusedFieldID, equals: block.wrappedValue.id)
                    .onChange(of: block.wrappedValue.text) { _, _ in persistChanges() }
                    .onSubmit { handleBlockReturn(after: block.wrappedValue.id, inheritType: .numbered) }
            }

        case .check:
            HStack(alignment: .firstTextBaseline, spacing: DS.Space.xs) {
                Button {
                    block.wrappedValue.isCompleted.toggle()
                    persistChanges()
                } label: {
                    Image(systemName: block.wrappedValue.isCompleted ? "checkmark.square.fill" : "square")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(block.wrappedValue.isCompleted ? Color.accentColor : DS.Color.textTertiary)
                }
                .buttonStyle(.plain)

                TextField("To-do item", text: block.text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(DS.Text.body)
                    .foregroundStyle(block.wrappedValue.isCompleted ? DS.Color.textTertiary : DS.Color.textPrimary)
                    .strikethrough(block.wrappedValue.isCompleted, color: DS.Color.textTertiary)
                    .focused($focusedFieldID, equals: block.wrappedValue.id)
                    .onChange(of: block.wrappedValue.text) { _, _ in persistChanges() }
                    .onSubmit { handleBlockReturn(after: block.wrappedValue.id, inheritType: .check) }
            }

        case .quote:
            HStack(alignment: .top, spacing: DS.Space.sm) {
                Rectangle()
                    .fill(Color.accentColor.opacity(0.6))
                    .frame(width: 3)
                    .cornerRadius(1.5)

                TextField("Quote", text: block.text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .regular, design: .serif).italic())
                    .foregroundStyle(DS.Color.textSecondary)
                    .focused($focusedFieldID, equals: block.wrappedValue.id)
                    .onChange(of: block.wrappedValue.text) { _, _ in persistChanges() }
                    .onSubmit { handleBlockReturn(after: block.wrappedValue.id) }
            }

        case .divider:
            HStack {
                Rectangle()
                    .fill(Color.primary.opacity(0.12))
                    .frame(height: 1)
            }
            .padding(.vertical, DS.Space.xs)

        case .attachment, .subtask, .tag, .link:
            HStack(spacing: DS.Space.xs) {
                Image(systemName: blockTypeIcon(block.wrappedValue.type))
                    .foregroundStyle(Color.accentColor)
                TextField("Reference note…", text: block.text)
                    .textFieldStyle(.plain)
                    .font(DS.Text.body)
                    .focused($focusedFieldID, equals: block.wrappedValue.id)
                    .onChange(of: block.wrappedValue.text) { _, _ in persistChanges() }
            }
        }
    }

    // MARK: - Block Context Menu

    @ViewBuilder
    private func blockTypeMenu(for block: Binding<TodoContentBlock>) -> some View {
        Section("Transform Block") {
            Button {
                block.wrappedValue.type = .paragraph
                persistChanges()
            } label: { Label("Text", systemImage: "paragraph") }

            Button {
                block.wrappedValue.type = .h1
                persistChanges()
            } label: { Label("Heading 1", systemImage: "textformat.size.larger") }

            Button {
                block.wrappedValue.type = .h2
                persistChanges()
            } label: { Label("Heading 2", systemImage: "textformat.size") }

            Button {
                block.wrappedValue.type = .h3
                persistChanges()
            } label: { Label("Heading 3", systemImage: "textformat.size.smaller") }

            Button {
                block.wrappedValue.type = .bullet
                persistChanges()
            } label: { Label("Bullet List", systemImage: "list.bullet") }

            Button {
                block.wrappedValue.type = .numbered
                persistChanges()
            } label: { Label("Numbered List", systemImage: "list.number") }

            Button {
                block.wrappedValue.type = .check
                persistChanges()
            } label: { Label("To-do List", systemImage: "checkmark.square") }

            Button {
                block.wrappedValue.type = .quote
                persistChanges()
            } label: { Label("Quote", systemImage: "quote.opening") }

            Button {
                block.wrappedValue.type = .divider
                persistChanges()
            } label: { Label("Divider", systemImage: "divide") }
        }

        Section {
            Button(role: .destructive) {
                deleteBlock(id: block.wrappedValue.id)
            } label: {
                Label("Delete Block", systemImage: "trash")
            }
        }
    }

    private var activeBlockType: TodoBlockType? {
        guard let id = activeBlockID, let block = blocks.first(where: { $0.id == id }) else {
            return .paragraph
        }
        return block.type
    }

    // MARK: - Add Block Quick Bar (Liquid Glass Container)

    private var addBlockBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            PlutoGlassCluster(spacing: 3) {
                quickAddButton(title: "Text", icon: "text.alignleft", type: .paragraph)
                quickAddButton(title: "H1", icon: "textformat.size.larger", type: .h1)
                quickAddButton(title: "Checklist", icon: "checkmark.square", type: .check)
                quickAddButton(title: "Bullet", icon: "list.bullet", type: .bullet)
                quickAddButton(title: "Heading", icon: "textformat.size", type: .h2)
                quickAddButton(title: "Quote", icon: "quote.opening", type: .quote)
                quickAddButton(title: "Divider", icon: "divide", type: .divider)
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
        .padding(.top, 6)
    }

    private func quickAddButton(title: String, icon: String, type: TodoBlockType) -> some View {
        let isActive = activeBlockType == type
        return Button {
            withAnimation(PlutoSpring.snappy) {
                let newBlock = TodoContentBlock(type: type, text: "")
                blocks.append(newBlock)
                activeBlockID = newBlock.id
                focusedFieldID = newBlock.id
                persistChanges()
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: isActive ? .bold : .medium))
                    .symbolEffect(.bounce, value: isActive)
                Text(title)
                    .font(.system(size: 10, weight: isActive ? .bold : .medium))
            }
            .foregroundStyle(isActive ? Color.black.opacity(0.92) : DS.Theme.textSecondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3.5)
            .background {
                if isActive {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.98), Color(white: 0.90)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(Capsule().stroke(Color.white.opacity(0.9), lineWidth: 0.8))
                        .shadow(color: Color.black.opacity(0.20), radius: 4, y: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func handleBlockReturn(after blockID: UUID, inheritType: TodoBlockType? = nil) {
        guard let index = blocks.firstIndex(where: { $0.id == blockID }) else { return }
        let nextType = inheritType ?? .paragraph
        let newBlock = TodoContentBlock(type: nextType, text: "")

        blocks.insert(newBlock, at: index + 1)
        activeBlockID = newBlock.id
        focusedFieldID = newBlock.id
        persistChanges()
    }

    private func deleteBlock(id: UUID) {
        guard blocks.count > 1 else {
            blocks[0].text = ""
            blocks[0].type = .paragraph
            persistChanges()
            return
        }

        if let index = blocks.firstIndex(where: { $0.id == id }) {
            blocks.remove(at: index)
            let prevIndex = max(0, index - 1)
            let targetID = blocks[prevIndex].id
            activeBlockID = targetID
            focusedFieldID = targetID
            persistChanges()
        }
    }

    private func blockTypeIcon(_ type: TodoBlockType) -> String {
        switch type {
        case .paragraph: return "paragraph"
        case .h1: return "textformat.size.larger"
        case .h2: return "textformat.size"
        case .h3: return "textformat.size.smaller"
        case .bullet: return "list.bullet"
        case .numbered: return "list.number"
        case .check: return "checkmark.square"
        case .quote: return "quote.opening"
        case .divider: return "divide"
        case .attachment: return "paperclip"
        case .subtask: return "arrow.turn.down.right"
        case .tag: return "tag"
        case .link: return "link"
        }
    }
}

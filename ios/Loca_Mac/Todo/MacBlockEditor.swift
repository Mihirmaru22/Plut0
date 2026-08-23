//
//  MacBlockEditor.swift
//  PLUTO
//
//  Rich Open-World Note Canvas for Mac Todo Details.
//  Continuous, freeform 120Hz document editor with native rich-text typography,
//  markdown auto-import, headings, checklists, and real-time SwiftData persistence.
//

import SwiftUI
import SwiftData
import AppKit

// MARK: - MacBlockEditor (Open-World Freeform Canvas)

struct MacBlockEditor: View {

    @Bindable var item: TodoItem
    @Binding var activeBlockID: UUID?
    var allItems: [TodoItem] = []
    var onSave: () -> Void

    @StateObject private var controller = RichTextEditorController()
    @State private var initialAttributed: NSAttributedString = NSAttributedString()
    @State private var initialPlain: String = ""
    @State private var editorKey: UUID = UUID()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Open-World Document Canvas
            MacRichTextEditor(
                initialAttributedText: initialAttributed,
                initialPlainText: initialPlain,
                preset: .standard,
                contentInset: NSSize(width: 6, height: 6),
                isEditable: true,
                controller: controller,
                onTextChangeDebounced: { attributed, plain in
                    persistNote(attributed: attributed, plain: plain)
                }
            )
            .frame(minHeight: 140, maxHeight: .infinity)
            .id(editorKey)

            Divider()
                .opacity(0.12)

            // Modern Formatting Bar (Open World Tools)
            noteFormatToolbar
        }
        .padding(.vertical, 2)
        .onAppear {
            loadInitialNote()
        }
        .onChange(of: item.id) { _, _ in
            loadInitialNote()
        }
    }

    private func loadInitialNote() {
        if let rtf = item.noteRTFData,
           let attr = try? NSAttributedString(data: rtf, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
            self.initialAttributed = attr
            self.initialPlain = attr.string
        } else if let plain = item.notes, !plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.initialAttributed = RichTextTypography.convertMarkdownToAttributedString(markdown: plain, preset: .standard)
            self.initialPlain = plain
        } else if let blocks = item.contentBlocks, !blocks.isEmpty {
            let combined = blocks.map { block -> String in
                switch block.type {
                case .h1: return "# \(block.text)"
                case .h2: return "## \(block.text)"
                case .h3: return "### \(block.text)"
                case .bullet: return "• \(block.text)"
                case .numbered: return "1. \(block.text)"
                case .check: return block.isCompleted ? "- [x] \(block.text)" : "- [ ] \(block.text)"
                case .quote: return "> \(block.text)"
                case .divider: return "---"
                default: return block.text
                }
            }.joined(separator: "\n")
            self.initialAttributed = RichTextTypography.convertMarkdownToAttributedString(markdown: combined, preset: .standard)
            self.initialPlain = combined
        } else {
            self.initialAttributed = NSAttributedString()
            self.initialPlain = ""
        }
        self.editorKey = UUID()
    }

    private func persistNote(attributed: NSAttributedString, plain: String) {
        let rtfData = try? attributed.data(
            from: NSRange(location: 0, length: attributed.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
        item.noteRTFData = rtfData
        let trimmed = plain.trimmingCharacters(in: .whitespacesAndNewlines)
        item.notes = trimmed.isEmpty ? nil : plain
        onSave()
    }

    // MARK: - Open World Formatting Bar

    private var noteFormatToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            PlutoGlassCluster(spacing: 3) {
                // Style Switcher
                formatButton(title: "Text", icon: "text.alignleft", isActive: controller.activeParagraphStyle == .body) {
                    controller.applyParagraphStyle(.body, preset: .standard)
                }

                formatButton(title: "H1", icon: "textformat.size.larger", isActive: controller.activeParagraphStyle == .title) {
                    controller.applyParagraphStyle(.title, preset: .standard)
                }

                formatButton(title: "H2", icon: "textformat.size", isActive: controller.activeParagraphStyle == .heading) {
                    controller.applyParagraphStyle(.heading, preset: .standard)
                }

                formatButton(title: "Checklist", icon: "checkmark.square", isActive: controller.activeParagraphStyle == .checklist) {
                    controller.applyParagraphStyle(.checklist, preset: .standard)
                }

                formatButton(title: "Bullet", icon: "list.bullet", isActive: controller.activeParagraphStyle == .bulletedList) {
                    controller.applyParagraphStyle(.bulletedList, preset: .standard)
                }

                formatButton(title: "Numbered", icon: "list.number", isActive: controller.activeParagraphStyle == .numberedList) {
                    controller.applyParagraphStyle(.numberedList, preset: .standard)
                }

                formatButton(title: "Quote", icon: "quote.opening", isActive: controller.activeParagraphStyle == .quote) {
                    controller.applyParagraphStyle(.quote, preset: .standard)
                }

                // Inline Traits
                formatButton(title: "B", icon: "bold", isActive: controller.isBold) {
                    controller.toggleBold(preset: .standard)
                }

                formatButton(title: "I", icon: "italic", isActive: controller.isItalic) {
                    controller.toggleItalic(preset: .standard)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
    }

    private func formatButton(title: String, icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(PlutoSpring.snappy) {
                action()
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
}

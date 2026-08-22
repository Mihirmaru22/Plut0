import Foundation

/// Bidirectional translator mapping between Phase 1 Note domain models and Phase 2 CRDT documents.
public enum CRDTTranslator {
    
    // MARK: - CRDTDoc -> NoteContent
    
    public static func materializeContent(from doc: CRDTDoc) -> NoteContent {
        let activeBlocks = doc.blocks.filter { !$0.isDeleted }
        
        let noteBlocks: [NoteBlock] = activeBlocks.map { crdtBlock in
            let text = crdtBlock.text.string
            switch crdtBlock.type {
            case "heading":
                let level = Int(crdtBlock.attributes["level", default: "1"]) ?? 1
                return .heading(HeadingBlock(id: crdtBlock.id, text: text, level: level))
            case "checklistItem":
                let isChecked = crdtBlock.attributes["isChecked"] == "true"
                return .checklistItem(ChecklistItemBlock(id: crdtBlock.id, text: text, isChecked: isChecked))
            case "bullet":
                return .bullet(BulletBlock(id: crdtBlock.id, text: text))
            case "divider":
                return .divider(DividerBlock(id: crdtBlock.id))
            default:
                return .paragraph(ParagraphBlock(id: crdtBlock.id, text: text))
            }
        }
        
        let finalBlocks = noteBlocks.isEmpty ? [.paragraph(ParagraphBlock())] : noteBlocks
        return NoteContent(version: 1, blocks: finalBlocks)
    }
    
    // MARK: - Note -> CRDTDoc
    
    public static func crdtDoc(from note: Note, deviceID: String = "local-device") -> CRDTDoc {
        var blocks: [CRDTBlock] = []
        let now = note.updatedAt.timeIntervalSince1970
        var prevSortKey: String? = nil
        
        for block in note.content.blocks {
            let sortKey = FractionalIndex.between(prevSortKey, nil)
            prevSortKey = sortKey
            
            switch block {
            case .paragraph(let p):
                blocks.append(
                    CRDTBlock(
                        id: p.id,
                        type: "paragraph",
                        text: CRDTText(string: p.text, deviceID: deviceID),
                        lastModified: now,
                        sortKey: sortKey
                    )
                )
            case .heading(let h):
                blocks.append(
                    CRDTBlock(
                        id: h.id,
                        type: "heading",
                        text: CRDTText(string: h.text, deviceID: deviceID),
                        attributes: ["level": "\(h.level)"],
                        lastModified: now,
                        sortKey: sortKey
                    )
                )
            case .checklistItem(let c):
                blocks.append(
                    CRDTBlock(
                        id: c.id,
                        type: "checklistItem",
                        text: CRDTText(string: c.text, deviceID: deviceID),
                        attributes: ["isChecked": c.isChecked ? "true" : "false"],
                        lastModified: now,
                        sortKey: sortKey
                    )
                )
            case .bullet(let b):
                blocks.append(
                    CRDTBlock(
                        id: b.id,
                        type: "bullet",
                        text: CRDTText(string: b.text, deviceID: deviceID),
                        lastModified: now,
                        sortKey: sortKey
                    )
                )
            case .divider(let d):
                blocks.append(
                    CRDTBlock(
                        id: d.id,
                        type: "divider",
                        text: CRDTText(),
                        lastModified: now,
                        sortKey: sortKey
                    )
                )
            }
        }
        
        var metadata: [String: String] = [:]
        var metadataTimestamps: [String: Double] = [:]
        
        metadata["title"] = note.title
        metadataTimestamps["title"] = now
        
        metadata["isPinned"] = note.isPinned ? "true" : "false"
        metadataTimestamps["isPinned"] = now
        
        metadata["isDeleted"] = note.isDeleted ? "true" : "false"
        metadataTimestamps["isDeleted"] = now
        
        if let folderID = note.folderID {
            metadata["folderID"] = folderID.raw.uuidString
            metadataTimestamps["folderID"] = now
        }
        
        return CRDTDoc(
            id: note.id,
            deviceID: deviceID,
            metadata: metadata,
            metadataTimestamps: metadataTimestamps,
            blocks: blocks
        )
    }
    
    // MARK: - Mutation Application to CRDTDoc
    
    public static func apply(mutation: NoteMutation, to doc: inout CRDTDoc, deviceID: String = "local-device") {
        let now = Date().timeIntervalSince1970
        
        switch mutation {
        case .createNote(let noteID, let folderID):
            doc = CRDTDoc(id: noteID, deviceID: deviceID)
            doc.title = ""
            doc.folderID = folderID
            let defaultBlock = CRDTBlock(id: UUID(), type: "paragraph", text: CRDTText(string: "", deviceID: deviceID), sortKey: FractionalIndex.initial)
            doc.addBlock(defaultBlock)
            
        case .setTitle(_, let title):
            doc.setMetadata(key: "title", value: title, timestamp: now)
            
        case .setPinned(_, let isPinned):
            doc.setMetadata(key: "isPinned", value: isPinned ? "true" : "false", timestamp: now)
            
        case .setLocked(_, let isLocked):
            doc.setMetadata(key: "isLocked", value: isLocked ? "true" : "false", timestamp: now)
            
        case .markDeleted:
            doc.setMetadata(key: "isDeleted", value: "true", timestamp: now)
            
        case .restore:
            doc.setMetadata(key: "isDeleted", value: "false", timestamp: now)
            
        case .move(_, let folderID):
            doc.folderID = folderID
            
        case .permanentlyDelete:
            doc.setMetadata(key: "isDeleted", value: "true", timestamp: now)
            for i in 0..<doc.blocks.count {
                doc.blocks[i].isDeleted = true
            }
            
        case .toggleChecklistItem(_, let blockID):
            doc.toggleChecklist(blockID: blockID)
            
        case .updateContent(_, let newContent):
            // Reconcile blocks while preserving CRDT atom histories for identical block IDs
            var updatedBlocks: [CRDTBlock] = []
            let existingMap = Dictionary(uniqueKeysWithValues: doc.blocks.map { ($0.id, $0) })
            var lastSortKey: String? = nil
            
            for block in newContent.blocks {
                let sortKey = FractionalIndex.between(lastSortKey, nil)
                lastSortKey = sortKey
                
                if var existing = existingMap[block.id] {
                    // Update text if changed
                    if existing.text.string != block.text {
                        existing.text = CRDTText(string: block.text, deviceID: deviceID)
                    }
                    if case .checklistItem(let item) = block {
                        existing.attributes["isChecked"] = item.isChecked ? "true" : "false"
                    } else if case .heading(let h) = block {
                        existing.attributes["level"] = "\(h.level)"
                    }
                    existing.lastModified = now
                    existing.sortKey = sortKey
                    updatedBlocks.append(existing)
                } else {
                    // Brand new block
                    let newCRDTBlock: CRDTBlock
                    switch block {
                    case .paragraph(let p):
                        newCRDTBlock = CRDTBlock(id: p.id, type: "paragraph", text: CRDTText(string: p.text, deviceID: deviceID), lastModified: now, sortKey: sortKey)
                    case .heading(let h):
                        newCRDTBlock = CRDTBlock(id: h.id, type: "heading", text: CRDTText(string: h.text, deviceID: deviceID), attributes: ["level": "\(h.level)"], lastModified: now, sortKey: sortKey)
                    case .checklistItem(let c):
                        newCRDTBlock = CRDTBlock(id: c.id, type: "checklistItem", text: CRDTText(string: c.text, deviceID: deviceID), attributes: ["isChecked": c.isChecked ? "true" : "false"], lastModified: now, sortKey: sortKey)
                    case .bullet(let b):
                        newCRDTBlock = CRDTBlock(id: b.id, type: "bullet", text: CRDTText(string: b.text, deviceID: deviceID), lastModified: now, sortKey: sortKey)
                    case .divider(let d):
                        newCRDTBlock = CRDTBlock(id: d.id, type: "divider", text: CRDTText(), lastModified: now, sortKey: sortKey)
                    }
                    updatedBlocks.append(newCRDTBlock)
                }
            }
            doc.blocks = updatedBlocks
            _ = doc.vectorClock.increment(for: deviceID)
            
        case .materializeFromSync:
            break
        }
    }
}

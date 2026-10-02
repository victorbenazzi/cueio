import AppKit
import UniformTypeIdentifiers

enum DocumentMode: String {
    case raw
    case preview
}

enum SaveState {
    case draft
    case edited
    case saved
}

@objc(CueioDocument)
final class Document: NSDocument {
    static let stateDidChange = Notification.Name("CueioDocumentStateDidChange")
    static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkdn"]

    /// O texto vive aqui e o editor exibe este mesmo storage: não existe cópia para sincronizar.
    let storage = NSTextStorage()
    private var preferredMode: DocumentMode = .raw

    // Autosave em arquivo, versões e restauração de rascunhos vêm do NSDocument.
    override class var autosavesInPlace: Bool { true }

    override var fileURL: URL? {
        didSet { notifyStateChange() }
    }

    var isMarkdown: Bool {
        if let ext = fileURL?.pathExtension.lowercased(), !ext.isEmpty {
            return Self.markdownExtensions.contains(ext)
        }
        guard let fileType, let type = UTType(fileType) else { return true }
        return type.conforms(to: .markdownText)
    }

    /// Texto puro nunca tem preview, então o modo efetivo já respeita essa regra.
    var mode: DocumentMode {
        get { isMarkdown ? preferredMode : .raw }
        set {
            guard newValue != preferredMode else { return }
            preferredMode = newValue
            invalidateRestorableState()
            notifyStateChange()
        }
    }

    var saveState: SaveState {
        if fileURL == nil { return .draft }
        return hasUnautosavedChanges ? .edited : .saved
    }

    override func makeWindowControllers() {
        // Arquivo vindo do disco abre no preview; rascunho novo abre no editor.
        // A restauração de sessão roda depois e sobrescreve esta escolha.
        preferredMode = fileURL == nil ? .raw : .preview
        addWindowController(DocumentWindowController(document: self))
    }

    override func read(from data: Data, ofType typeName: String) throws {
        guard let text = Self.decode(data) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        storage.replaceCharacters(in: NSRange(location: 0, length: storage.length), with: text)
        undoManager?.removeAllActions()
    }

    override func data(ofType typeName: String) throws -> Data {
        Data(storage.string.utf8)
    }

    override func updateChangeCount(_ change: NSDocument.ChangeType) {
        super.updateChangeCount(change)
        notifyStateChange()
    }

    override func updateChangeCount(withToken changeCountToken: Any, for saveOperation: NSDocument.SaveOperationType) {
        super.updateChangeCount(withToken: changeCountToken, for: saveOperation)
        notifyStateChange()
    }

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        coder.encode(preferredMode.rawValue as NSString, forKey: "cueioMode")
    }

    override func restoreState(with coder: NSCoder) {
        super.restoreState(with: coder)
        if let raw = coder.decodeObject(of: NSString.self, forKey: "cueioMode") as String?,
           let restored = DocumentMode(rawValue: raw) {
            mode = restored
        }
    }

    private func notifyStateChange() {
        DispatchQueue.main.async { [weak self] in
            NotificationCenter.default.post(name: Self.stateDidChange, object: self)
        }
    }

    private static func decode(_ data: Data) -> String? {
        if let utf8 = String(data: data, encoding: .utf8) {
            return utf8.hasPrefix("\u{FEFF}") ? String(utf8.dropFirst()) : utf8
        }
        var converted: NSString?
        let encoding = NSString.stringEncoding(for: data, encodingOptions: nil,
                                               convertedString: &converted, usedLossyConversion: nil)
        return encoding == 0 ? nil : converted as String?
    }
}

import AppKit
import UniformTypeIdentifiers

enum DocumentMode: String {
    case raw
    case preview
}

@objc(CueioDocument)
final class Document: NSDocument {
    static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkdn"]

    private(set) var text = ""
    private var hasLoadedFromDisk = false

    var mode: DocumentMode = .raw {
        didSet {
            guard mode != oldValue else { return }
            invalidateRestorableState()
            onModeChange?()
        }
    }

    /// Fonte da verdade enquanto há uma janela aberta: o texto vive no NSTextView e só é copiado ao salvar.
    var textProvider: (() -> String)?
    var onStateChange: (() -> Void)?
    var onContentReload: (() -> Void)?
    var onModeChange: (() -> Void)?

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

    override func makeWindowControllers() {
        addWindowController(DocumentWindowController())
    }

    override func read(from data: Data, ofType typeName: String) throws {
        guard let decoded = Self.decode(data) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        text = decoded
        if !hasLoadedFromDisk {
            hasLoadedFromDisk = true
            mode = isMarkdown ? .preview : .raw
        }
        onContentReload?()
    }

    override func data(ofType typeName: String) throws -> Data {
        if let current = textProvider?() { text = current }
        return Data(text.utf8)
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
        coder.encode(mode.rawValue as NSString, forKey: "cueioMode")
    }

    override func restoreState(with coder: NSCoder) {
        super.restoreState(with: coder)
        if let raw = coder.decodeObject(of: NSString.self, forKey: "cueioMode") as String?,
           let restored = DocumentMode(rawValue: raw) {
            mode = restored
        }
    }

    private func notifyStateChange() {
        DispatchQueue.main.async { [weak self] in self?.onStateChange?() }
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

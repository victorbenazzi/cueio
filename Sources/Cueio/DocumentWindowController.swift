import AppKit

/// Janela de um documento: compõe editor, toolbar e barra de status, e aplica o modo foco.
final class DocumentWindowController: NSWindowController, NSWindowDelegate, NSMenuItemValidation {
    private let doc: Document
    private let editor: EditorViewController
    private let modeToolbar = ModeToolbar()
    private let statusBar = StatusBar()

    init(document: Document) {
        doc = document
        editor = EditorViewController(document: document)

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 560),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.minSize = NSSize(width: 360, height: 240)
        window.tabbingMode = .preferred
        window.tabbingIdentifier = "cueio.document"
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unifiedCompact
        window.backgroundColor = Theme.background
        window.center()
        super.init(window: window)

        window.delegate = self
        window.toolbar = modeToolbar.toolbar
        modeToolbar.onSelect = { [weak self] mode in self?.doc.mode = mode }

        // Esconder a barra de status (modo foco) recolhe o espaço sozinho.
        let stack = NSStackView(views: [editor.view, statusBar])
        stack.orientation = .vertical
        stack.spacing = 0
        stack.detachesHiddenViews = true
        stack.setHuggingPriority(.defaultLow, for: .vertical)
        statusBar.heightAnchor.constraint(equalToConstant: StatusBar.height).isActive = true
        window.contentView = stack

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(documentStateDidChange), name: Document.stateDidChange, object: doc)
        center.addObserver(self, selector: #selector(applyFocusMode), name: Settings.focusModeDidChange, object: nil)

        applyFocusMode()
        documentStateDidChange()
        editor.focus()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) não é usado") }

    // MARK: - Estado

    @objc private func documentStateDidChange() {
        modeToolbar.update(mode: doc.mode, canPreview: doc.isMarkdown)
        statusBar.update(state: doc.saveState)
    }

    @objc private func applyFocusMode() {
        let focus = Settings.shared.focusMode
        window?.toolbar?.isVisible = !focus
        window?.titleVisibility = focus ? .hidden : .visible
        statusBar.isHidden = focus
    }

    // MARK: - Ações

    @objc func toggleMarkdownPreview(_ sender: Any?) {
        doc.mode = doc.mode == .raw ? .preview : .raw
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        guard item.action == #selector(toggleMarkdownPreview(_:)) else { return true }
        item.state = doc.mode == .preview ? .on : .off
        return doc.isMarkdown
    }

    // MARK: - NSWindowDelegate

    func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? {
        doc.undoManager
    }
}

import AppKit

final class DocumentWindowController: NSWindowController, NSWindowDelegate, NSTextViewDelegate,
    NSToolbarDelegate, NSMenuItemValidation {
    private static let modeItem = NSToolbarItem.Identifier("cueio.mode")
    private static let focusColumnWidth: CGFloat = 700

    private let scrollView: NSScrollView
    private let textView: NSTextView
    private let highlighter = MarkdownHighlighter()
    private let statusBar = StatusBar()
    private let modeControl = NSSegmentedControl()
    private var statusBarHeight: NSLayoutConstraint!
    private var preview: PreviewView?
    private var fontSize = Settings.shared.fontSize
    private var words = 0
    private var wordCountWork: DispatchWorkItem?

    private var cueioDocument: Document? { document as? Document }

    init() {
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

        scrollView = NSTextView.scrollableTextView()
        textView = scrollView.documentView as! NSTextView
        super.init(window: window)

        window.delegate = self
        buildLayout()
        buildToolbar()
        configureTextView()
        applyFocusMode()
        NotificationCenter.default.addObserver(self, selector: #selector(settingsDidChange),
                                               name: Settings.didChange, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) não é usado") }

    override var document: AnyObject? {
        didSet { attachDocument() }
    }

    // MARK: - Montagem

    private func buildLayout() {
        guard let content = window?.contentView else { return }
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        statusBar.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(scrollView)
        content.addSubview(statusBar)

        statusBarHeight = statusBar.heightAnchor.constraint(equalToConstant: StatusBar.height)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: content.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: statusBar.topAnchor),
            statusBar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            statusBar.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            statusBar.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            statusBarHeight,
        ])

        scrollView.contentView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(viewportDidResize),
                                               name: NSView.frameDidChangeNotification, object: scrollView.contentView)
    }

    private func buildToolbar() {
        // Controle pequeno e símbolos leves: a toolbar compacta não deve chamar atenção.
        let symbol = NSImage.SymbolConfiguration(pointSize: 10, weight: .regular)
        modeControl.segmentCount = 2
        modeControl.trackingMode = .selectOne
        modeControl.controlSize = .small
        modeControl.setImage(NSImage(systemSymbolName: "chevron.left.forwardslash.chevron.right",
                                     accessibilityDescription: "Editar texto")?.withSymbolConfiguration(symbol), forSegment: 0)
        modeControl.setImage(NSImage(systemSymbolName: "eye", accessibilityDescription: "Visualizar markdown")?
            .withSymbolConfiguration(symbol), forSegment: 1)
        modeControl.setWidth(26, forSegment: 0)
        modeControl.setWidth(26, forSegment: 1)
        modeControl.setToolTip("Editar texto", forSegment: 0)
        modeControl.setToolTip("Visualizar markdown (⇧⌘P)", forSegment: 1)
        modeControl.target = self
        modeControl.action = #selector(modeControlChanged(_:))

        let toolbar = NSToolbar(identifier: "cueio.document")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        window?.toolbar = toolbar
    }

    private func configureTextView() {
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.drawsBackground = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.insertionPointColor = Theme.accent
        textView.textContainer?.lineFragmentPadding = 0
        textView.delegate = self
        textView.textStorage?.delegate = highlighter
        applyEditorStyle()
    }

    private func applyEditorStyle() {
        let style = EditorStyle(fontSize: fontSize)
        highlighter.style = style
        textView.defaultParagraphStyle = style.paragraph
        textView.typingAttributes = style.baseAttributes
        if let storage = textView.textStorage { highlighter.restyle(storage) }
    }

    // MARK: - Documento

    private func attachDocument() {
        guard let doc = cueioDocument else { return }
        doc.textProvider = { [weak self] in self?.textView.string ?? "" }
        doc.onStateChange = { [weak self] in self?.documentStateDidChange() }
        doc.onContentReload = { [weak self] in self?.loadText() }
        doc.onModeChange = { [weak self] in self?.applyMode() }
        loadText()
    }

    private func loadText() {
        guard let doc = cueioDocument else { return }
        highlighter.isMarkdown = doc.isMarkdown
        textView.string = doc.text
        textView.typingAttributes = highlighter.style.baseAttributes
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        doc.undoManager?.removeAllActions()
        words = WordCounter.count(doc.text)
        applyMode()
        refreshStatus()
    }

    /// Salvar como .txt (ou renomear) muda o tipo: o realce e o preview acompanham.
    private func documentStateDidChange() {
        guard let doc = cueioDocument else { return }
        if highlighter.isMarkdown != doc.isMarkdown {
            highlighter.isMarkdown = doc.isMarkdown
            if let storage = textView.textStorage { highlighter.restyle(storage) }
            if !doc.isMarkdown { doc.mode = .raw }
            applyMode()
        }
        refreshStatus()
    }

    private func refreshStatus() {
        guard let doc = cueioDocument else { return }
        let location = doc.fileURL.map { ($0.path as NSString).abbreviatingWithTildeInPath }
            ?? "Rascunho guardado automaticamente"
        let state: String
        if doc.fileURL == nil {
            state = "Não salvo"
        } else if doc.hasUnautosavedChanges {
            state = "Editado"
        } else {
            state = "Salvo ✓"
        }
        let count = "\(words.formatted()) \(words == 1 ? "palavra" : "palavras")"
        statusBar.update(leading: location, trailing: "\(count)   \(state)")
    }

    // MARK: - Modos

    private func applyMode() {
        guard let doc = cueioDocument, let window else { return }
        let showPreview = doc.mode == .preview && doc.isMarkdown
        modeControl.selectedSegment = showPreview ? 1 : 0
        modeControl.setEnabled(doc.isMarkdown, forSegment: 1)

        if showPreview {
            let preview = ensurePreview()
            preview.render(markdown: textView.string, baseURL: doc.fileURL?.deletingLastPathComponent())
            preview.isHidden = false
            scrollView.isHidden = true
            window.makeFirstResponder(preview.webView)
        } else {
            preview?.isHidden = true
            scrollView.isHidden = false
            window.makeFirstResponder(textView)
        }
    }

    private func ensurePreview() -> PreviewView {
        if let preview { return preview }
        let view = PreviewView()
        view.translatesAutoresizingMaskIntoConstraints = false
        window?.contentView?.addSubview(view)
        let top = (window?.contentLayoutGuide as? NSLayoutGuide)?.topAnchor ?? scrollView.topAnchor
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: top),
            view.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
        ])
        preview = view
        return view
    }

    @objc func toggleMarkdownPreview(_ sender: Any?) {
        guard let doc = cueioDocument, doc.isMarkdown else { return }
        doc.mode = doc.mode == .raw ? .preview : .raw
    }

    @objc private func modeControlChanged(_ sender: NSSegmentedControl) {
        cueioDocument?.mode = sender.selectedSegment == 1 ? .preview : .raw
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        if item.action == #selector(toggleMarkdownPreview(_:)) {
            item.state = cueioDocument?.mode == .preview ? .on : .off
            return cueioDocument?.isMarkdown ?? false
        }
        return true
    }

    // MARK: - Foco, fonte e layout

    @objc private func settingsDidChange() {
        if fontSize != Settings.shared.fontSize {
            fontSize = Settings.shared.fontSize
            applyEditorStyle()
        }
        applyFocusMode()
    }

    private func applyFocusMode() {
        let focus = Settings.shared.focusMode
        window?.toolbar?.isVisible = !focus
        window?.titleVisibility = focus ? .hidden : .visible
        statusBar.isHidden = focus
        statusBarHeight.constant = focus ? 0 : StatusBar.height
        updateInsets()
    }

    @objc private func viewportDidResize() { updateInsets() }

    /// No modo foco o texto vira uma coluna centralizada com largura de leitura.
    private func updateInsets() {
        let width = scrollView.contentSize.width
        let column = Settings.shared.focusMode ? Self.focusColumnWidth : .greatestFiniteMagnitude
        let inset = NSSize(width: max(24, ((width - column) / 2).rounded(.down)), height: 18)
        if textView.textContainerInset != inset { textView.textContainerInset = inset }
    }

    // MARK: - NSTextViewDelegate

    func textDidChange(_ notification: Notification) {
        wordCountWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.words = WordCounter.count(self.textView.string)
            self.refreshStatus()
        }
        wordCountWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    // MARK: - NSWindowDelegate

    func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? {
        cueioDocument?.undoManager
    }

    // MARK: - NSToolbarDelegate

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace, Self.modeItem]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard identifier == Self.modeItem else { return nil }
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = "Modo"
        item.view = modeControl
        return item
    }
}

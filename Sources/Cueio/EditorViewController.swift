import AppKit

/// Área de conteúdo de um documento: o editor de texto e, quando pedido, o preview.
/// Exibe o NSTextStorage do próprio Document, então nunca há texto para copiar ou sincronizar.
final class EditorViewController: NSViewController {
    private static let focusColumnWidth: CGFloat = 700

    let textView: NSTextView
    private let document: Document
    private let scrollView = NSScrollView()
    private let contentStorage = NSTextContentStorage()
    private let highlighter: MarkdownHighlighter
    private var preview: PreviewView?
    private var displayedMode: DocumentMode?

    init(document: Document) {
        self.document = document

        let container = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        container.lineFragmentPadding = 0
        let layoutManager = NSTextLayoutManager()
        layoutManager.textContainer = container
        contentStorage.textStorage = document.storage
        contentStorage.addTextLayoutManager(layoutManager)
        textView = NSTextView(frame: .zero, textContainer: container)

        highlighter = MarkdownHighlighter(storage: document.storage,
                                          style: EditorStyle(fontSize: Settings.shared.fontSize),
                                          isMarkdown: document.isMarkdown)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) não é usado") }

    override func loadView() {
        configureTextView()
        scrollView.documentView = textView
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.contentView.postsFrameChangedNotifications = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let root = NSView()
        root.addSubview(scrollView)
        pin(scrollView, to: root)
        view = root

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(updateInsets),
                           name: NSView.frameDidChangeNotification, object: scrollView.contentView)
        center.addObserver(self, selector: #selector(updateInsets), name: Settings.focusModeDidChange, object: nil)
        center.addObserver(self, selector: #selector(fontSizeDidChange), name: Settings.fontSizeDidChange, object: nil)
        center.addObserver(self, selector: #selector(documentStateDidChange), name: Document.stateDidChange, object: document)
        center.addObserver(self, selector: #selector(storageDidEdit),
                           name: NSTextStorage.didProcessEditingNotification, object: document.storage)

        applyTypingStyle()
        updateInsets()
        showCurrentMode()
    }

    private func configureTextView() {
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
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
    }

    /// Coloca o foco em quem está visível: o texto ou o preview.
    func focus() {
        view.window?.makeFirstResponder(document.mode == .preview ? preview?.webView : textView)
    }

    // MARK: - Modos

    private func showCurrentMode() {
        let mode = document.mode
        displayedMode = mode
        if mode == .preview {
            let preview = ensurePreview()
            renderPreview()
            preview.isHidden = false
            scrollView.isHidden = true
        } else {
            preview?.isHidden = true
            scrollView.isHidden = false
        }
        focus()
    }

    private func renderPreview() {
        preview?.render(markdown: document.storage.string, baseURL: document.fileURL?.deletingLastPathComponent())
    }

    private func ensurePreview() -> PreviewView {
        if let preview { return preview }
        let created = PreviewView()
        created.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(created)
        // O editor rola por baixo da toolbar; o preview começa abaixo dela.
        pin(created, to: view, top: view.safeAreaLayoutGuide.topAnchor)
        preview = created
        return created
    }

    // MARK: - Observadores

    @objc private func documentStateDidChange() {
        highlighter.isMarkdown = document.isMarkdown
        if document.mode != displayedMode { showCurrentMode() }
    }

    /// Mudanças de conteúdo fora da digitação (reverter, arquivo alterado em outro app) refletem no preview.
    @objc private func storageDidEdit() {
        if displayedMode == .preview, document.storage.editedMask.contains(.editedCharacters) { renderPreview() }
    }

    @objc private func fontSizeDidChange() {
        highlighter.style = EditorStyle(fontSize: Settings.shared.fontSize)
        applyTypingStyle()
    }

    private func applyTypingStyle() {
        textView.defaultParagraphStyle = highlighter.style.paragraph
        textView.typingAttributes = highlighter.style.baseAttributes
    }

    /// No modo foco o texto vira uma coluna centralizada com largura de leitura.
    @objc private func updateInsets() {
        let width = scrollView.contentSize.width
        let column = Settings.shared.focusMode ? Self.focusColumnWidth : .greatestFiniteMagnitude
        let inset = NSSize(width: max(24, ((width - column) / 2).rounded(.down)), height: 18)
        if textView.textContainerInset != inset { textView.textContainerInset = inset }
    }

    private func pin(_ child: NSView, to parent: NSView, top: NSLayoutYAxisAnchor? = nil) {
        NSLayoutConstraint.activate([
            child.topAnchor.constraint(equalTo: top ?? parent.topAnchor),
            child.bottomAnchor.constraint(equalTo: parent.bottomAnchor),
            child.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            child.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
        ])
    }
}

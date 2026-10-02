import AppKit

/// Toolbar compacta com o seletor editor/preview.
final class ModeToolbar: NSObject, NSToolbarDelegate {
    private static let modeItem = NSToolbarItem.Identifier("cueio.mode")

    let toolbar = NSToolbar(identifier: "cueio.document")
    var onSelect: ((DocumentMode) -> Void)?
    private let control = NSSegmentedControl()

    override init() {
        super.init()
        // Controle pequeno e símbolos leves: a toolbar compacta não deve chamar atenção.
        let symbol = NSImage.SymbolConfiguration(pointSize: 10, weight: .regular)
        let segments = [("chevron.left.forwardslash.chevron.right", "Editar texto"),
                        ("eye", "Visualizar markdown (⇧⌘P)")]
        control.segmentCount = segments.count
        control.trackingMode = .selectOne
        control.controlSize = .small
        for (index, (name, label)) in segments.enumerated() {
            control.setImage(NSImage(systemSymbolName: name, accessibilityDescription: label)?
                .withSymbolConfiguration(symbol), forSegment: index)
            control.setWidth(26, forSegment: index)
            control.setToolTip(label, forSegment: index)
        }
        control.target = self
        control.action = #selector(controlChanged(_:))

        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
    }

    func update(mode: DocumentMode, canPreview: Bool) {
        control.selectedSegment = mode == .preview ? 1 : 0
        control.setEnabled(canPreview, forSegment: 1)
    }

    @objc private func controlChanged(_ sender: NSSegmentedControl) {
        onSelect?(sender.selectedSegment == 1 ? .preview : .raw)
    }

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
        item.view = control
        return item
    }
}

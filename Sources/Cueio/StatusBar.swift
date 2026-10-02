import AppKit

/// Rodapé mínimo: mostra só se o documento está salvo.
final class StatusBar: NSView {
    static let height: CGFloat = 22

    private let label = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        label.font = .systemFont(ofSize: 10.5)
        label.textColor = Theme.muted
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) não é usado") }

    func update(state: SaveState) {
        label.stringValue = state.label
    }
}

private extension SaveState {
    var label: String {
        switch self {
        case .draft: "Não salvo"
        case .edited: "Editado"
        case .saved: "Salvo ✓"
        }
    }
}

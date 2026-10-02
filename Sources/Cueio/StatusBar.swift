import AppKit

final class StatusBar: NSView {
    static let height: CGFloat = 22

    private let leading = NSTextField(labelWithString: "")
    private let trailing = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        for label in [leading, trailing] {
            label.font = .systemFont(ofSize: 10.5)
            label.textColor = Theme.muted
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)
        }
        leading.lineBreakMode = .byTruncatingMiddle
        leading.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        trailing.setContentCompressionResistancePriority(.required, for: .horizontal)

        NSLayoutConstraint.activate([
            leading.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            leading.centerYAnchor.constraint(equalTo: centerYAnchor),
            trailing.leadingAnchor.constraint(greaterThanOrEqualTo: leading.trailingAnchor, constant: 16),
            trailing.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            trailing.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) não é usado") }

    func update(leading leadingText: String, trailing trailingText: String) {
        if leading.stringValue != leadingText { leading.stringValue = leadingText }
        if trailing.stringValue != trailingText { trailing.stringValue = trailingText }
    }

    override func draw(_ dirtyRect: NSRect) {
        Theme.background.setFill()
        bounds.fill()
        let hairline = 1 / (window?.backingScaleFactor ?? 2)
        Theme.line.setFill()
        NSRect(x: 0, y: bounds.maxY - hairline, width: bounds.width, height: hairline).fill()
    }
}

enum WordCounter {
    static func count(_ text: String) -> Int {
        var words = 0
        var inWord = false
        for scalar in text.unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                inWord = false
            } else if !inWord {
                inWord = true
                words += 1
            }
        }
        return words
    }
}

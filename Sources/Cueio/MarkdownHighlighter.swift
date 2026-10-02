import AppKit

struct EditorStyle {
    let font: NSFont
    let boldFont: NSFont
    let italicFont: NSFont
    let paragraph: NSParagraphStyle
    let baselineOffset: CGFloat

    init(fontSize: CGFloat) {
        font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        boldFont = .monospacedSystemFont(ofSize: fontSize, weight: .semibold)
        italicFont = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)

        // Mesma respiração da 0.1 (line-height 1.65), com o texto centralizado na linha.
        let lineHeight = (fontSize * 1.65).rounded()
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = lineHeight
        paragraph.maximumLineHeight = lineHeight
        self.paragraph = paragraph
        baselineOffset = max(0, (lineHeight - (font.ascender - font.descender)) / 4).rounded()
    }

    var baseAttributes: [NSAttributedString.Key: Any] {
        [.font: font, .foregroundColor: Theme.text, .paragraphStyle: paragraph, .baselineOffset: baselineOffset]
    }
}

/// Realce leve de markdown direto no NSTextStorage: só fonte e cor, o texto continua puro.
/// A cada edição reestiliza apenas os parágrafos tocados; blocos de código cercados forçam
/// uma passada completa quando a estrutura deles muda.
final class MarkdownHighlighter: NSObject, NSTextStorageDelegate {
    var style = EditorStyle(fontSize: Settings.defaultFontSize)
    var isMarkdown = true
    private var fences: [NSRange] = []

    func restyle(_ storage: NSTextStorage) {
        storage.beginEditing()
        fences = isMarkdown ? Self.findFences(in: storage.string as NSString) : []
        highlight(storage, in: NSRange(location: 0, length: storage.length))
        storage.endEditing()
    }

    func textStorage(_ storage: NSTextStorage, willProcessEditing editedMask: NSTextStorageEditActions,
                     range editedRange: NSRange, changeInLength delta: Int) {
        guard editedMask.contains(.editedCharacters) else { return }
        let string = storage.string as NSString

        guard isMarkdown else {
            highlight(storage, in: string.paragraphRange(for: editedRange))
            return
        }

        let expected = fences.map { Self.shift($0, by: editedRange, delta: delta) }
        fences = Self.findFences(in: string)
        let range = expected == fences ? string.paragraphRange(for: editedRange) : NSRange(location: 0, length: string.length)
        highlight(storage, in: range)
    }

    // MARK: - Estilos

    private func highlight(_ storage: NSTextStorage, in range: NSRange) {
        storage.setAttributes(style.baseAttributes, range: range)
        guard isMarkdown, range.length > 0 else { return }

        let string = storage.string
        let codeBlocks = fences.filter { NSIntersectionRange($0, range).length > 0 }
        let isOutsideCode: (NSRange) -> Bool = { match in
            !codeBlocks.contains { NSLocationInRange(match.location, $0) }
        }

        func each(_ regex: NSRegularExpression, _ body: (NSTextCheckingResult) -> Void) {
            regex.enumerateMatches(in: string, range: range) { match, _, _ in
                if let match, isOutsideCode(match.range) { body(match) }
            }
        }
        func color(_ color: NSColor, _ range: NSRange) {
            if range.location != NSNotFound, range.length > 0 { storage.addAttribute(.foregroundColor, value: color, range: range) }
        }
        func closingMarker(of match: NSTextCheckingResult, length: Int) -> NSRange {
            NSRange(location: NSMaxRange(match.range) - length, length: length)
        }

        each(Patterns.heading) { m in
            storage.addAttribute(.font, value: style.boldFont, range: m.range)
            color(Theme.faint, m.range(at: 1))
        }
        each(Patterns.quote) { m in
            color(Theme.muted, m.range)
            color(Theme.faint, m.range(at: 1))
        }
        each(Patterns.list) { m in
            color(Theme.accent, m.range(at: 1))
            color(Theme.muted, m.range(at: 2))
        }
        each(Patterns.rule) { m in color(Theme.faint, m.range) }
        each(Patterns.bareURL) { m in color(Theme.accent, m.range) }
        each(Patterns.bold) { m in
            storage.addAttribute(.font, value: style.boldFont, range: m.range)
            color(Theme.faint, m.range(at: 1))
            color(Theme.faint, closingMarker(of: m, length: m.range(at: 1).length))
        }
        each(Patterns.italic) { m in
            storage.addAttribute(.font, value: style.italicFont, range: m.range(at: 2))
            color(Theme.faint, m.range(at: 1))
            color(Theme.faint, closingMarker(of: m, length: 1))
        }
        each(Patterns.strike) { m in
            storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: m.range(at: 2))
            color(Theme.muted, m.range(at: 2))
            color(Theme.faint, m.range(at: 1))
            color(Theme.faint, closingMarker(of: m, length: 2))
        }
        each(Patterns.link) { m in
            color(Theme.faint, m.range)
            color(Theme.accent, m.range(at: 2))
        }
        each(Patterns.codeSpan) { m in
            storage.addAttributes([.font: style.font, .foregroundColor: Theme.text,
                                   .backgroundColor: Theme.codeBackground], range: m.range(at: 2))
            color(Theme.faint, m.range(at: 1))
            color(Theme.faint, closingMarker(of: m, length: m.range(at: 1).length))
        }

        for block in codeBlocks {
            let visible = NSIntersectionRange(block, range)
            storage.addAttributes([.font: style.font, .foregroundColor: Theme.muted], range: visible)
        }
    }

    // MARK: - Blocos de código cercados

    /// Varredura linear das linhas que abrem ou fecham ``` e ~~~. Bloco sem fechamento vai até o fim.
    static func findFences(in string: NSString) -> [NSRange] {
        var result: [NSRange] = []
        var open: (start: Int, marker: unichar)?
        var lineStart = 0
        let length = string.length

        while lineStart < length {
            var lineEnd = 0
            var contentsEnd = 0
            string.getLineStart(nil, end: &lineEnd, contentsEnd: &contentsEnd, for: NSRange(location: lineStart, length: 0))

            var index = lineStart
            while index < contentsEnd, index - lineStart < 4, string.character(at: index) == 32 { index += 1 }
            if index - lineStart < 4, index + 2 < contentsEnd {
                let marker = string.character(at: index)
                if marker == 96 || marker == 126,
                   string.character(at: index + 1) == marker, string.character(at: index + 2) == marker {
                    if let current = open {
                        if current.marker == marker {
                            result.append(NSRange(location: current.start, length: lineEnd - current.start))
                            open = nil
                        }
                    } else {
                        open = (lineStart, marker)
                    }
                }
            }
            lineStart = lineEnd
        }
        if let current = open {
            result.append(NSRange(location: current.start, length: length - current.start))
        }
        return result
    }

    /// Onde um bloco antigo deveria estar depois da edição, se a estrutura não mudou.
    private static func shift(_ block: NSRange, by edited: NSRange, delta: Int) -> NSRange {
        let oldEnd = edited.location + edited.length - delta
        if block.location >= oldEnd {
            return NSRange(location: block.location + delta, length: block.length)
        }
        if block.location <= edited.location, oldEnd <= NSMaxRange(block) {
            return NSRange(location: block.location, length: block.length + delta)
        }
        return block
    }
}

private enum Patterns {
    static let heading = regex(#"^(#{1,6})[ \t]+.*$"#)
    static let quote = regex(#"^[ \t]*(>+).*$"#)
    static let list = regex(#"^[ \t]*([-*+]|\d{1,9}[.)])[ \t]+(\[[ xX]\][ \t])?"#)
    static let rule = regex(#"^[ \t]{0,3}([-*_])([ \t]*\1){2,}[ \t]*$"#)
    static let bold = regex(#"(\*\*|__)(?=\S)(.+?)(?<=\S)\1"#)
    static let italic = regex(#"(?<![*_\w])([*_])(?=[^\s*_])(.+?)(?<=[^\s*_])\1(?![*_\w])"#)
    static let strike = regex(#"(~~)(?=\S)(.+?)(?<=\S)~~"#)
    static let link = regex(#"(!?\[)([^\]\n]*)(\]\()([^)\n]*)(\))"#)
    static let bareURL = regex(#"<?https?://[^\s<>()]+>?"#)
    static let codeSpan = regex(#"(`+)([^`\n]+?)\1"#)

    private static func regex(_ pattern: String) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
    }
}

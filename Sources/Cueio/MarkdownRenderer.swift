import Foundation
import cmark_gfm
import cmark_gfm_extensions

enum MarkdownRenderer {
    private static let extensions = ["table", "strikethrough", "autolink", "tasklist", "tagfilter"]
    // Quebra simples vira <br>, como o `breaks: true` da 0.1. Sem CMARK_OPT_UNSAFE: HTML cru e
    // links javascript: ficam de fora, então o preview não precisa de sanitização extra.
    private static let options = CMARK_OPT_HARDBREAKS | CMARK_OPT_FOOTNOTES

    static func html(from markdown: String) -> String {
        cmark_gfm_core_extensions_ensure_registered()
        guard let parser = cmark_parser_new(options) else { return "" }
        defer { cmark_parser_free(parser) }

        for name in extensions {
            if let ext = cmark_find_syntax_extension(name) {
                cmark_parser_attach_syntax_extension(parser, ext)
            }
        }
        markdown.withCString { cmark_parser_feed(parser, $0, strlen($0)) }

        guard let root = cmark_parser_finish(parser) else { return "" }
        defer { cmark_node_free(root) }
        guard let rendered = cmark_render_html(root, options, cmark_parser_get_syntax_extensions(parser)) else { return "" }
        defer { free(rendered) }
        return addingHeadingIDs(to: String(cString: rendered))
    }

    /// Slug no padrão do GitHub: minúsculas, só letras, números, `-` e `_`, espaços viram `-`.
    /// Assim links como `[x](#minha-seção)` escritos para o GitHub funcionam aqui também.
    static func slug(_ text: String) -> String {
        var slug = ""
        for scalar in text.lowercased().unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) || scalar == "-" || scalar == "_" {
                slug.unicodeScalars.append(scalar)
            } else if scalar == " " {
                slug.append("-")
            }
        }
        return slug
    }

    private static let headingPattern = try! NSRegularExpression(pattern: "<h([1-6])>(.*?)</h\\1>",
                                                                 options: .dotMatchesLineSeparators)
    private static let tagPattern = try! NSRegularExpression(pattern: "<[^>]+>")

    /// O cmark não gera `id` nos títulos; sem isso as âncoras internas não têm destino.
    private static func addingHeadingIDs(to html: String) -> String {
        let source = html as NSString
        var used: [String: Int] = [:]
        // Títulos repetidos ganham -1, -2… na ordem do documento, como no GitHub.
        let insertions: [(location: Int, id: String)] = headingPattern
            .matches(in: html, range: NSRange(location: 0, length: source.length))
            .compactMap { match in
                let inner = source.substring(with: match.range(at: 2))
                let text = tagPattern.stringByReplacingMatches(in: inner, range: NSRange(location: 0, length: (inner as NSString).length),
                                                               withTemplate: "")
                let base = slug(decodingEntities(text))
                guard !base.isEmpty else { return nil }
                let count = used[base, default: 0]
                used[base] = count + 1
                return (match.range(at: 1).upperBound, count == 0 ? base : "\(base)-\(count)")
            }
        let result = NSMutableString(string: html)
        // De trás para frente, para as inserções não deslocarem as posições que faltam.
        for insertion in insertions.reversed() {
            result.insert(" id=\"\(insertion.id)\"", at: insertion.location)
        }
        return result as String
    }

    private static func decodingEntities(_ text: String) -> String {
        text.replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
}

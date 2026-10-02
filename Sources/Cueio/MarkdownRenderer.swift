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
        return String(cString: rendered)
    }
}

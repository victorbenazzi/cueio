import AppKit
import WebKit

/// Preview de markdown. Só é criado quando o usuário abre o preview pela primeira vez,
/// então quem só edita texto nunca paga o custo do WebKit.
final class PreviewView: NSView, WKNavigationDelegate {
    let webView: WKWebView

    override init(frame frameRect: NSRect) {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(frame: frameRect)

        webView.navigationDelegate = self
        webView.setValue(false, forKey: "drawsBackground")
        webView.underPageBackgroundColor = Theme.background
        webView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) não é usado") }

    func render(markdown: String, baseURL: URL?) {
        let body = MarkdownRenderer.html(from: markdown)
        webView.loadHTMLString(PreviewTemplate.page(body: body), baseURL: baseURL)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        // Âncoras internas (notas de rodapé) rolam a página; o resto abre no app padrão.
        let page = webView.url?.absoluteString.split(separator: "#").first
        if url.fragment != nil, url.absoluteString.split(separator: "#").first == page {
            decisionHandler(.allow)
            return
        }
        NSWorkspace.shared.open(url)
        decisionHandler(.cancel)
    }
}

enum PreviewTemplate {
    static func page(body: String) -> String {
        """
        <!doctype html>
        <html lang="pt-BR">
        <head>
        <meta charset="utf-8">
        <meta name="color-scheme" content="light dark">
        <style>\(css)</style>
        </head>
        <body><article>\(body)</article></body>
        </html>
        """
    }

    private static let css = """
    :root {
      --bg: #fafafa; --text: #1f1f1f; --muted: #737373; --line: #e5e5e5;
      --accent: #0969da; --code-bg: #f1f1f1; --table-alt: rgba(127,127,127,.04);
      --mono: ui-monospace, "SF Mono", Menlo, monospace;
    }
    @media (prefers-color-scheme: dark) {
      :root { --bg: #111; --text: #ededed; --muted: #a3a3a3; --line: #2b2b2b;
              --accent: #58a6ff; --code-bg: #1c1c1c; --table-alt: rgba(255,255,255,.025); }
    }
    html { background: var(--bg); }
    body {
      margin: 0; color: var(--text); background: var(--bg);
      font: 14px/1.6 -apple-system, "SF Pro Text", system-ui, sans-serif;
      -webkit-font-smoothing: antialiased; text-rendering: optimizeLegibility;
    }
    article { max-width: 680px; margin: 0 auto; padding: 18px 24px 64px; overflow-wrap: break-word; }
    article > :first-child { margin-top: 0 !important; }
    h1, h2, h3, h4, h5, h6 { margin: 28px 0 14px; font-weight: 600; line-height: 1.25; letter-spacing: -.015em; }
    h1 { font-size: 2em; } h2 { font-size: 1.5em; } h3 { font-size: 1.25em; }
    h4 { font-size: 1em; } h5 { font-size: .875em; } h6 { font-size: .85em; color: var(--muted); }
    h1, h2 { padding-bottom: .3em; border-bottom: 1px solid var(--line); }
    p, blockquote, ul, ol, dl, table, pre, details { margin: 0 0 16px; }
    ul, ol { padding-left: 2em; }
    li + li { margin-top: .25em; }
    li > p { margin-top: 16px; }
    li:has(> input[type=checkbox]) { list-style: none; margin-left: -1.4em; }
    input[type=checkbox] { margin: 0 .5em 0 0; vertical-align: middle; }
    a { color: var(--accent); text-decoration: none; }
    a:hover { text-decoration: underline; text-underline-offset: 2px; }
    strong { font-weight: 600; }
    blockquote { margin-left: 0; padding: 0 1em; color: var(--muted); border-left: 3px solid var(--line); }
    hr { height: 1px; margin: 24px 0; border: 0; background: var(--line); }
    code, kbd, pre { font-family: var(--mono); }
    code { padding: .2em .4em; font-size: .85em; border-radius: 5px; background: var(--code-bg); }
    pre { padding: 14px 16px; overflow: auto; font-size: .85em; line-height: 1.5; border-radius: 8px; background: var(--code-bg); }
    pre code { padding: 0; font-size: inherit; background: none; }
    table { display: block; width: max-content; max-width: 100%; overflow: auto; border-collapse: collapse; }
    th, td { padding: 6px 13px; border: 1px solid var(--line); }
    th { font-weight: 600; }
    tr:nth-child(2n) { background: var(--table-alt); }
    img { max-width: 100%; }
    .footnotes { margin-top: 32px; font-size: .9em; color: var(--muted); }
    """
}

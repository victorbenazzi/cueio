import AppKit
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    /// Tag do item "Última aba" no menu Janela (⌘9).
    static let lastTabTag = 9

    func applicationWillFinishLaunching(_ notification: Notification) {
        // O controller padrão precisa existir antes do launch para abrir arquivos vindos do Finder.
        _ = NSDocumentController.shared
        NSWindow.allowsAutomaticWindowTabbing = true
        NSApp.mainMenu = MainMenu.build()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    /// Botão "+" da barra de abas e ⌘T.
    @objc func newWindowForTab(_ sender: Any?) {
        NSDocumentController.shared.newDocument(sender)
    }

    /// Registra o cueio como app padrão para markdown e texto. O macOS pode pedir confirmação.
    @objc func makeDefaultApp(_ sender: Any?) {
        Task { @MainActor in
            let alert = NSAlert()
            do {
                for type in [UTType.markdownText, .plainText] {
                    try await NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpen: type)
                }
                alert.messageText = "O cueio agora é o app padrão"
                alert.informativeText = "Arquivos .md e .txt vão abrir no cueio. Markdown abre direto no preview."
            } catch {
                alert.alertStyle = .warning
                alert.messageText = "Não foi possível definir o app padrão"
                alert.informativeText = error.localizedDescription
            }
            alert.runModal()
        }
    }

    /// ⌘1 a ⌘8 escolhem a aba pela posição e ⌘9 vai para a última, como nos navegadores.
    @objc func selectTab(_ sender: NSMenuItem) {
        guard let target = tab(for: sender.tag) else { return }
        if let group = target.tabGroup { group.selectedWindow = target } else { target.makeKeyAndOrderFront(nil) }
    }

    private func tab(for tag: Int) -> NSWindow? {
        guard let window = NSApp.keyWindow, window.windowController is DocumentWindowController else { return nil }
        let tabs = window.tabbedWindows ?? [window]
        if tag == Self.lastTabTag { return tabs.last }
        return tabs.indices.contains(tag - 1) ? tabs[tag - 1] : nil
    }

    @objc func toggleFocusMode(_ sender: Any?) { Settings.shared.focusMode.toggle() }
    @objc func increaseFontSize(_ sender: Any?) { Settings.shared.fontSize += 1 }
    @objc func decreaseFontSize(_ sender: Any?) { Settings.shared.fontSize -= 1 }
    @objc func resetFontSize(_ sender: Any?) { Settings.shared.fontSize = Settings.defaultFontSize }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(toggleFocusMode(_:)):
            item.state = Settings.shared.focusMode ? .on : .off
            return true
        case #selector(selectTab(_:)):
            return tab(for: item.tag) != nil
        default:
            return true
        }
    }
}

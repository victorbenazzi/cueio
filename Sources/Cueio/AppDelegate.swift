import AppKit
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private var keyMonitor: Any?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // O controller padrão precisa existir antes do launch para abrir arquivos vindos do Finder.
        _ = NSDocumentController.shared
        NSWindow.allowsAutomaticWindowTabbing = true
        NSApp.mainMenu = MainMenu.build()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            Self.selectTab(for: event) ? nil : event
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    /// Botão "+" da barra de abas e ⌘T.
    @objc func newWindowForTab(_ sender: Any?) {
        NSDocumentController.shared.newDocument(sender)
    }

    /// Registra o cueio como app padrão para markdown e texto. O macOS pode pedir confirmação.
    @objc func makeDefaultApp(_ sender: Any?) {
        let types: [UTType] = [.markdownText, .plainText]
        let group = DispatchGroup()
        var failures: [String] = []
        for type in types {
            group.enter()
            NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpen: type) { error in
                DispatchQueue.main.async {
                    if let error { failures.append(error.localizedDescription) }
                    group.leave()
                }
            }
        }
        group.notify(queue: .main) {
            let alert = NSAlert()
            if failures.isEmpty {
                alert.messageText = "O cueio agora é o app padrão"
                alert.informativeText = "Arquivos .md e .txt vão abrir no cueio. Markdown abre direto no preview."
            } else {
                alert.alertStyle = .warning
                alert.messageText = "Não foi possível definir o app padrão"
                alert.informativeText = failures.joined(separator: "\n")
            }
            alert.runModal()
        }
    }

    @objc func toggleFocusMode(_ sender: Any?) { Settings.shared.focusMode.toggle() }
    @objc func increaseFontSize(_ sender: Any?) { Settings.shared.fontSize += 1 }
    @objc func decreaseFontSize(_ sender: Any?) { Settings.shared.fontSize -= 1 }
    @objc func resetFontSize(_ sender: Any?) { Settings.shared.fontSize = Settings.defaultFontSize }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        if item.action == #selector(toggleFocusMode(_:)) {
            item.state = Settings.shared.focusMode ? .on : .off
        }
        return true
    }

    /// ⌘1 a ⌘8 escolhem a aba pela posição e ⌘9 vai para a última, como nos navegadores.
    private static func selectTab(for event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
              let key = event.charactersIgnoringModifiers, let index = Int(key), (1...9).contains(index),
              let window = NSApp.keyWindow, window.windowController is DocumentWindowController
        else { return false }

        let tabs = window.tabbedWindows ?? [window]
        let target = index == 9 ? tabs.last : (index <= tabs.count ? tabs[index - 1] : nil)
        if let target {
            if let group = window.tabGroup { group.selectedWindow = target } else { target.makeKeyAndOrderFront(nil) }
        }
        return true
    }
}

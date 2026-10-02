import AppKit

enum MainMenu {
    static func build() -> NSMenu {
        let main = NSMenu()
        main.addItem(submenu(appMenu()))
        main.addItem(submenu(fileMenu()))
        main.addItem(submenu(editMenu()))
        main.addItem(submenu(viewMenu()))
        let window = windowMenu()
        main.addItem(submenu(window))
        NSApp.windowsMenu = window
        return main
    }

    private static func appMenu() -> NSMenu {
        let menu = NSMenu(title: "cueio")
        menu.addItem(item("Sobre o cueio", #selector(NSApplication.orderFrontStandardAboutPanel(_:))))
        menu.addItem(item("Tornar cueio o app padrão…", #selector(AppDelegate.makeDefaultApp(_:))))
        menu.addItem(.separator())
        let services = NSMenu(title: "Serviços")
        let servicesItem = NSMenuItem(title: "Serviços", action: nil, keyEquivalent: "")
        servicesItem.submenu = services
        NSApp.servicesMenu = services
        menu.addItem(servicesItem)
        menu.addItem(.separator())
        menu.addItem(item("Ocultar cueio", #selector(NSApplication.hide(_:)), "h"))
        menu.addItem(item("Ocultar outros", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option]))
        menu.addItem(item("Mostrar todos", #selector(NSApplication.unhideAllApplications(_:))))
        menu.addItem(.separator())
        menu.addItem(item("Encerrar cueio", #selector(NSApplication.terminate(_:)), "q"))
        return menu
    }

    private static func fileMenu() -> NSMenu {
        let menu = NSMenu(title: "Arquivo")
        menu.addItem(item("Novo", #selector(NSDocumentController.newDocument(_:)), "n"))
        menu.addItem(item("Nova aba", #selector(AppDelegate.newWindowForTab(_:)), "t"))
        menu.addItem(item("Abrir…", #selector(NSDocumentController.openDocument(_:)), "o"))

        // O AppKit preenche este submenu sozinho ao encontrar o item "clearRecentDocuments:".
        let recent = NSMenu(title: "Abrir recente")
        recent.addItem(item("Limpar menu", #selector(NSDocumentController.clearRecentDocuments(_:))))
        let recentItem = NSMenuItem(title: "Abrir recente", action: nil, keyEquivalent: "")
        recentItem.submenu = recent
        menu.addItem(recentItem)

        menu.addItem(.separator())
        menu.addItem(item("Fechar", #selector(NSWindow.performClose(_:)), "w"))
        menu.addItem(item("Salvar…", #selector(NSDocument.save(_:)), "s"))
        menu.addItem(item("Duplicar", #selector(NSDocument.duplicate(_:)), "s", [.command, .shift]))
        menu.addItem(item("Salvar como…", #selector(NSDocument.saveAs(_:)), "s", [.command, .shift, .option]))
        menu.addItem(item("Renomear…", #selector(NSDocument.rename(_:))))
        menu.addItem(item("Mover para…", #selector(NSDocument.move(_:))))
        menu.addItem(item("Reverter para a versão salva", #selector(NSDocument.revertToSaved(_:))))
        return menu
    }

    private static func editMenu() -> NSMenu {
        let menu = NSMenu(title: "Editar")
        menu.addItem(item("Desfazer", Selector(("undo:")), "z"))
        menu.addItem(item("Refazer", Selector(("redo:")), "z", [.command, .shift]))
        menu.addItem(.separator())
        menu.addItem(item("Recortar", #selector(NSText.cut(_:)), "x"))
        menu.addItem(item("Copiar", #selector(NSText.copy(_:)), "c"))
        menu.addItem(item("Colar", #selector(NSText.paste(_:)), "v"))
        menu.addItem(item("Selecionar tudo", #selector(NSText.selectAll(_:)), "a"))
        menu.addItem(.separator())

        let find = NSMenu(title: "Buscar")
        find.addItem(findItem("Buscar…", .showFindInterface, "f"))
        find.addItem(findItem("Buscar e substituir…", .showReplaceInterface, "f", [.command, .option]))
        find.addItem(findItem("Buscar seguinte", .nextMatch, "g"))
        find.addItem(findItem("Buscar anterior", .previousMatch, "g", [.command, .shift]))
        find.addItem(findItem("Usar seleção para buscar", .setSearchString, "e"))
        find.addItem(item("Ir para a seleção", #selector(NSTextView.centerSelectionInVisibleArea(_:)), "j"))
        menu.addItem(submenu(find))

        let spelling = NSMenu(title: "Ortografia e gramática")
        spelling.addItem(item("Mostrar ortografia e gramática", #selector(NSText.showGuessPanel(_:)), ":"))
        spelling.addItem(item("Verificar documento agora", #selector(NSText.checkSpelling(_:)), ";"))
        spelling.addItem(item("Verificar ortografia ao digitar", #selector(NSTextView.toggleContinuousSpellChecking(_:))))
        menu.addItem(submenu(spelling))
        return menu
    }

    private static func viewMenu() -> NSMenu {
        let menu = NSMenu(title: "Visualizar")
        menu.addItem(item("Visualizar markdown", #selector(DocumentWindowController.toggleMarkdownPreview(_:)), "p", [.command, .shift]))
        menu.addItem(item("Modo foco", #selector(AppDelegate.toggleFocusMode(_:)), "f", [.command, .shift]))
        menu.addItem(.separator())
        menu.addItem(item("Aumentar texto", #selector(AppDelegate.increaseFontSize(_:)), "="))
        menu.addItem(item("Diminuir texto", #selector(AppDelegate.decreaseFontSize(_:)), "-"))
        menu.addItem(item("Tamanho real", #selector(AppDelegate.resetFontSize(_:)), "0"))
        menu.addItem(.separator())
        menu.addItem(item("Mostrar barra de abas", #selector(NSWindow.toggleTabBar(_:))))
        menu.addItem(item("Mostrar todas as abas", #selector(NSWindow.toggleTabOverview(_:)), "\\", [.command, .shift]))
        menu.addItem(item("Entrar em tela cheia", #selector(NSWindow.toggleFullScreen(_:)), "f", [.command, .control]))
        return menu
    }

    private static func windowMenu() -> NSMenu {
        let menu = NSMenu(title: "Janela")
        menu.addItem(item("Minimizar", #selector(NSWindow.performMiniaturize(_:)), "m"))
        menu.addItem(item("Zoom", #selector(NSWindow.performZoom(_:))))
        menu.addItem(.separator())
        let tabs = NSMenu(title: "Ir para aba")
        for number in 1...AppDelegate.lastTabTag {
            let title = number == AppDelegate.lastTabTag ? "Última aba" : "Aba \(number)"
            let tabItem = item(title, #selector(AppDelegate.selectTab(_:)), "\(number)")
            tabItem.tag = number
            tabs.addItem(tabItem)
        }
        menu.addItem(submenu(tabs))
        menu.addItem(.separator())
        menu.addItem(item("Trazer tudo para a frente", #selector(NSApplication.arrangeInFront(_:))))
        return menu
    }

    private static func submenu(_ menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: menu.title, action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }

    private static func item(_ title: String, _ action: Selector?, _ key: String = "",
                             _ modifiers: NSEvent.ModifierFlags = .command) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        return item
    }

    private static func findItem(_ title: String, _ action: NSTextFinder.Action, _ key: String,
                                 _ modifiers: NSEvent.ModifierFlags = .command) -> NSMenuItem {
        let item = self.item(title, #selector(NSResponder.performTextFinderAction(_:)), key, modifiers)
        item.tag = action.rawValue
        return item
    }
}

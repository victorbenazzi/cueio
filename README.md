<p align="center">
  <img src="docs/icon.png" width="128" height="128" alt="Ícone do cueio">
</p>

<h1 align="center">cueio</h1>

<p align="center">Editor de texto e markdown para macOS. Leve, rápido e nativo.</p>

---

O cueio abre, edita e visualiza arquivos `.md` e `.txt` sem distração. É escrito em Swift com AppKit: abre na hora, usa cerca de 24 MB de memória e aproveita o que o macOS já oferece, como abas, autosave, versões, corretor, ditado e Writing Tools.

## Recursos

- **Abas nativas**: ⌘T ou ⌘N para nova, ⌘W para fechar, ⌃Tab para alternar e ⌘1...⌘9 para pular direto.
- **Autosave**: tudo é salvo sozinho. Rascunhos e abas voltam como estavam ao reabrir o app.
- **Realce de markdown** no editor: títulos, ênfase, listas, links e código, sem sair do texto puro.
- **Preview** (⇧⌘P) com GitHub Flavored Markdown: tabelas, tarefas, tachado e notas de rodapé. Arquivos `.md` abrem direto no preview.
- **Modo foco** (⇧⌘F): esconde as barras e centraliza o texto numa coluna de leitura.
- **Tamanho do texto**: ⌘=, ⌘- e ⌘0.
- **App padrão**: o menu "Tornar cueio o app padrão…" associa `.md` e `.txt` ao cueio.
- Tema claro e escuro, menus em português.

## Instalação

Requer macOS 14 ou superior e as Command Line Tools (`xcode-select --install`). O Xcode não é necessário.

```bash
git clone https://github.com/victorbenazzi/cueio.git
cd cueio
./scripts/build.sh
cp -R build/cueio.app /Applications/
```

O app é assinado localmente (ad-hoc), então roda na máquina onde foi compilado.

## Estrutura

| Arquivo | Papel |
| --- | --- |
| `Document.swift` | NSDocument: leitura, escrita, autosave, estado restaurável |
| `DocumentWindowController.swift` | janela, toolbar, modos, modo foco, status |
| `MarkdownHighlighter.swift` | realce incremental no NSTextStorage |
| `MarkdownRenderer.swift` | markdown para HTML com [cmark-gfm](https://github.com/apple/swift-cmark) |
| `PreviewView.swift` | WKWebView do preview, criado só quando usado |
| `MainMenu.swift` | menus em português |

## História

A versão 0.1 foi feita em Tauri + React e o código-fonte se perdeu. A 0.2 é uma reescrita nativa baseada no que foi recuperado do app instalado. Veja [docs/v0.1.md](docs/v0.1.md).

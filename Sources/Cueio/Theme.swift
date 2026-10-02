import AppKit
import UniformTypeIdentifiers

/// Paleta herdada da versão 0.1 (tokens do CSS original), resolvida para claro e escuro.
enum Theme {
    static let background = dynamic(light: 0xFAFAFA, dark: 0x111111)
    static let text = dynamic(light: 0x1F1F1F, dark: 0xEDEDED)
    static let muted = dynamic(light: 0x737373, dark: 0xA3A3A3)
    static let faint = dynamic(light: 0xA3A3A3, dark: 0x666666)
    static let line = dynamic(light: 0xE5E5E5, dark: 0x2B2B2B)
    static let accent = dynamic(light: 0x0969DA, dark: 0x58A6FF)
    static let codeBackground = NSColor(name: nil) { appearance in
        isDark(appearance) ? NSColor(white: 1, alpha: 0.06) : NSColor(white: 0, alpha: 0.045)
    }

    private static func dynamic(light: UInt32, dark: UInt32) -> NSColor {
        NSColor(name: nil) { appearance in color(isDark(appearance) ? dark : light) }
    }

    private static func isDark(_ appearance: NSAppearance) -> Bool {
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private static func color(_ hex: UInt32) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1)
    }
}

extension UTType {
    static let markdownText = UTType(importedAs: "net.daringfireball.markdown", conformingTo: .plainText)
}

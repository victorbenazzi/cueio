import Foundation

/// Preferências globais. Cada mudança tem a própria notificação e vale para todas as janelas.
final class Settings {
    static let shared = Settings()
    static let fontSizeDidChange = Notification.Name("CueioFontSizeDidChange")
    static let focusModeDidChange = Notification.Name("CueioFocusModeDidChange")
    static let defaultFontSize: CGFloat = 13

    private let defaults = UserDefaults.standard

    var fontSize: CGFloat {
        get {
            let stored = defaults.double(forKey: "editorFontSize")
            return stored > 0 ? stored : Self.defaultFontSize
        }
        set {
            defaults.set(min(max(newValue, 10), 28), forKey: "editorFontSize")
            NotificationCenter.default.post(name: Self.fontSizeDidChange, object: nil)
        }
    }

    var focusMode: Bool {
        get { defaults.bool(forKey: "focusMode") }
        set {
            defaults.set(newValue, forKey: "focusMode")
            NotificationCenter.default.post(name: Self.focusModeDidChange, object: nil)
        }
    }
}

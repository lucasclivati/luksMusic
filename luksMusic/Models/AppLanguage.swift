// AppLanguage.swift
// luksMusic
//
// The app's language: Portuguese or English, chosen in Ajustes or following the device. The choice is stored as
// the app's AppleLanguages, which iOS reads when the app starts, so it applies the next time the app opens. The
// texts are the Portuguese strings in the code, translated in en.lproj/Localizable.strings.

import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    /// The device's language (English for any language other than Portuguese)
    case system
    case portuguese = "pt-BR"
    case english = "en"

    var id: String { rawValue }

    /// Each language is named in itself, so anyone can find theirs
    var displayName: String {
        switch self {
        case .system: return String(localized: "Idioma do aparelho")
        case .portuguese: return "Português"
        case .english: return "English"
        }
    }

    private static let choiceKey = "appLanguage"
    private static let appleLanguagesKey = "AppleLanguages"

    /// The choice made in Ajustes
    static var chosen: AppLanguage {
        get { AppLanguage(rawValue: UserDefaults.standard.string(forKey: choiceKey) ?? "") ?? .system }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: choiceKey)
            if newValue == .system {
                UserDefaults.standard.removeObject(forKey: appleLanguagesKey)
            } else {
                UserDefaults.standard.set([newValue.rawValue], forKey: appleLanguagesKey)
            }
        }
    }

    /// The language the app is showing now (the one iOS picked when it started)
    static var current: AppLanguage {
        Bundle.main.preferredLocalizations.first?.hasPrefix("pt") == true ? .portuguese : .english
    }
}

import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system, en, it, fr, de, pl, es, pt, ro
    case zhHans = "zh-hans"

    var id: String { rawValue }

    var nativeName: String {
        switch self {
        case .system: return "System Language"
        case .en: return "English"
        case .it: return "Italiano"
        case .fr: return "Français"
        case .de: return "Deutsch"
        case .pl: return "Polski"
        case .es: return "Español"
        case .pt: return "Português"
        case .ro: return "Română"
        case .zhHans: return "简体中文"
        }
    }

    fileprivate var localeCode: String? {
        self == .system ? nil : rawValue
    }
}

enum Localization {
    static let appLanguageDefaultsKey = "appLanguage"

    static var currentLanguage: AppLanguage {
        let raw = UserDefaults.standard.string(forKey: appLanguageDefaultsKey) ?? AppLanguage.system.rawValue
        return AppLanguage(rawValue: raw) ?? .system
    }

    private static func resolvedCode() -> String {
        if let code = currentLanguage.localeCode { return code }
        let supported = AppLanguage.allCases.compactMap(\.localeCode)
        return Bundle.preferredLocalizations(from: supported, forPreferences: Locale.preferredLanguages).first ?? "en"
    }

    private static func resourceRootBundle() -> Bundle {
        // Packaged .app: SwiftPM's resource bundle is copied under Contents/Resources
        // by Scripts/build_app.sh, matching the standard macOS bundle layout.
        if let resourcesURL = Bundle.main.resourceURL {
            let candidate = resourcesURL.appendingPathComponent("PingSentry_PingSentry.bundle")
            if let bundle = Bundle(url: candidate) { return bundle }
        }
        // `swift run`/`swift test`: SwiftPM's generated Bundle.module accessor
        // already knows how to find its own build-directory resource bundle.
        return Bundle.module
    }

    private static func languageBundle() -> Bundle {
        let code = resolvedCode()
        let root = resourceRootBundle()
        guard let path = root.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return root
        }
        return bundle
    }

    static func tr(_ key: String, args: [CVarArg] = []) -> String {
        let template = languageBundle().localizedString(forKey: key, value: key, table: nil)
        return args.isEmpty ? template : String(format: template, arguments: args)
    }
}

func L(_ key: String, _ args: CVarArg...) -> String {
    Localization.tr(key, args: args)
}

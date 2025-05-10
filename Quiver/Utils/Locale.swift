//
//  Created by Nupzil on 2025/5/9.
//
//  Copyright © 2025 Nupzil <vvgvjks@gmail.com>.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice
//  (including the next paragraph) shall be included in all copies or substantial
//  portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF
//  ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
//  EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
//  OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import SwiftUI

private let defaultLocale: LocaleManager.Locale = {
    let code = SwiftUI.Locale.preferredLanguages.first ?? "en"
    let shortCode = SwiftUI.Locale(identifier: code).identifier

    if shortCode.starts(with: "zh") {
        return .zhHans
    }
    return .en
}()

@Observable
public final class LocaleManager {
    public enum Locale: String, CaseIterable {
        case en
        case zhHans = "zh-Hans"

        public var locale: SwiftUI.Locale {
            SwiftUI.Locale(identifier: rawValue)
        }

        public var displayName: String {
            switch self {
            case .en:
                return "English"
            case .zhHans:
                return "简体中文"
            }
        }
    }

    public static let shared = LocaleManager()

    public var currentLocale: Locale = defaultLocale

    public var toggleButtonText: String {
        currentLocale == .en ? "简体中文" : "English"
    }

    public func toggle() {
        currentLocale = (currentLocale == .en) ? .zhHans : .en
        Bundle.setLanguage(currentLocale.locale)
    }

    public func changeLanguage(to language: Locale) {
        currentLocale = language
        Bundle.setLanguage(language.locale)
    }

    public func swizzleLocalization() {
        Bundle.swizzleLocalization()
    }
}

/// swizzling 比较危险，这里的方法应该只在 DEBUG 环境使用。
private extension Bundle {
    private static var currentLanguageBundle: Bundle?
    private static var originalLocalizedStringMethod: Method?

    static func setLanguage(_ language: Locale) {
        guard let path = Bundle.main.path(forResource: language.identifier, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else {
            return
        }
        Bundle.currentLanguageBundle = bundle
    }

    @objc func swizzled_localizedString(forKey key: String, value: String?, table: String?) -> String {
        guard let currentLanguageBundle = Bundle.currentLanguageBundle else {
            return swizzled_localizedString(forKey: key, value: value, table: table)
        }

        return currentLanguageBundle.swizzled_localizedString(forKey: key, value: value, table: table)
    }

    static func swizzleLocalization() {
        let originalSelector = #selector(localizedString(forKey:value:table:))
        let swizzledSelector = #selector(Bundle.swizzled_localizedString(forKey:value:table:))

        guard let originalMethod = class_getInstanceMethod(self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)
        else {
            return
        }

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
}

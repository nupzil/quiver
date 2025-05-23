//
//  Created by Nupzil on 2025/5/1.
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

import Foundation

private func retrieveInfoDictionaryValue(_ key: String, _ defaultValue: String) -> String {
    return Bundle.main.object(forInfoDictionaryKey: key) as? String ?? defaultValue
}

enum AppInfo {
    static let appName = retrieveInfoDictionaryValue("CFBundleName", "Quiver")
    static let version = retrieveInfoDictionaryValue("CFBundleShortVersionString", "1.0.0")
    static let buildNumber = retrieveInfoDictionaryValue("CFBundleVersion", "Unknown")
    static let repositoryURL = retrieveInfoDictionaryValue("CFBundleRepositoryURL", "https://github.com/nupzil/quiver")
    static let releasePageURL = "https://github.com/nupzil/quiver/releases"
    static let releasesAPIEndpoint = "https://api.github.com/repos/nupzil/quiver/releases/latest"
    static let currentYear = Calendar.current.component(.year, from: Date())
    static let developerName = retrieveInfoDictionaryValue("CFBundleDeveloper", "Nupzil")
}

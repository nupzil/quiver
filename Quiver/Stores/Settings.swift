//
//  Created by Nupzil on 2025/4/30.
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

@Observable
final class Settings {
    static let shared = Settings()
    
    public let maxLogFilesRetained = 50
    public let areNotificationsEnabled = true
    public let appLogsOutputDirectory = NSString(string: "~/.quiver/logs").expandingTildeInPath
    public let applicationDataDirectory = NSString(string: "~/.quiver").expandingTildeInPath
    public let configurationFilePath = NSString(string: "~/.quiver/configure.yml").expandingTildeInPath

    private let userDefaults = UserDefaults.standard
}

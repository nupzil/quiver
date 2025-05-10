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

import AppKit

func showInFinder(path: String) {
    let url = URL(fileURLWithPath: path)
    
    /// 在 Finder 中选择对应的文件，但是此时不会聚焦，Finder 窗口不会在最前
    NSWorkspace.shared.activateFileViewerSelecting([url])

    /// 聚焦 Finder 窗口
    let appleScript = """
    tell application "Finder"
        activate
        reveal POSIX file "\(path)"
    end tell
    """

    var error: NSDictionary?
    if let script = NSAppleScript(source: appleScript) {
        script.executeAndReturnError(&error)
        if let error = error {
            Logger.warning("Focus on the Finder window AppleScript error: \(error)")
        }
    }
}




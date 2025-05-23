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

func openInVscode(path: String){
    let process = Process()
    
    let defaultShell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/bash"
    
    let shellArguments: [String]
    if defaultShell.contains("zsh") {
        shellArguments = ["-i", "-c", "code \(path)"]
    } else {
        shellArguments = ["-c", "code \(path)"]
    }

    process.launchPath = defaultShell
    process.arguments = shellArguments
    
    process.terminationHandler = { process in
        if process.terminationStatus == 0 {
            Logger.info("Process completed successfully.")
        } else {
            Logger.warning("Process failed with status: \(process.terminationStatus)")
        }
    }
    
    process.launch()
}

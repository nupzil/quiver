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

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        LocaleManager.shared.swizzleLocalization()
        #endif
        ConfigManager.shared.ensureDefaultTemplate()
        CommandManager.shared.loadConfiguration()
        OutputFileService.shared.cleanupObsoleteFiles(commands: CommandManager.shared.commands)
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Task {
            await CommandRunner.shared.terminateAllProcesses()
            NSApplication.shared.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}

@main
struct QuiverApp: App {
    @Environment(\.openWindow) private var openWindow
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    #if DEBUG
    @State private var localeManager = LocaleManager.shared
    #endif
    
    @State private var commandManager = CommandManager.shared

    var body: some Scene {
        // 这是一个状态栏应用，默认不需要显示任何窗口。
        // 但 SwiftUI 会自动打开第一个窗口，需手动避免。
        // 常见的解决方案有两种：
        // 1. 将 `MenuBarExtra` 放在 Scene 的最前面；
        // 2. 使用 `.defaultLaunchBehavior(.suppressed)` 修饰符（仅支持 macOS 15 及以上）。

        MenuBarExtra {
            ForEach(self.commandManager.commands) { command in
                Button { self.commandManager.toggleCommand(command: command) } label: {
                    HStack {
                        if command.status == .running {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.green)
                                .symbolRenderingMode(.palette)
                        } else {
                            Image(systemName: "hourglass")
                                .font(.system(size: 8))
                        }
                        
                        Spacer()
                        Text(command.name)
                    }
                }
                .disabled(command.cancelled) /// cancelled 是一个中间状态，需要保证此时不能再操作按钮了。
                .help(command.status == .running ? "Click to stop service" : "Click to start service")
            }
            
            if !self.commandManager.commands.isEmpty {
                Divider()
            }
            
            Button("Show Config Folder") {
                showInFinder(path: Settings.shared.configurationFilePath)
            }
            
            Button("Reload Configuration") {
                self.commandManager.reloadConfiguration()
            }
            .disabled(self.commandManager.isRunning)
            .help(if: self.commandManager.isRunning, LocalizedStringKey("Stop all running commands first"))
            
            Button("Show Script Output Folder") {
                NSWorkspace.shared.open(URL(fileURLWithPath: Settings.shared.applicationDataDirectory))
            }
            
            Divider()
            
            Button("About \(AppInfo.appName)") {
                self.openWindow(id: AppWindow.about.rawValue)
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == AppWindow.about.rawValue }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }
            
            #if DEBUG
            Menu("Language") {
                Button(LocaleManager.Locale.en.displayName) {
                    self.localeManager.changeLanguage(to: .en)
                }
                .disabled(self.localeManager.currentLocale == .en)
                
                Button(LocaleManager.Locale.zhHans.displayName) {
                    self.localeManager.changeLanguage(to: .zhHans)
                }
                .disabled(self.localeManager.currentLocale == .zhHans)
            }
           
            #endif
            
            Button("Check for Updates") {
                Task { await UpdateService.shared.checkForUpdates() }
            }
            .disabled(UpdateService.shared.isUpdateCheckInProgress)
            
            Divider()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            if self.commandManager.isRunning == false {
                Image(systemName: "power")
            } else {
                Image(systemName: "power.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.primary, .green)
            }
        }
        #if DEBUG
        .environment(\.locale, self.localeManager.currentLocale.locale)
        #endif
        .menuBarExtraStyle(.menu)
        
        Window("About", id: AppWindow.about.rawValue) {
            AboutView()
        }
        #if DEBUG
        .environment(\.locale, self.localeManager.currentLocale.locale)
        #endif
        .windowStyle(.titleBar)
        .suppressLaunchIfAvailable()
        .windowResizability(.contentSize)
        .handlesExternalEvents(matching: Set(arrayLiteral: AppWindow.about.rawValue))
    }
}

extension View {
    @ViewBuilder
    func help(if condition: Bool, _ text: LocalizedStringKey) -> some View {
        if condition {
            self.help(text)
        } else {
            self
        }
    }
}

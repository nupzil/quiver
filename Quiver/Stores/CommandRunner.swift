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

import AppKit
import Foundation
import UserNotifications

private struct CommandExecutionContext {
    var process: Process
    var outputPipe: Pipe
    var fileHandle: FileHandle
}

/// Command Process 的关闭需要异步，因为 Command 可能有优雅关机之类的操作，可能不会立即关闭，避免阻塞主线程，需要切换到后台线程。
/// 因为内部只有两个可变的状态：isRunning、runningCommands 而isRunning 的修改依赖于 runningCommands 的变更，并且内部不会访问它，
/// 所以只需要包装 runningCommands 的操作就能达到线程安全。
@Observable
final class CommandRunner {
    static let shared = CommandRunner()
    
    private let settings: Settings
    private let outputService: OutputFileService
    
    /// 表示是否存在任何正在运行中的命令
    /// - 重要提示: 此属性必须在主线程上访问，否则可能导致不可预测的行为
    /// - 在非 UI 层代码中，请使用 isAnyCommandRunning() 方法访问此状态
    private(set) var isRunning = false
    
    private var runningCommands: [Command: CommandExecutionContext] = [:]

    /// 应该使用此方法而不是直接访问 isRunning 属性，除非你用于 UI 层，需要响应式的状态。
    func isAnyCommandRunning() -> Bool {
        if Thread.isMainThread {
            return isRunning
        } else {
            return DispatchQueue.main.sync { self.isRunning }
        }
    }
    
    private func appendRunningCommand(_ command: Command, _ context: CommandExecutionContext) {
        DispatchQueue.main.async {
            self.runningCommands[command] = context
            self.isRunning = !self.runningCommands.isEmpty
        }
    }
    
    private func getRunningCommandContext(_ command: Command) -> CommandExecutionContext? {
        if Thread.isMainThread {
            return runningCommands[command]
        } else {
            return DispatchQueue.main.sync { self.runningCommands[command] }
        }
    }
    
    private func removeRunningCommand(_ command: Command) {
        DispatchQueue.main.async {
            self.runningCommands.removeValue(forKey: command)
            self.isRunning = !self.runningCommands.isEmpty
        }
    }
    
    private init(settings: Settings = .shared, outputService: OutputFileService = .shared) {
        self.settings = settings
        self.outputService = outputService
    }
    
    func start(_ command: Command) {
        do {
            if command.isRunning() { return }
            
            let (process, inputPipe, outputPipe) = buildProcess(command)
        
            /// 这里创建了输出文件，但是后续可能不会真正的写入数据，即输出文件可能是空的。
            let fileHandle = try outputService.createCommandOutputFile(command)
        
            outputPipe.fileHandleForReading.readabilityHandler = { [weak self, weak fileHandle] handle in
                guard let self = self, let fileHandle = fileHandle else { return }
                /// handle.availableData 是计算属性，需要使用变量保存，因为它每次访问都会去获取新的数据。
                let data = handle.availableData
                self.handleOutput(data: data, fileHandle: fileHandle)
                
                /// ⚠️ 特殊处理：仅在 DEBUG 模式下启用。
                ///
                /// 针对我的场景，具体是用于 Python 编写的 Telegram Bot 服务。
                /// 在该服务启动时，`telethon` 库需要用户输入验证码才能完成登录。
                /// 如果代码中已经提供了手机号，`telethon` 还会要求输入验证码进行身份验证。
                ///
                /// 因此，当命令行输出中包含 `"Please enter the code you received:"` 时，
                /// 会弹出一个输入框供用户输入验证码。
                ///
                /// 由于这是针对我的需求的特殊处理，仅在 DEBUG 模式下启用，
                /// 在生产模式下不涉及该交互式操作。
                #if DEBUG
                    processDataFromAvailableData(data: data, inputPipe: inputPipe)
                #endif
            }
            
            process.terminationHandler = { [weak self] process in
                self?.handleProcessTermination(command: command, process: process)
            }
        
            try process.run()
            
            appendRunningCommand(command, CommandExecutionContext(process: process, outputPipe: outputPipe, fileHandle: fileHandle))

            command.markAsRunning()
            Logger.info("Command started: \(command.name) process ID: \(process.processIdentifier)")

            if settings.areNotificationsEnabled {
                NotificationService.shared.sendNotificationIfAuthorizedOrRequest(
                    title: NSLocalizedString("Command Started", comment: ""),
                    body: String(format: NSLocalizedString("%@ is now running", comment: ""), command.name)
                )
            }
            
        } catch {
            command.markAsFinished(isSuccess: false)
            Logger.error("Command failed to start: \(error.localizedDescription)")
            if settings.areNotificationsEnabled {
                NotificationService.shared.sendNotificationIfAuthorizedOrRequest(
                    title: NSLocalizedString("Command Failed to Start", comment: ""),
                    body: String(format: NSLocalizedString("%@ error: %@", comment: ""), command.name, error.localizedDescription)
                )
            }
        }
    }
    
    /// 在程序退出时需要终止全部进行中的命令，不能使用 GCD 因为不能 await，不能很好的判断什么时候全部退出了，所以需要使用 async
    func terminate(_ command: Command) async {
        /// 会阻塞需要调度到后台线程中处理
        
        guard let handler = getRunningCommandContext(command) else { return }
            
        Logger.debug("Preparing to stop command: \(command.name)")
            
        handler.outputPipe.fileHandleForReading.readabilityHandler = nil
            
        /// isCancelled 是一个额外的状态，只是表示 Command 已被取消，在 isRunning == false 时会重新设置回 false
        command.markAsCancelled()

        handler.process.terminate()
            
        handler.process.waitUntilExit()
            
        try? handler.fileHandle.close()
            
        removeRunningCommand(command)
            
        Logger.info("Command manually stopped: \(command.name)")
    }
    
    func terminateAllProcesses() async {
        if runningCommands.isEmpty { return }
        let startTime = Date()
        Logger.info("Starting to terminate all running processes.")

        await withTaskGroup(of: Void.self) { group in
            for command in runningCommands.keys {
                group.addTask {
                    Logger.info("Terminating process: \(command)")
                    await self.terminate(command)
                    Logger.info("Process terminated: \(command)")
                }
            }
        }
        let timeInterval = Date().timeIntervalSince(startTime)
        Logger.info("All termination tasks have been initiated. Total time taken: \(timeInterval) seconds.")
    }
    
    #if DEBUG
        /// 缓冲process的输出，因为之前只是写文件不需要，这里是需要读文件，最好还是缓冲一下
        /// 这里只记录最新一行的数据
        private var accumulatedData = Data()
        class DummyKeyWindow: NSWindow {
            override var canBecomeKey: Bool { true }
            override var canBecomeMain: Bool { true }

            override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
                super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)

                self.alphaValue = 0
                self.level = .modalPanel
                self.isReleasedWhenClosed = false
            }

            convenience init() {
                let windowWidth: CGFloat = 400
                let windowHeight: CGFloat = 220
                let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
                let hostWindowRect = NSRect(
                    x: screenFrame.midX - windowWidth / 2,
                    y: screenFrame.height * 0.66,
                    width: windowWidth,
                    height: windowHeight
                )
                self.init(contentRect: hostWindowRect, styleMask: [], backing: .buffered, defer: false)
            }
        }

        private func findVerificationCodeWindow() -> NSWindow? {
            for window in NSApp.windows {
                if NSStringFromClass(type(of: window)) == NSStringFromClass(DummyKeyWindow.self) {
                    return window
                }
            }
            return nil
        }
    
        private func processDataFromAvailableData(data: Data, inputPipe: Pipe) {
            accumulatedData.append(data)
            while true {
                guard let newlineIndex = accumulatedData.firstIndex(of: 0x0A) else { break }
                let lineData = accumulatedData.subdata(in: 0 ..< newlineIndex)
                if let line = String(data: lineData, encoding: .utf8) {
                    handleTelegramBotVerificationCode(data: line, inputPipe: inputPipe)
                }

                accumulatedData.removeSubrange(0 ... newlineIndex)
            }
        }

        private func getLineFromData(_ data: Data) -> String? {
            if let range = data.range(of: Data([0x0A])) {
                let lineData = data.subdata(in: 0 ..< range.lowerBound)
                if let line = String(data: lineData, encoding: .utf8) {
                    return line
                }
            }
            return nil
        }

        private func handleTelegramBotVerificationCode(data: String, inputPipe: Pipe) {
            guard data.contains("Please enter the code you received:") else {
                return
            }
            
            DispatchQueue.main.async { [weak self, weak inputPipe] in
                guard let self = self, let inputPipe = inputPipe else { return }

                /// 这里就不能认真考虑这种多次打开的场景，它不应该存在
                /// FIXME：这里暂时这样处理
                if let window = findVerificationCodeWindow() {
                    window.close()
                }

                let alert = NSAlert()
                alert.messageText = NSLocalizedString("Please enter the code you received:", comment: "")
                alert.alertStyle = .informational

                alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
                alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))

                let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
                inputField.font = NSFont.monospacedDigitSystemFont(ofSize: 16, weight: .medium)
                inputField.alignment = .center

                inputField.isBezeled = true
                inputField.bezelStyle = .roundedBezel
                inputField.focusRingType = .default
                inputField.usesSingleLineMode = true

                alert.accessoryView = inputField

                /// 这里使用一个透明的窗口目的：让 alert 内自动聚焦的 input 的光标能够正常显示
                let dummyWindow = DummyKeyWindow()
                dummyWindow.center()
                dummyWindow.makeKeyAndOrderFront(nil)

                alert.beginSheetModal(for: dummyWindow) { response in
                    dummyWindow.close()
                    if response == .alertFirstButtonReturn {
                        /// 向 Process 写入数据时，如果对应的程序没有做好安全处理，是可能存在注入攻击等风险的。
                        let safeInput = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let data = (safeInput + "\n").data(using: .utf8) {
                            inputPipe.fileHandleForWriting.write(data)
                            Logger.info("Successfully wrote the verification code to the process")
                        }
                    } else {
                        Logger.info("User canceled entering the verification code")
                    }
                }
                /// 让 alert 能够获得焦点
                NSApp.activate(ignoringOtherApps: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if let alertWindow = dummyWindow.attachedSheet {
                        alertWindow.makeFirstResponder(inputField)
                    }
                }
            }
        }
    #endif
}

extension CommandRunner {
    private func handleProcessTermination(command: Command, process: Process) {
        let status = process.terminationStatus
        let reason = process.terminationReason

        removeRunningCommand(command)

        if reason == .exit, status == 0 {
            Logger.info("✅ Child process exited normally")
        } else {
            Logger.error("❌ Child process exited abnormally, status=\(status), reason=\(reason.rawValue)")
        }

        // 发送终止通知（仅在正常退出时）
        if settings.areNotificationsEnabled {
            if command.isCancelled() {
                NotificationService.shared.sendNotificationIfAuthorizedOrRequest(
                    title: NSLocalizedString("Command Stopped", comment: ""),
                    body: String(format: NSLocalizedString("%@ was manually stopped", comment: ""), command.name)
                )
            } else if reason == .exit, status == 0 {
                NotificationService.shared.sendNotificationIfAuthorizedOrRequest(
                    title: NSLocalizedString("Command Completed", comment: ""),
                    body: String(format: NSLocalizedString("%@ completed successfully (exit code: %d)", comment: ""), command.name, status)
                )
            } else {
                NotificationService.shared.sendNotificationIfAuthorizedOrRequest(
                    title: NSLocalizedString("Command Failed", comment: ""),
                    body: String(format: NSLocalizedString("%@ failed with exit code: %d", comment: ""), command.name, status)
                )
            }
        }
        
        /// 先发消息再更新状态，因为上面需要判断是否是取消的。
        command.markAsFinished(isSuccess: reason == .exit && status == 0)
    }
    
    private func handleOutput(data: Data, fileHandle: FileHandle) {
        do {
            if data.isEmpty {
                try fileHandle.close()
            } else {
                try fileHandle.write(contentsOf: data)
            }
        } catch {
            Logger.error("Error receiving data response: \(error)")
        }
    }

    private func buildProcess(_ command: Command) -> (Process, Pipe, Pipe) {
        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        
        let defaultShell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/bash"
        let workingDirectory = NSString(string: command.workingDirectory).expandingTildeInPath

        let shellArguments: [String]
        if defaultShell.contains("zsh") {
            shellArguments = ["-i", "-c", command.shellCommand]
        } else {
            shellArguments = ["-c", command.shellCommand]
        }

        process.arguments = shellArguments
        process.standardInput = inputPipe
        process.standardError = outputPipe
        process.standardOutput = outputPipe
        process.executableURL = URL(fileURLWithPath: defaultShell)
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        
        if !command.environment.isEmpty {
            var env = ProcessInfo.processInfo.environment
            for (key, value) in command.environment {
                env[key] = value
            }
            env["TERM"] = "xterm-256color"
            process.environment = env
        }
        
        Logger.info("Starting command: \(command.name), command: \(command.shellCommand), working directory: \(workingDirectory)")
        
        return (process, inputPipe, outputPipe)
    }
}

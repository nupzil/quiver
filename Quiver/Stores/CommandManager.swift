//
//  Created by Nupzil on 2025/5/8.
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

@Observable
final class CommandManager {
    static let shared = CommandManager()

    var commands: [Command] = []

    private let commandRunner: CommandRunner
    private let configManager: ConfigManager

    var isRunning: Bool {
        commandRunner.isRunning
    }

    private init(commandRunner: CommandRunner = .shared, configManager: ConfigManager = .shared) {
        self.commandRunner = commandRunner
        self.configManager = configManager
    }

    func toggleCommand(command: Command) {
        Task {
            if command.isRunning() {
                await commandRunner.terminate(command)
            } else {
                commandRunner.start(command)
            }
        }
    }

    func loadConfiguration() {
        do {
            commands = try configManager.loadConfiguration()
        } catch {
            NotificationService.shared.sendNotificationIfAuthorizedOrRequest(
                title: NSLocalizedString("Failed to Load Configuration", comment: ""),
                body: String(format: NSLocalizedString("Reason: %@", comment: ""), error.localizedDescription)
            )
        }
    }

    func reloadConfiguration() {
        if commandRunner.isAnyCommandRunning() {
            showAlert(
                title: NSLocalizedString("Cannot Reload Configuration", comment: ""),
                body: NSLocalizedString("Please stop all running commands before reloading configuration.", comment: "")
            )
            return
        }

        do {
            commands = try configManager.loadConfiguration()
            Logger.debug("Configuration file reloaded successfully")
            Logger.debug("Successfully loaded \(commands.count) configurations")
            notifyOrAlert(
                title: NSLocalizedString("Configuration Reloaded", comment: ""),
                body: NSLocalizedString("All commands have been reloaded successfully.", comment: "")
            )
        } catch {
            Logger.info("Failed to reload configuration file: \(error.localizedDescription)")
            notifyOrAlert(
                title: NSLocalizedString("Failed to Load Configuration", comment: ""),
                body: String(format: NSLocalizedString("Reason: %@", comment: ""), error.localizedDescription)
            )
        }
    }

    private func notifyOrAlert(title: String, body: String) {
        Task {
            let granted = await NotificationService.shared.requestAuthorizationIfNeeded()

            if granted {
                if await NotificationService.shared.sendNotification(title: title, body: body) {
                    return
                }
            }
            DispatchQueue.main.async {
                showAlert(title: title, body: body)
            }
        }
    }
}

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
import SwiftUI
import VersionCompare

private struct GitHubReleaseInfo: Decodable {
    let tag_name: String
}

struct VersionCheckResult {
    let downloadURL: URL
    let latestVersion: String
    let currentVersion: String
    let updateAvailable: Bool
}

@Observable
final class UpdateService {
    static let shared = UpdateService()

    var isUpdateCheckInProgress = false

    @ObservationIgnored
    private var lastCheckTimestamp: Date?

    private let releasesAPIEndpoint = URL(string: AppInfo.releasesAPIEndpoint)!

    private let releasePageURL = URL(string: AppInfo.releasePageURL)!

    private func retrieveVersionInfo() async throws -> VersionCheckResult {
        do {
            let (data, response) = try await URLSession.shared.data(from: releasesAPIEndpoint)
            guard let httpResponse = response as? HTTPURLResponse else {
                Logger.warning("Invalid response: not an HTTP response")
                throw NSError(domain: "UpdateService", code: -10003, userInfo: [NSLocalizedDescriptionKey: "Invalid response type received"])
            }
            guard (200 ... 299).contains(httpResponse.statusCode) else {
                Logger.warning("Request failed with status code: \(httpResponse.statusCode)")
                throw NSError(domain: "UpdateService", code: -10002, userInfo: [NSLocalizedDescriptionKey: "HTTP request failed with invalid status code"])
            }

            let releaseInfo = try JSONDecoder().decode(GitHubReleaseInfo.self, from: data)

            let installedVersion = AppInfo.version.versionStringNormalized()
            let latestVersion = releaseInfo.tag_name.versionStringNormalized()

            let updateAvailable: Bool = try {
                guard let latest = Version(latestVersion), let installed = Version(installedVersion) else {
                    Logger.warning("Failed to compare versions: \(installedVersion) vs \(latestVersion)")
                    throw NSError(domain: "UpdateService", code: -10001)
                }
                return latest > installed
            }()

            Logger.info("Checking for updates: current version = \(installedVersion), latest version = \(latestVersion)")

            return VersionCheckResult(
                downloadURL: releasePageURL,
                latestVersion: latestVersion,
                currentVersion: installedVersion,
                updateAvailable: updateAvailable,
            )
        } catch {
            Logger.info("Error occurred while checking for updates: \(error)")
            throw error
        }
    }

    public func checkForUpdates() async {
        let currentTime = Date()
        if let lastCheck = lastCheckTimestamp, currentTime.timeIntervalSince(lastCheck) < 10 {
            Logger.info("Update check skipped: last check was less than 10 seconds ago")
            return
        }
        lastCheckTimestamp = currentTime

        guard !isUpdateCheckInProgress else { return }

        await MainActor.run { isUpdateCheckInProgress = true }
        let versionInfo = try? await retrieveVersionInfo()
        await MainActor.run { isUpdateCheckInProgress = false }

        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.icon = NSImage(named: "AppIcon")
            guard let versionInfo else {
                alert.messageText = NSLocalizedString("Error Checking for Updates", comment: "")
                alert.informativeText = NSLocalizedString("An error occurred while checking for updates. Please try again later.", comment: "")
                alert.addButton(withTitle: NSLocalizedString("OK", comment: "OK button title"))
                alert.runModal()
                return
            }

            if true {
                let info = NSLocalizedString("A new version is available: %@ (You have %@)", comment: "")

                alert.messageText = NSLocalizedString("New Update Available", comment: "")
                alert.informativeText = String(format: info, versionInfo.latestVersion, versionInfo.currentVersion)

                alert.addButton(withTitle: NSLocalizedString("Go Download", comment: "Download button title"))
                alert.addButton(withTitle: NSLocalizedString("Ignore", comment: "Ignore button title"))
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    NSWorkspace.shared.open(versionInfo.downloadURL)
                }
                return
            }

            let info = NSLocalizedString("You are using the latest version (%@)", comment: "")
            alert.messageText = NSLocalizedString("You are up to date", comment: "")
            alert.informativeText = String(format: info, versionInfo.currentVersion)
            alert.addButton(withTitle: NSLocalizedString("OK", comment: "OK button title"))
            alert.runModal()
        }

        /// alert.messageText = NSLocalizedString("Checking for updates...", comment: "")
        /// alert.informativeText = NSLocalizedString("Please wait while we check for the latest version.", comment: "")
        /// alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Cancel button title"))
    }
}

private extension String {
    func versionStringNormalized() -> String {
        /// 移除可能得前缀: v or V
        let normalized = replacingOccurrences(of: "^[vV]", with: "", options: .regularExpression)
        return normalized
    }
}

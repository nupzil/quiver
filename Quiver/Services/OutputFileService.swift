//
//  Created by Nupzil on 2025/5/7.
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

final class OutputFileService {
    static let shared = OutputFileService()

    private let settings: Settings

    private init(settings: Settings = .shared) {
        self.settings = settings
    }

    private var timestampFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "YYYY-MM-DD-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }

    private var baseOutputDirectory: URL {
        URL(fileURLWithPath: settings.applicationDataDirectory).appending(path: "outs", directoryHint: .isDirectory)
    }

    func createCommandOutputFile(_ command: Command) throws -> FileHandle {
        let url = try generateOutputFilePath(for: command)
        try "".write(to: url, atomically: true, encoding: .utf8)
        return try FileHandle(forWritingTo: url)
    }

    func cleanupObsoleteFiles(commands: [Command]) {
        let directories = fetchSubdirectories(in: baseOutputDirectory)

        let activeDirectories = directories.filter { directory in
            commands.contains(where: { command in command.id == directory.lastPathComponent })
        }
        /// todo 不存在的目录全部删除，防止修改配置无法清理关联的输出文件

        for dir in activeDirectories {
            purgeExcessLogs(in: dir, keepingLast: settings.maxLogFilesRetained)
        }
    }
}

extension OutputFileService {
    private func purgeExcessLogs(in directory: URL, keepingLast maxCount: Int) {
        let fileManager = FileManager.default

        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else {
            return
        }

        let logFiles = files
            .filter { $0.pathExtension == "log" }
            .compactMap { url -> (URL, Date)? in
                let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                return date.map { (url, $0) }
            }
            .sorted { $0.1 > $1.1 }

        let obsoleteFiles = logFiles.dropFirst(maxCount)
        for (url, _) in obsoleteFiles {
            try? fileManager.removeItem(at: url)
            Logger.info("Deleted log file: \(url.lastPathComponent)")
        }
    }

    private func generateOutputFilePath(for command: Command) throws -> URL {
        let timestamp = timestampFormatter.string(from: Date())
        let nextURL = baseOutputDirectory
            .appending(path: "\(command.id)", directoryHint: .isDirectory)
            .appending(path: "\(timestamp).log", directoryHint: .notDirectory)

        let directory = nextURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            Logger.warning("Unable to create directory at \(directory.path): \(error.localizedDescription)")
        }
        return nextURL
    }

    private func fetchSubdirectories(in parent: URL) -> [URL] {
        guard let contents = try? FileManager.default.contentsOfDirectory(at: parent, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return []
        }

        return contents.filter {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
    }
}

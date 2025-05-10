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

public enum LogLevel: String, CaseIterable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    
    var priority: Int {
        switch self {
        case .debug: return 0
        case .info: return 1
        case .warning: return 2
        case .error: return 3
        }
    }
}

/// 日志管理器，负责日志文件的创建、轮转和清理
public class LogManager {
    public static let shared = LogManager()
    
    private let maxLogFiles = Settings.shared.maxLogFilesRetained
    
    private let logDir: String = Settings.shared.appLogsOutputDirectory
    
    /// 当前日志文件路径
    private(set) var currentLogFilePath: String
    
    private let fileManager = FileManager.default
    
    private let logQueue = DispatchQueue(label: "com.quiver.logmanager", qos: .utility)
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    private init() {
        if !fileManager.fileExists(atPath: logDir) {
            try? fileManager.createDirectory(atPath: logDir, withIntermediateDirectories: true, attributes: nil)
        }
        
        let timestamp = dateFormatter.string(from: Date())
        currentLogFilePath = "\(logDir)/quiver_\(timestamp).log"
        fileManager.createFile(atPath: currentLogFilePath, contents: nil)
        
        // 清理旧日志文件
        cleanupOldLogFiles()
    }
    
    private func cleanupOldLogFiles() {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let fileURLs = try self.fileManager.contentsOfDirectory(
                    at: URL(fileURLWithPath: self.logDir),
                    includingPropertiesForKeys: [.creationDateKey],
                    options: .skipsHiddenFiles
                )
                
                let logFiles = fileURLs.filter { $0.pathExtension == "log" }
                
                if logFiles.count > self.maxLogFiles {
                    let sortedFiles = try logFiles.sorted {
                        let date1 = try $0.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                        let date2 = try $1.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                        return date1 < date2
                    }
                    
                    let filesToDelete = sortedFiles.prefix(sortedFiles.count - self.maxLogFiles)
                    for fileURL in filesToDelete {
                        try self.fileManager.removeItem(at: fileURL)
                    }
                }
            } catch {
                print("清理日志文件失败: \(error)")
            }
        }
    }
    
    public func getAllLogFiles() -> [String] {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: URL(fileURLWithPath: logDir),
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )
            return fileURLs.filter { $0.pathExtension == "log" }.map { $0.path }
        } catch {
            print("获取日志文件列表失败: \(error)")
            return []
        }
    }
    
    func writeToFile(_ logMessage: String) {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let fileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: self.currentLogFilePath))
                fileHandle.seekToEndOfFile()
                
                if let data = "\(logMessage)\n".data(using: .utf8) {
                    fileHandle.write(data)
                }
                
                fileHandle.closeFile()
            } catch {
                print("写入日志文件失败: \(error)")
            }
        }
    }
}

/// 日志记录器类
public class Logger {
    private let module: String
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
    
    public static var minimumLogLevel: LogLevel = .debug
    
    public static var printToConsole: Bool = true
    
    public init(module: String) {
        self.module = module
    }
    
    public func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, message, file: file, function: function, line: line)
    }
    
    public func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, message, file: file, function: function, line: line)
    }
    
    public func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, message, file: file, function: function, line: line)
    }
 
    public func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, message, file: file, function: function, line: line)
    }
    
    private func log(_ level: LogLevel, _ message: String, file: String, function: String, line: Int) {
        if level.priority < Logger.minimumLogLevel.priority {
            return
        }
        
        let timestamp = dateFormatter.string(from: Date())
        let fileName = (file as NSString).lastPathComponent
        let levelFormatted = level.rawValue.prefix(6).padding(toLength: 6, withPad: " ", startingAt: 0)
        let moduleFormatted = module.prefix(20).padding(toLength: 10, withPad: " ", startingAt: 0)
        let logMessage = "\(timestamp) \(levelFormatted) \(moduleFormatted) \(fileName):\(line) \(function) \(message)"
        
        if Logger.printToConsole {
            print(logMessage)
        }
        
        LogManager.shared.writeToFile(logMessage)
    }
}

/// 便捷的日志记录扩展
public extension Logger {
    static let `default` = Logger(module: "Default")
    
    static func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        Logger.default.debug(message, file: file, function: function, line: line)
    }
    
    static func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        Logger.default.info(message, file: file, function: function, line: line)
    }
    
    static func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        Logger.default.warning(message, file: file, function: function, line: line)
    }
    
    static func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        Logger.default.error(message, file: file, function: function, line: line)
    }
}

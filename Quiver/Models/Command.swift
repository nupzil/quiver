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

import CryptoKit
import Foundation

enum CommandStatus {
    case idle
    case failed
    case running
    case success
}

/// 其他线程对于 status 的访问应该通过方法访问，不能直接访问 status 属性，除非是在 UI 层
@Observable
class Command: Identifiable {
    let id: String
    let name: String
    let shellCommand: String
    let workingDirectory: String
    let environment: [String: String]

    // MARK: State
    
    /// 已取消，但是可能仍在运行中的，UI应该在 canceled 状态中将UI禁用。
    /// cancelled 将在真正停止时设置回 false
    private(set) var cancelled = false

    /// 表示 Command 当前的状态
    /// - 重要提示: 此属性必须在主线程上访问，否则可能导致不可预测的行为
    /// - 在非 UI 层代码中，请使用 isRunning or isCancelled 计算属性访问
    private(set) var status: CommandStatus = .idle
    

    init(name: String, shellCommand: String, workingDirectory: String, environment: [String: String] = [:]) {
        self.name = name
        self.id = sanitize(name)
        self.environment = environment
        self.shellCommand = shellCommand
        self.workingDirectory = workingDirectory
    }

    /// 使用方法而不是计算属性用于标记于 status 的不同
    func isRunning() -> Bool {
        if Thread.isMainThread {
            return status == .running
        }
        return DispatchQueue.main.sync { self.status == .running }
    }

    /// 使用方法而不是计算属性用于标记于 status 的不同
    func isCancelled() -> Bool {
        if Thread.isMainThread {
            return cancelled
        }
        return DispatchQueue.main.sync { self.cancelled }
    }

    func markAsRunning() {
        if Thread.isMainThread {
            status = .running
        } else {
            DispatchQueue.main.sync { self.status = .running }
        }
    }

    func markAsCancelled() {
        if Thread.isMainThread {
            cancelled = true
        } else {
            DispatchQueue.main.sync { self.cancelled = true }
        }
    }

    func markAsFinished(isSuccess: Bool) {
        if Thread.isMainThread {
            cancelled = false
            status = isSuccess ? .success : .failed
        } else {
            DispatchQueue.main.sync {
                self.cancelled = false
                self.status = isSuccess ? .success : .failed
            }
        }
    }
}

extension Command: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Command, rhs: Command) -> Bool {
        return lhs.id == rhs.id
    }
}

private func hash(from name: String) -> String {
    let data = name.data(using: .utf8)!
    let hash = SHA256.hash(data: data)
    return hash.prefix(12).map { String(format: "%02x", $0) }.joined()
}

private func sanitize(_ name: String) -> String {
    let allowed = CharacterSet.alphanumerics.union(.whitespaces)
    let sanitized = name.components(separatedBy: allowed.inverted).joined()
    return sanitized.replacingOccurrences(of: " ", with: "_")
}

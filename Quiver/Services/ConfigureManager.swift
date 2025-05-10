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
import Yams

enum ConfigurationError: LocalizedError {
    case fileNotFound
    case encodingFailed
    case decodingFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return NSLocalizedString("Configuration file not found.", comment: "")
        case .encodingFailed:
            return NSLocalizedString("Failed to encode configuration.", comment: "")
        case .decodingFailed(let error):
            return String(format: NSLocalizedString("Failed to decode configuration: %@", comment: ""), error.localizedDescription)
        }
    }
}

private struct CommandConfiguration: Codable {
    let name: String
    let script: String
    let workingDir: String
    let environment: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case env
        case name
        case script
        case workingDir = "working_dir"
    }
    
    init(name: String, script: String, workingDir: String, environment: [String: String]? = nil) {
        self.name = name
        self.script = script
        self.workingDir = workingDir
        self.environment = environment
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        name = try container.decode(String.self, forKey: .name)
        script = try container.decode(String.self, forKey: .script)
        workingDir = try container.decode(String.self, forKey: .workingDir)
        
        if let envArray = try container.decodeIfPresent([[String: String]].self, forKey: .env) {
            var envDict = [String: String]()
            for item in envArray {
                for (key, value) in item {
                    envDict[key] = value
                }
            }
            environment = envDict
        } else {
            environment = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(name, forKey: .name)
        try container.encode(script, forKey: .script)
        try container.encode(workingDir, forKey: .workingDir)
        
        if let env = environment, !env.isEmpty {
            var envArray = [[String: String]]()
            for (key, value) in env {
                envArray.append([key: value])
            }
            try container.encode(envArray, forKey: .env)
        }
    }
    
    func toCommand() -> Command {
        return Command(
            name: name,
            shellCommand: script,
            workingDirectory: workingDir,
            environment: environment ?? [:]
        )
    }
}

final class ConfigManager {
    static let shared = ConfigManager()
    
    private let settings: Settings
    
    private init(settings: Settings = .shared) {
        self.settings = settings
    }

    func ensureDefaultTemplate() {
        let configPath = settings.configurationFilePath
        let configDir = (configPath as NSString).deletingLastPathComponent
        
        if !FileManager.default.fileExists(atPath: configDir) {
            try? FileManager.default.createDirectory(atPath: configDir, withIntermediateDirectories: true)
        }

        if !FileManager.default.fileExists(atPath: configPath) {
            createConfigurationTemplate()
        }
    }

    func loadConfiguration() throws -> [Command] {
        let configPath = settings.configurationFilePath

        if !FileManager.default.fileExists(atPath: configPath) {
            throw ConfigurationError.fileNotFound
        }
    
        let yamlString = try String(contentsOfFile: configPath, encoding: .utf8)
        
        do {
            let decoder = YAMLDecoder()
            let configurations = try decoder.decode([CommandConfiguration].self, from: yamlString)
            return configurations.map { $0.toCommand() }
        } catch {
            Logger.warning("Failed to parse configuration file: \(error.localizedDescription)")
            throw ConfigurationError.decodingFailed(error)
        }
    }
    
    func saveConfiguration(_ commands: [Command]) throws {
        let configPath = settings.configurationFilePath
    
        let configurations = commands.map { command -> CommandConfiguration in
            CommandConfiguration(
                name: command.name,
                script: command.shellCommand,
                workingDir: command.workingDirectory,
                environment: command.environment.isEmpty ? nil : command.environment
            )
        }
        
        do {
            let encoder = YAMLEncoder()
            let yamlString = try encoder.encode(configurations)
            try yamlString.write(toFile: configPath, atomically: true, encoding: .utf8)
            Logger.info("Configuration saved to: \(configPath)")
        } catch {
            Logger.error("Failed to save configuration: \(error.localizedDescription)")
            throw ConfigurationError.encodingFailed
        }
    }
}

extension ConfigManager {
    private func createConfigurationTemplate() {
        let templateContent = """
        # Quiver Configuration File Example
        # You can define multiple commands, each with the following properties:
        # - name: Command name
        # - script: Shell command to execute
        # - working_dir: Working directory
        # - env: Environment variables (optional)

        - name: Echo Example
          script: echo "[$mode] Hello from Quiver!"
          working_dir: ~/
          env: 
            - mode: DEBUG

        - name: open release dir
          script: open "$(find ~/Library/Developer/Xcode/DerivedData -name 'Quiver-*' -type d | head -n 1)/Build/Products"
          working_dir: ~/
        
        """

        do {
            try templateContent.write(toFile: settings.configurationFilePath, atomically: true, encoding: .utf8)
            Logger.info("Created configuration template: \(settings.configurationFilePath)")
        } catch {
            Logger.error("Failed to create configuration template: \(error.localizedDescription)")
        }
    }
}

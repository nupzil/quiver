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

import UserNotifications

final class NotificationService {
    static let shared = NotificationService()
    
    private(set) var isAuthorized = false
    
    func requestAuthorizationIfNeeded() async -> Bool {
        if isAuthorized { return true }
        
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        if settings.authorizationStatus != .notDetermined {
            isAuthorized = settings.authorizationStatus == .authorized
            return isAuthorized
        }
        return await requestAuthorization()
    }
    
    func requestAuthorizationIfNeeded(_ completion: @escaping (Bool) -> Void) {
        if isAuthorized { return completion(true) }
        
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus != .notDetermined {
                self.isAuthorized = settings.authorizationStatus == .authorized
                return completion(self.isAuthorized)
            }
            
            self.requestAuthorization(completion)
        }
    }

    func requestAuthorization() async -> Bool {
        do {
            let center = UNUserNotificationCenter.current()
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                Logger.info("Notification permission granted")
            } else {
                Logger.warning("User denied notification permission")
            }
            isAuthorized = granted
        } catch {
            isAuthorized = false
            Logger.error("Failed to request notification permission: \(error)")
        }
        return isAuthorized
    }
    
    func requestAuthorization(_ completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                Logger.error("Failed to request notification permission: \(error)")
            } else if !granted {
                Logger.warning("User denied notification permission")
            } else {
                Logger.info("Notification permission granted")
            }
            self.isAuthorized = granted
            completion(granted)
        }
    }
    
    func sendNotification(title: String, body: String) {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.body = body
        content.title = title
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Logger.error("Failed to send notification: \(error)")
            }
        }
    }
    
    func sendNotification(title: String, body: String) async -> Bool {
        guard isAuthorized else { return false }
        
        let content = UNMutableNotificationContent()
        content.body = body
        content.title = title
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        do {
            try await UNUserNotificationCenter.current().add(request)
            return true
        } catch {
            Logger.error("Failed to send notification: \(error)")
            return false
        }
    }
    
    func sendNotificationIfAuthorizedOrRequest(title: String, body: String) {
        requestAuthorizationIfNeeded { granted in
            if granted {
                self.sendNotification(title: title, body: body)
            }
        }
    }

}

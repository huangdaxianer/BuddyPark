import UserNotifications
import UIKit
import Intents

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
                
        do {
            completionHandler()
        }
    }
    
    func requestAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { (granted, error) in
            if granted {
                print("Notification Authorization Granted.")
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                print("Notification Authorization Denied.")
            }
        }
    }
    
    func handleDeviceToken(_ deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        UserDefaults.standard.set(token, forKey: "deviceToken")
        print("Device Token: \(token)")
    }
    
    func handleFailureToRegister(_ error: Error) {
        print("Failed to register for remote notifications: \(error)")
    }
    
}

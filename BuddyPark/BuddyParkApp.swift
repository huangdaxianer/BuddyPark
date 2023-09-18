import SwiftUI
import UserNotifications


class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    let notificationManager = NotificationManager.shared
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self // 修改这里
        
        notificationManager.requestAuthorization()
        UIApplication.shared.registerForRemoteNotifications()
        
        // 处理回复消息的操作
        let replyAction = UNTextInputNotificationAction(identifier: "reply",
                                                        title: "Reply",
                                                        options: [],
                                                        textInputButtonTitle: "Send",
                                                        textInputPlaceholder: "Your message")
        let category = UNNotificationCategory(identifier: "normal",
                                              actions: [replyAction],
                                              intentIdentifiers: [],
                                              options: [])
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.setNotificationCategories([category])
        
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        notificationManager.handleDeviceToken(deviceToken)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        notificationManager.handleFailureToRegister(error)
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
    }
    
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let notificationContent = response.notification.request.content
        if let userInfo = notificationContent.userInfo as? [String: Any],
           let apsData = userInfo["aps"] as? [String: Any],
           let characterIDString = apsData["characterid"] as? String,
           let characterID = Int32(characterIDString) {
            if response.actionIdentifier == "reply",
               let textInputResponse = response as? UNTextInputNotificationResponse {
                
                var replyText = textInputResponse.userText
                replyText = replyText.replacingOccurrences(of: "\n", with: " ")
                
                let date = Date()
                let formatter = DateFormatter()
                formatter.dateFormat = "MM月dd日HH:mm"
                formatter.locale = Locale(identifier: "zh_CN")
                let timeString = formatter.string(from: date)
                let replayWithTime = "\(replyText)$\(timeString)"
                
                let userMessage = LocalMessage(id: UUID(), role: "user", content: replayWithTime, timestamp: Date())
                
                DispatchQueue.main.async {
                    // 通过 globalSessionManager 获取对应 characterID 的 messageManager
                    if let messageManager = globalSessionManager?.session(for: characterID) {
                        
                        messageManager.appendFullMessage(userMessage, lastUserReplyFromServer: nil, isFromBackground: true) {
                            messageManager.sendRequest(type: .newMessage)
                        }
                    }
                }
            }
        }
        completionHandler()
    }
    
    
    
    //在前台通过 APNS 收消息
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        let characteridString = (userInfo["aps"] as? [String: Any])?["characterid"] as? String // 假设 userInfo 里包含 characterid
        guard let characterid = Int32(characteridString ?? "") else {
            return
        }
        
        let messageManager = globalSessionManager?.session(for: characterid)
        let fullText = (userInfo["aps"] as? [String: Any])?["full-text"] as? String
        let messageUUID: UUID
        if let messageUUIDString = (userInfo["aps"] as? [String: Any])?["message-uuid"] as? String,
           let validUUID = UUID(uuidString: messageUUIDString) {
            messageUUID = validUUID
        } else {
            messageUUID = UUID() // 创建一个新的 UUID
        }
        
        
        // let freeMessageLeftString = (userInfo["aps"] as? [String: Any])?["free-message-left"] as? String
        let lastUserMessageFromServer = (userInfo["aps"] as? [String: Any])?["users-reply"] as? String
        
        let newFullMessage = LocalMessage(id: messageUUID, role: "assistant", content: fullText ?? notification.request.content.body, timestamp: Date())
        messageManager?.appendFullMessage(newFullMessage, lastUserReplyFromServer: lastUserMessageFromServer){}
        
        // 这里还要处理根据通知里的消息处理订阅状态的逻辑
    }
}


@main
struct BuddyParkApp: App {
    let dataManager = CoreDataManager.shared
    @StateObject var sessionManager: SessionManager
    @State private var isSignedIn: Bool = false
    @State var navigateToHome: Bool = false

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        CharacterManager.shared.setupImageDirectory(for: .profile)
        let context = dataManager.mainManagedObjectContext // 使用CoreDataManager的mainManagedObjectContext
        let sessionManager = SessionManager(context: context)
        _sessionManager = StateObject(wrappedValue: sessionManager)
        globalSessionManager = sessionManager
    }

    var body: some Scene {
            WindowGroup {
                if navigateToHome {
                    HomeView(sessionManager: sessionManager)
                        .environment(\.managedObjectContext, dataManager.mainManagedObjectContext)
                        .environmentObject(sessionManager)
                } else {
                    WelcomeView(navigateToHome: $navigateToHome)
                }
            }
        }
}





import SwiftUI
import UserNotifications


class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    let notificationManager = NotificationManager.shared
 //   var sessionManager: SessionManager!
    

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
    
    //更新角标
    func applicationWillEnterForeground(_ application: UIApplication) {
        UIApplication.shared.applicationIconBadgeNumber = 0
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        let userDefaults = UserDefaults(suiteName: appGroupName)
        userDefaults?.set(0, forKey: "badgeNumber")
    }

    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        notificationManager.handleDeviceToken(deviceToken)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        notificationManager.handleFailureToRegister(error)
    }
    
    //在后台处理用户的回复
//    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
//        if response.actionIdentifier == "reply",
//           let response = response as? UNTextInputNotificationResponse {
//            let replyText = response.userText
//            let date = Date()
//            let formatter = DateFormatter()
//            formatter.dateFormat = "MM月dd日HH:mm"
//            let timeString = formatter.string(from: date)
//            let replayWithTime = "\(replyText)$\(timeString)"
//            let userMessage = LocalMessage(id: UUID(), role: .user, content: replayWithTime, timestamp: Date())
//            DispatchQueue.main.async {
//                self.messageManager.appendFullMessage(userMessage, lastUserReplyFromServer: nil, isFromBackground: true){}
//            }
//            messageManager.sendRequest(type: .newMessage)
//        }
//
//        completionHandler()
//    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
    }
    
    //在前台通过 APNS 收消息
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
          let userInfo = notification.request.content.userInfo
          let characterIdString = (userInfo["aps"] as? [String: Any])?["characterid"] as? String // 假设 userInfo 里包含 characterid
          guard let characterId = Int32(characterIdString ?? "") else {
              print("无法从推送通知中获取 characterId")
              return
          }

        let messageManager = globalSessionManager?.session(for: characterId)
          let fullText = (userInfo["aps"] as? [String: Any])?["full-text"] as? String
          let freeMessageLeftString = (userInfo["aps"] as? [String: Any])?["free-message-left"] as? String
          let lastUserMessageFromServer = (userInfo["aps"] as? [String: Any])?["users-reply"] as? String
          
          let newFullMessage = LocalMessage(id: UUID(), role: "assistant", content: fullText ?? notification.request.content.body, timestamp: Date())
        messageManager?.appendFullMessage(newFullMessage, lastUserReplyFromServer: lastUserMessageFromServer){}

        // 这里还要处理根据通知里的消息处理订阅状态的逻辑
      }

}

var globalSessionManager: SessionManager?

@main
struct BuddyParkApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject var sessionManager: SessionManager
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        let context = persistenceController.container.viewContext
        let sessionManager = SessionManager(context: context)
        _sessionManager = StateObject(wrappedValue: sessionManager)
        globalSessionManager = sessionManager
    }


    var body: some Scene {
        WindowGroup {
            HomeView(sessionManager: globalSessionManager ?? sessionManager)
                 .environment(\.managedObjectContext, persistenceController.container.viewContext)
                 .environmentObject(globalSessionManager ?? sessionManager)
        }
    }
}



class ProfileData: ObservableObject {
    @Published var profiles: [ProfileCardModel] = []

    init() {
        for i in 1...20 { // 使用 1...10 而不是 0..<10
            let characterId: Int32 = 705
            let name = "俊熙\(i)号"  // 在这里，我们将索引值 i 加到名字后面
            let age = 21
            let pictures: [UIImage] = [UIImage(named: "junxi")!]
            let intro = "体育校队队长，母胎单身，肌肉发达头脑也不简单，喜欢大哥哥。"
            let profile = ProfileCardModel(characterId: characterId, name: name, age: age, pictures: pictures, intro: intro)
            profiles.append(profile)
        }
    }
}



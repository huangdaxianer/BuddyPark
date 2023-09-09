import UserNotifications
import CoreData
import UIKit
import Intents

class NSE: UNNotificationServiceExtension {
    
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    
    let appGroupName = "group.com.penghao.BuddyPark"
    var persistentContainer: NSPersistentContainer!
    var globalSessionManager: SessionManager?

    // 初始化CoreData的persistentContainer
    func setupCoreDataStack() {
        let container = NSPersistentContainer(name: "BuddyPark")
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName) {
            container.persistentStoreDescriptions = [NSPersistentStoreDescription(url: url.appendingPathComponent("BuddyPark.sqlite"))]
        }
        
        container.loadPersistentStores { (description, error) in
            if let error = error {
                print("Error setting up Core Data (\(error))")
            }
        }
        
        persistentContainer = container
        globalSessionManager = SessionManager(container: container)
    }

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        // 设置CoreData
        setupCoreDataStack()

        // ... 保留你原有的代码，但确保删除所有与UserDefaults相关的部分 ...

        // 使用新的SessionManager和MessageManager逻辑处理消息
        let userInfo = request.content.userInfo
        let characteridString = (userInfo["aps"] as? [String: Any])?["characterid"] as? String
        guard let characterid = Int32(characteridString ?? "") else {
            print("无法从推送通知中获取 characterid")
            return
        }

        let messageManager = globalSessionManager?.session(for: characterid)
        let fullText = (userInfo["aps"] as? [String: Any])?["full-text"] as? String
        let lastUserMessageFromServer = (userInfo["aps"] as? [String: Any])?["users-reply"] as? String
          
        let newFullMessage = LocalMessage(id: UUID(), role: "assistant", content: fullText ?? request.content.body, timestamp: Date())
        messageManager?.appendFullMessage(newFullMessage, lastUserReplyFromServer: lastUserMessageFromServer){}

        // ... 保留你原有的interaction逻辑 ...

        contentHandler(bestAttemptContent ?? request.content)
    }
    
    // ... 其他函数 ...
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
    
}


//本地存储的时候会有 MessageID
extension LocalMessage {
    func toServerMessage() -> ServerMessage {
        ServerMessage(role: role, content: content)
    }
}

struct ServerMessage: Codable {
    enum Role: String, Codable {
        case user
        case assistant
        case system
    }
    
    let role: Role
    let content: String
}

struct LocalMessage: Identifiable, Codable, Equatable {
    let id: UUID?
    let role: ServerMessage.Role
    let content: String
    let timestamp: Date // 添加的新字段

    static func == (lhs: LocalMessage, rhs: LocalMessage) -> Bool {
        return lhs.id == rhs.id && lhs.role == rhs.role && lhs.content == rhs.content && lhs.timestamp == rhs.timestamp
    }
}


struct ServerRequest: Codable {
    let messages: [ServerMessage]
}

import UserNotifications
import CoreData
import UIKit
import Intents

class NotificationService: UNNotificationServiceExtension {
    
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    
    let appGroupName = "group.com.penghao.BuddyPark"
    var persistentContainer: NSPersistentContainer!
    var globalSessionManager: SessionManager?
    
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
        globalSessionManager = SessionManager(context: container.viewContext)  // 使用 viewContext
    }
    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent) ?? bestAttemptContent
        
        
        // 打印接收到的推送通知内容
        print("接收到的推送通知内容: \(request.content.userInfo)")
        
        // 设置CoreData
        setupCoreDataStack()
        
        // 使用新的SessionManager和MessageManager逻辑处理消息
        let userInfo = request.content.userInfo
        let characteridString = (userInfo["aps"] as? [String: Any])?["characterid"] as? String
        guard let characterid = Int32(characteridString ?? "") else {
            print("无法从推送通知中获取 characterid")
            contentHandler(bestAttemptContent ?? request.content) // 确保总是回调 contentHandler
            return
        }
        print("成功获取 characterid: \(characterid)")
        
        if let messageManager = globalSessionManager?.session(for: characterid) {
            print("成功获取或创建对应 characterid 的 MessageManager")
            let fullText = (userInfo["aps"] as? [String: Any])?["full-text"] as? String
            let lastUserMessageFromServer = (userInfo["aps"] as? [String: Any])?["users-reply"] as? String
            
            let newFullMessage = LocalMessage(id: UUID(), role: "assistant", content: fullText ?? request.content.body, timestamp: Date())
            messageManager.appendFullMessage(newFullMessage, lastUserReplyFromServer: lastUserMessageFromServer){}
        } else {
            print("无法获取或创建对应 characterid 的 MessageManager")
        }
        
        contentHandler(bestAttemptContent ?? request.content)
    }
    
    
    override func serviceExtensionTimeWillExpire() {
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}

class SessionManager: ObservableObject {
    private var sessions: [Int32: MessageManager] = [:]
    private let context: NSManagedObjectContext // 添加 context 属性
    
    // 添加构造函数以接收 context
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    func session(for characterid: Int32) -> MessageManager {
        if let session = sessions[characterid] {
            print("找到了与 characterid: \(characterid) 对应的 Session")
            return session
        } else {
            print("没有找到与 characterid: \(characterid) 对应的 Session, 创建新的 Session")
            let newSession = MessageManager(characterid: characterid, context: context)
            sessions[characterid] = newSession
            return newSession
        }
    }
    
}

class MessageManager: ObservableObject {
    
    @Published var messages: [LocalMessage] = []
    @Published var lastUpdated = Date()
    @Published var isTyping = false
    private var contact: Contact
    
    var context: NSManagedObjectContext {
        return CoreDataManager.shared.mainManagedObjectContext
    }
    
    
    enum UserRole: String {
        case user
        case assistant
    }
    
    init(characterid: Int32, context: NSManagedObjectContext) {
        
        let fetchRequest: NSFetchRequest<Contact> = Contact.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "characterid == %d", characterid)
        
        do {
            let contacts = try context.fetch(fetchRequest)
            guard let contact = contacts.first else {
                fatalError("未找到与 characterid 匹配的 Contact")
            }
            self.contact = contact
            self.messages = loadMessages()
        } catch {
            fatalError("获取 Contact 失败: \(error)")
        }
    }
    
    var contactName: String {
        return contact.name ?? "未知联系人"
    }
    
    private func loadMessages() -> [LocalMessage] {
        guard let messagesSet = contact.messages else {
            print("Failed to cast messages to correct type.")
            return []
        }
        
        return messagesSet.array.compactMap {
            $0 as? Message
        }.map {
            LocalMessage(id: $0.id ?? UUID(),
                         role: $0.role ?? "user",
                         content: $0.content ?? "",
                         timestamp: $0.timestamp ?? Date())
        }.sorted(by: { $0.timestamp < $1.timestamp })
    }
    
    
    
    func appendFullMessage(_ newMessage: LocalMessage,
                           lastUserReplyFromServer: String?,
                           isFromBackground: Bool? = nil,
                           completion: @escaping () -> Void) {
        if isFromBackground == true { self.messages = self.loadMessages() }
        if newMessage.role == UserRole.user.rawValue || newMessage.content.last == "#" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.isTyping = false }
        }
        
        let shouldAppend = handleMessageAppending(newMessage)
        if shouldAppend {
            // 增加 newMessageNum 的值
            contact.newMessageNum += 1
            CoreDataManager.shared.saveChanges()
            completion()
        }
        DispatchQueue.main.async { self.lastUpdated = Date() }
    }
    
    func saveMessage(_ localMessage: LocalMessage) {
        let newMessage = Message(context: self.context)
        newMessage.id = localMessage.id
        newMessage.role = localMessage.role
        newMessage.content = localMessage.content
        newMessage.timestamp = localMessage.timestamp
        newMessage.characterid = self.contact.characterid
        newMessage.contact = self.contact
        
        // Ensure ordered relationship
        let existingMessages = self.contact.messages ?? NSOrderedSet()
        let mutableMessages = existingMessages.mutableCopy() as! NSMutableOrderedSet
        mutableMessages.add(newMessage)
        self.contact.messages = mutableMessages.copy() as? NSOrderedSet
        CoreDataManager.shared.saveChanges()
        
        self.messages.append(localMessage)  // 这里同步更新 messages 数组
        self.lastUpdated = Date()  // 这里更新 lastUpdated 以通知 SwiftUI 进行刷新
    }
    
    private func handleMessageAppending(_ newMessage: LocalMessage) -> Bool {
        guard let lastMessage = messages.last else {
            saveMessage(newMessage)
            return true
        }
        
        switch (lastMessage.role, newMessage.role) {
        case (UserRole.user.rawValue, UserRole.user.rawValue):
            let combinedContent = lastMessage.content + "#" + newMessage.content
            let combinedMessage = LocalMessage(id: newMessage.id, role: UserRole.user.rawValue, content: combinedContent, timestamp: Date())
            removeMessage(lastMessage)  // 删除原始消息
            saveMessage(combinedMessage)
            return true  // 为了确保新消息被添加，我们返回 true
        case (UserRole.assistant.rawValue, UserRole.assistant.rawValue) where newMessage.content.count > lastMessage.content.count:
            saveMessage(newMessage)
            return true
        default:
            saveMessage(newMessage)
            return true
        }
    }
    
    private func removeMessage(_ localMessage: LocalMessage) {
        // 首先从本地数组中删除
        if let index = messages.firstIndex(where: { $0.id == localMessage.id }) {
            messages.remove(at: index)
        }
        
        // 然后从 CoreData 中删除
        let fetchRequest: NSFetchRequest<Message> = Message.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", localMessage.id as CVarArg)
        
        do {
            let fetchedMessages = try context.fetch(fetchRequest)
            if let messageToDelete = fetchedMessages.first {
                context.delete(messageToDelete)
                try context.save()
            }
        } catch {
            print("Error removing message from CoreData: \(error.localizedDescription)")
        }
    }
    
    enum RequestType: String {
        case newMessage = "new-message"
        case appRestart = "app-restart"
    }
}

extension LocalMessage {
    func toServerMessage() -> ServerMessage {
        ServerMessage(role: role, content: content, timestamp: timestamp) // 将 timestamp 也转换过去
    }
}

struct ServerMessage: Codable {
    let role: String
    let content: String
    let timestamp: Date // 添加新字段
}

struct LocalMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let role: String
    let content: String
    let timestamp: Date // 添加的新字段
    
    static func == (lhs: LocalMessage, rhs: LocalMessage) -> Bool {
        return lhs.id == rhs.id && lhs.role == rhs.role && lhs.content == rhs.content && lhs.timestamp == rhs.timestamp
    }
}


struct LocalMessageWithLastReply: Identifiable, Codable, Equatable {
    let id: UUID?
    let role: String
    let content: String
    let lastUserMessage: String
    
    static func == (lhs: LocalMessageWithLastReply, rhs: LocalMessageWithLastReply) -> Bool {
        return lhs.id == rhs.id && lhs.role == rhs.role && lhs.content == rhs.content && lhs.lastUserMessage == rhs.lastUserMessage
    }
}


struct ServerRequest: Codable {
    let messages: [ServerMessage]
}
final class CoreDataManager {
    static let shared = CoreDataManager(modelName: "BuddyPark")
    
    private let modelName: String
    
    init(modelName: String) {
        self.modelName = modelName
        setupNotificationHandling()
    }
    
    private lazy var privateManagedObjectContext: NSManagedObjectContext = {
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = self.persistantStoreCoordinator
        return context
    }()
    
    private(set) lazy var mainManagedObjectContext: NSManagedObjectContext = {
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.parent = self.privateManagedObjectContext
        return context
    }()
    
    private lazy var managedObjectModel: NSManagedObjectModel = {
        guard let dataModelUrl = Bundle.main.url(forResource: self.modelName, withExtension: "momd") else { fatalError("Unable to find data model url") }
        guard let dataModel = NSManagedObjectModel(contentsOf: dataModelUrl) else { fatalError("Unable to find data model") }
        return dataModel
    }()
    
    private lazy var persistantStoreCoordinator: NSPersistentStoreCoordinator = {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let fileManager = FileManager.default
        let storeName = "\(self.modelName).sqlite"
        let directory = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.com.penghao.BuddyPark")!
        let storeUrl = directory.appendingPathComponent(storeName)
        
        let options = [
            NSMigratePersistentStoresAutomaticallyOption : true,
            NSInferMappingModelAutomaticallyOption : true,
        ]
        
        do {
            try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeUrl, options: options)
        } catch {
            fatalError("Unable to add store: \(error)")
        }
        
        return coordinator
    }()
    
    func saveChanges() {
        mainManagedObjectContext.perform {
            do {
                if self.mainManagedObjectContext.hasChanges {
                    try self.mainManagedObjectContext.save()
                }
            } catch {
                print("Saving error (child context): \(error.localizedDescription)")
            }
            do {
                if self.privateManagedObjectContext.hasChanges {
                    try self.privateManagedObjectContext.save()
                }
            } catch {
                print("Saving error (parent context): \(error.localizedDescription)")
            }
        }
    }
    
    @objc private func saveChanges(notification: Notification) {
        saveChanges()
    }
    
    private func setupNotificationHandling() {
        NotificationCenter.default.addObserver(self, selector: #selector(saveChanges(notification:)), name: UIApplication.willTerminateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(saveChanges(notification:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
}

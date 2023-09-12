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
        setupCoreDataStack()
        
        guard let userInfo = request.content.userInfo as? [String: Any],
              let apsData = userInfo["aps"] as? [String: Any],
              let characteridString = apsData["characterid"] as? String,
              let characterid = Int32(characteridString) else {
                contentHandler(bestAttemptContent ?? request.content) // 确保总是回调 contentHandler
                return
        }
                
        if let sharedDirectoryUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: self.appGroupName) {
            let avatarDirectory = sharedDirectoryUrl.appendingPathComponent("CharacterAvatar") // 修正这里的目录名
            let imagePath = avatarDirectory.appendingPathComponent("\(characterid)").path
            if FileManager.default.fileExists(atPath: imagePath) {
                
                let avatarImageURL = URL(fileURLWithPath: imagePath)
                let avatarImage = INImage(url: avatarImageURL)
                
                let notificationTitle = request.content.title

                let person = INPerson(personHandle: INPersonHandle(value: characteridString, type: .unknown),
                                      nameComponents: nil,
                                      displayName: notificationTitle,
                                      image: avatarImage,
                                      contactIdentifier: nil,
                                      customIdentifier: characteridString)
                
                let intent = INSendMessageIntent(recipients: nil,
                                                 outgoingMessageType: .outgoingMessageText,
                                                 content: notificationTitle,
                                                 speakableGroupName: nil,
                                                 conversationIdentifier: characteridString,
                                                 serviceName: nil,
                                                 sender: person,
                                                 attachments: nil)

                
                let interaction = INInteraction(intent: intent, response: nil)
                interaction.direction = INInteractionDirection.incoming
                
                interaction.donate { error in
                    if let error = error {
                    } else {
                    }
                    
                    do {
                        let updatedContent = try self.bestAttemptContent?.updating(from: intent)
                        contentHandler(updatedContent ?? request.content)
                    } catch {
                        contentHandler(self.bestAttemptContent ?? request.content)
                    }
                }
            } else {
                contentHandler(bestAttemptContent ?? request.content)
            }
        }
        
        if let messageManager = globalSessionManager?.session(for: characterid) {
            
            let fullText = (userInfo["aps"] as? [String: Any])?["full-text"] as? String
            let messageUUID: UUID
            if let messageUUIDString = (userInfo["aps"] as? [String: Any])?["message-uuid"] as? String,
               let validUUID = UUID(uuidString: messageUUIDString) {
                messageUUID = validUUID
            } else {
                messageUUID = UUID() // 创建一个新的 UUID
            }
            let lastUserMessageFromServer = (userInfo["aps"] as? [String: Any])?["users-reply"] as? String
            let newFullMessage = LocalMessage(id: messageUUID, role: "assistant", content: fullText ?? request.content.body, timestamp: Date())
            messageManager.appendFullMessage(newFullMessage, lastUserReplyFromServer: lastUserMessageFromServer){
            }
        }
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
    private var context: NSManagedObjectContext // 修改为非计算属性

    enum UserRole: String {
        case user
        case assistant
    }
    
    init(characterid: Int32, context: NSManagedObjectContext) {
        self.context = context // 使用从外部传入的 context
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
        return contact.name!
    }
    
    private func loadMessages() -> [LocalMessage] {
        guard let messagesSet = contact.messages else {
            print("Failed to cast messages to correct type.")
            return []
        }
        
        let localMessages = messagesSet.array.compactMap {
            $0 as? Message
        }.map {
            LocalMessage(id: $0.id ?? UUID(),
                         role: $0.role ?? "user",
                         content: $0.content ?? "",
                         timestamp: $0.timestamp ?? Date())
        }.sorted(by: { $0.timestamp < $1.timestamp })
        
        // 打印消息
        for message in localMessages {
            print("ID: \(message.id), Role: \(message.role), Content: \(message.content), Timestamp: \(message.timestamp)")
        }
        return localMessages
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
            contact.newMessageNum += 1
            CoreDataManager.shared.saveChanges()
            completion()
        }
        DispatchQueue.main.async {
            self.lastUpdated = Date()
            self.messages = self.loadMessages()

        }
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
        
        do {
              try self.context.save()
          } catch {
              print("保存消息到 CoreData 失败: \(error)")
          }
    }


    private func handleMessageAppending(_ newMessage: LocalMessage) -> Bool {
        guard let lastMessage = messages.last else {
            saveMessage(newMessage)
            return true
        }
        
        if lastMessage.role == UserRole.user.rawValue && newMessage.role == UserRole.user.rawValue {
            let combinedContent = lastMessage.content + "#" + newMessage.content
            let combinedMessage = LocalMessage(id: newMessage.id, role: UserRole.user.rawValue, content: combinedContent, timestamp: Date())
            removeMessage(lastMessage)
            saveMessage(combinedMessage)
            return true
        }
        
        saveMessage(newMessage)
        return true
    }

    
    private func removeMessage(_ localMessage: LocalMessage) {
        if let index = messages.firstIndex(where: { $0.id == localMessage.id }) {
            messages.remove(at: index)
        }
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

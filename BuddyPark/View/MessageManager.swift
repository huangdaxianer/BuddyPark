import Foundation
import CoreData
import AudioToolbox
import Combine
import UIKit
import CryptoKit


class SessionManager: ObservableObject {
    private var sessions: [Int32: MessageManager] = [:]
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    func session(for characterid: Int32) -> MessageManager {
        if let session = sessions[characterid] {
            return session
        } else {
            let newSession = MessageManager(characterid: characterid, context: context)
            sessions[characterid] = newSession
            return newSession
        }
    }
    
    @objc func appWillEnterForeground() {
        context.refreshAllObjects()
        for (_, session) in sessions {
            context.performAndWait {
                session.refreshAndLoadMessages() // 用新方法代替 loadMessages()
            }
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
    
    public func loadMessages() {
        guard let messagesSet = contact.messages else {
            self.messages = []
            return
        }
        
        self.messages = messagesSet.array.compactMap {
            $0 as? Message
        }.map {
            LocalMessage(id: $0.id ?? UUID(),
                         role: $0.role ?? "user",
                         content: $0.content ?? "",
                         timestamp: $0.timestamp ?? Date())
        }.sorted(by: { $0.timestamp < $1.timestamp })
    }
    
    var contactName: String {
        return contact.name ?? "未知联系人"
    }
    
    private func loadMessages() -> [LocalMessage] {
        guard let messagesSet = contact.messages else {
            return []
        }
        
        let loadedMessages = messagesSet.array.compactMap { $0 as? Message }.map { message -> LocalMessage in
            let localMessage = LocalMessage(id: message.id ?? UUID(),
                                            role: message.role ?? "user",
                                            content: message.content ?? "",
                                            timestamp: message.timestamp ?? Date())
            // 打印消息内容
            print("Loading message: ID: \(localMessage.id), Role: \(localMessage.role), Content: '\(localMessage.content)', Timestamp: \(localMessage.timestamp)")
            return localMessage
        }.sorted(by: { $0.timestamp < $1.timestamp })
        
        return loadedMessages
    }

    
    func appendFullMessage(_ newMessage: LocalMessage, lastUserReplyFromServer: String?, isFromBackground: Bool? = nil, completion: @escaping () -> Void) {
        print("appendFullMessage called with newMessage: \(newMessage), lastUserReplyFromServer: \(lastUserReplyFromServer ?? "nil"), isFromBackground: \(isFromBackground ?? false)")
        
        if let isFromBG = isFromBackground, isFromBG == true {
            self.messages = self.loadMessages()
            print("Loaded messages from background")
        }
        
        // 检查是否存在任何用户角色的消息
        let hasUserMessages = messages.contains { $0.role == UserRole.user.rawValue }
        print("hasUserMessages: \(hasUserMessages)")
        
        // 如果不存在任何用户角色的消息，或者lastUserReplyFromServer为nil，则直接添加新消息
//        if !hasUserMessages || lastUserReplyFromServer == nil {
//            print("No user messages or lastUserReplyFromServer is nil, saving new message")
//            saveMessage(newMessage)
//            completion()
//            DispatchQueue.main.async {
//                self.lastUpdated = Date()
//                print("Updated lastUpdated date to \(self.lastUpdated)")
//            }
//            return
//        }
//        
        // 存在用户消息且lastUserReplyFromServer不为nil时，进行匹配检查
        if let lastUserReplyFromServer = lastUserReplyFromServer, let lastUserMessage = messages.filter({ $0.role == UserRole.user.rawValue }).last {
            print("Checking last user message for match with server's last reply")
            if lastUserMessage.content != lastUserReplyFromServer {
                print("Last user message content (\(lastUserMessage.content)) does not match the server's last reply (\(lastUserReplyFromServer)). Aborting message append.")
                return // 如果不匹配，则不添加新消息
            }
        }
        
        print("About to check if we should append message")
        let shouldAppend = handleMessageAppending(newMessage)
        print("shouldAppend result: \(shouldAppend)")
        if shouldAppend {
            // 增加 newMessageNum 的值
            contact.newMessageNum += 1
            contact.isNew = false
            print("Incremented newMessageNum to \(contact.newMessageNum) and set isNew to false")
            context.refreshAllObjects()
            CoreDataManager.shared.saveChanges()
            completion()
            print("Core data changes saved")
        } else {
            print("Message append not required, skipping")
        }
        
        DispatchQueue.main.async {
            self.lastUpdated = Date()
            print("Updated lastUpdated date to \(self.lastUpdated) outside of shouldAppend check")
        }
    }


    
    public func refreshAndLoadMessages() {
           // 重新获取 contact
           let fetchRequest: NSFetchRequest<Contact> = Contact.fetchRequest()
           fetchRequest.predicate = NSPredicate(format: "characterid == %d", contact.characterid)
           
           do {
               let contacts = try context.fetch(fetchRequest)
               guard let refreshedContact = contacts.first else {
                   fatalError("未找到与 characterid 匹配的 Contact")
               }
               self.contact = refreshedContact
               self.messages = loadMessages()
           } catch {
               fatalError("获取 Contact 失败: \(error)")
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
        let existingMessages = self.contact.messages ?? NSOrderedSet()
        let mutableMessages = existingMessages.mutableCopy() as! NSMutableOrderedSet
        mutableMessages.add(newMessage)
        self.contact.messages = mutableMessages.copy() as? NSOrderedSet
        CoreDataManager.shared.saveChanges()
        
        self.messages.append(localMessage)
        self.lastUpdated = Date()
    }
    
    private func handleMessageAppending(_ newMessage: LocalMessage) -> Bool {
        
        
        guard let lastMessage = messages.last else {
            saveMessage(newMessage)
            return true // 当没有最后一条消息时，保存新消息并返回true
        }
        
        // 如果最后一条消息和新消息属于同一个角色
        if lastMessage.role == newMessage.role {
            // 根据角色的不同，处理消息合并或更新
            switch newMessage.role {
            case UserRole.user.rawValue:
                // 合并用户消息的内容，并生成一个新的UUID
                let combinedContent = "\(lastMessage.content)#\(newMessage.content)"
                let combinedMessage = LocalMessage(id: UUID(), role: UserRole.user.rawValue, content: combinedContent, timestamp: Date())
                removeMessage(lastMessage) // 移除旧的消息
                saveMessage(combinedMessage) // 保存新合并的消息
                return true
            case UserRole.assistant.rawValue:
                // 如果是助手消息，并且新消息内容更新，则更新消息
                if newMessage.content.count > lastMessage.content.count {
                    let updatedMessage = LocalMessage(id: UUID(), role: UserRole.assistant.rawValue, content: newMessage.content, timestamp: Date())
                    removeMessage(lastMessage)
                    saveMessage(updatedMessage)
                    return true
                }
            default:
                break // 对于其他情况，不做处理，会走到函数末尾的返回语句
            }
        } else {
            // 角色不同，直接保存新消息
            saveMessage(newMessage)
            return true
        }
        return false
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
        case greetingMessage = "greeting-message"
    }

    
    func sendRequest(type: RequestType, retryOnTimeout: Bool = true) {
        let completeURLString = serviceURL + "sendMessage"
        guard let url = URL(string: completeURLString) else { return }
        var urlRequest = URLRequest(url: url)
        urlRequest.timeoutInterval = 60.0
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(type.rawValue, forHTTPHeaderField: "X-Request-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "Authorization")
        if let uuidString = self.contact.id?.uuidString { urlRequest.setValue(uuidString, forHTTPHeaderField: "X-Dialogueid") }
        urlRequest.setValue(String(self.contact.characterid), forHTTPHeaderField: "X-characterid")
        urlRequest.setValue(UserProfileManager.shared.getUserID() ?? "", forHTTPHeaderField: "X-Userid")
        urlRequest.setValue(UserDefaults.standard.string(forKey: "deviceToken") ?? "", forHTTPHeaderField: "X-Device-Token")

        switch type {
        case .newMessage, .appRestart:
            // 现有逻辑，处理 newMessage 和 appRestart 类型的请求
            if type == .newMessage && SubscriptionManager.shared.canSendMessage() {
                let request = ServerRequest(messages: messages.map { $0.toServerMessage() })
                do {
                    let requestBody = try JSONEncoder().encode(request)
                    urlRequest.httpBody = requestBody
                    urlRequest.httpMethod = "POST"
                } catch {
                    print("Error encoding request body: \(error.localizedDescription)")
                    return
                }
            } else {
                urlRequest.httpMethod = "GET"
            }
        case .greetingMessage:
            let predefinedMessage: [String: Any] = [
                "role": "user",
                "content": "你好呀",
                "timestamp": Date().timeIntervalSince1970
            ]
            let predefinedJSON: [String: Any] = [
                "messages": [predefinedMessage]
            ]
            do {
                let requestBody = try JSONSerialization.data(withJSONObject: predefinedJSON, options: [])
                urlRequest.httpBody = requestBody
                urlRequest.httpMethod = "POST"
            } catch {
                print("Error encoding predefined JSON to request body: \(error.localizedDescription)")
                return
            }
        }

        print("Request URL: \(urlRequest.url?.absoluteString ?? "No URL")")
        print("Request Method: \(urlRequest.httpMethod ?? "No Method")")
        print("Request Headers: \(urlRequest.allHTTPHeaderFields ?? [:])")
        if let httpBody = urlRequest.httpBody, let requestBodyString = String(data: httpBody, encoding: .utf8) {
            print("Request Body: \(requestBodyString)")
        }

        URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                print("Error fetching message: \(error.localizedDescription)")
                if (error as NSError).code == NSURLErrorTimedOut && retryOnTimeout {
                    self.sendRequest(type: .appRestart, retryOnTimeout: false) // 这里递归调用处理超时重试
                }
                return
            }

            if let data = data {
                let responseString = String(data: data, encoding: .utf8) ?? "Unable to convert data to string"
                print("Server Response:", responseString)
            }
        }.resume()
    }
}
    
extension LocalMessage {
    func toServerMessage() -> ServerMessage {
        ServerMessage(role: role, content: content, timestamp: timestamp)
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

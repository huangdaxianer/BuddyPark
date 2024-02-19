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
        if isFromBackground == true { self.messages = self.loadMessages() }

        // 检查最后一条用户消息是否与服务端提供的匹配
        if let lastUserReplyFromServer = lastUserReplyFromServer {
            // 查找最后一条用户角色的消息
            if let lastUserMessage = messages.filter({ $0.role == UserRole.user.rawValue }).last {
                print("Checking last user message for match.")
                if lastUserMessage.content != lastUserReplyFromServer {
                    print("Last user message does not match the server's last reply. Aborting message append.")
                    return // 如果不匹配，则不添加新消息
                }
            }
        }

        let shouldAppend = handleMessageAppending(newMessage)
        if shouldAppend {
            // 增加 newMessageNum 的值
            contact.newMessageNum += 1
            context.refreshAllObjects()
            CoreDataManager.shared.saveChanges()
            completion()
        }
        DispatchQueue.main.async { self.lastUpdated = Date() }
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
        
        // 如果以上情况都不匹配，或者是助手消息但内容没有更新，这里返回false
        // 表示没有进行消息合并或更新
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
        
        if type == .newMessage {
            if SubscriptionManager.shared.canSendMessage() {
                let request = ServerRequest(messages: messages.map { $0.toServerMessage() })
                
                do {
                    let requestBody = try JSONEncoder().encode(request)
                    urlRequest.httpBody = requestBody
                    print("sending message")
                } catch {
                    print("Error encoding request body: \(error.localizedDescription)")
                    return
                }
                urlRequest.httpMethod = "POST"
            } else {
                urlRequest.httpMethod = "GET"
            }
            
            
            URLSession.shared.dataTask(with: urlRequest) { data, response, error in
                if let error = error {
                    print("Error fetching message: \(error.localizedDescription)")
                    if (error as NSError).code == NSURLErrorTimedOut && retryOnTimeout {
                        self.sendRequest(type: .appRestart, retryOnTimeout: false)
                        print("错误了")
                    }
                    return
                }
                
                if let data = data {
                    let decoder = JSONDecoder()

                    do {
                        if let jsonResult = try? JSONSerialization.jsonObject(with: data, options: []) {
                            print("Server Response:", jsonResult)
                        } else {
                            let responseString = String(data: data, encoding: .utf8) ?? "Unable to convert data to string"
                            print("Server Response (String):", responseString)
                        }
                    } catch {
                        print("Error decoding the response:", error)
                    }
                }

            }.resume()
        } else {
            return
        }
    }
}
    

//本地存储的时候会有 MessageID
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

import Foundation
import CoreData
import AudioToolbox
import Combine
import UIKit

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

//新方法就是输入所有完整的消息，只比长短，然后更新消息



//
//    func testNetwork() {
//        let testNetworkURL = URL(string: "https://service-ly7fdync-1251732024.jp.apigw.tencentcs.com/release/")
//        var request = URLRequest(url: testNetworkURL!)
//        request.httpMethod = "GET"
//
//        let task = URLSession.shared.dataTask(with: request) { [weak self] (data, response, error) in
//            if let _ = error {
//                // 处理错误，例如你可以打印错误信息，或者显示一个错误提示给用户
//            } else if let _ = data {
//                // 成功获取数据，更新 isTyping
//                DispatchQueue.main.async {
//                    self?.isTyping = true
//                }
//            }
//        }
//        task.resume()
//    }
//
//    enum RequestType: String {
//        case newMessage = "new-message"
//        case appRestart = "app-restart"
//    }
//
//    //这个方法是用来处理后台发送消息刷新的操作，因为新加载一个 loadMessage 可以引起 message 的变化，这样就能让前台的消息更新
//    func reloadMessages() {
//        messages = loadMessages()
//    }





//    func resetDialogue() {
//        let currentDialogueID =  self.getOrCreateDialogueID().uuidString
//        self.clearServerMessage(dialogueID: currentDialogueID,retryOnTimeout: true)
//
//        let userDefaults = UserDefaults.standard
//        let dialogueIDKey = "DialogueID"
//        let uuid = UUID()
//        userDefaults.set(uuid.uuidString, forKey: dialogueIDKey)
//        self.messages.removeAll()
//        if let userDefaults = UserDefaults(suiteName: appGroupName) {
//            userDefaults.removeObject(forKey: storageKey)
//        }
//        UserDefaults.standard.set(false, forKey: "CharacterConfigCompleted")
//    }


//    func getOrCreateDialogueID() -> UUID {
//        let userDefaults = UserDefaults.standard
//        let uuidKey = "DialogueID"
//
//        if let uuidString = userDefaults.string(forKey: uuidKey), let uuid = UUID(uuidString: uuidString) {
//            return uuid
//        } else {
//            let uuid = UUID()
//            userDefaults.set(uuid.uuidString, forKey: uuidKey)
//            return uuid
//        }
//    }

//    private func setupNotificationObserver() {
//        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
//            .sink { [weak self] _ in
//
//                //这下面有一个可能导致问题的代码
//                self?.sendRequest(type: .appRestart)
//                print("sending requests")
//            }
//            .store(in: &cancellables)
//    }


//    func clearServerMessage(dialogueID: String, retryOnTimeout: Bool = true) {
//        guard let url = URL(string: deleteCharacterURL) else { return }
//        var urlRequest = URLRequest(url: url)
//        urlRequest.setValue(dialogueID, forHTTPHeaderField: "X-Dialogue-UUID")
//        urlRequest.timeoutInterval = 5.0
//        urlRequest.httpMethod = "DELETE"
//
//        URLSession.shared.dataTask(with: urlRequest) { data, response, error in
//            if let error = error {
//                //超时重试
//                if (error as NSError).code == NSURLErrorTimedOut && retryOnTimeout {
//                    self.clearServerMessage(dialogueID: dialogueID, retryOnTimeout: false)
//                }
//                return
//            }
//        }.resume()
//    }


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

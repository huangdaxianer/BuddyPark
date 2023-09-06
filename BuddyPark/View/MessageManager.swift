import Foundation
import CoreData
import AudioToolbox
import Combine
import UIKit

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
    private let context: NSManagedObjectContext
    

    enum UserRole: String {
        case user
        case assistant
    }
    
    init(characterid: Int32, context: NSManagedObjectContext) {
        self.context = context
        
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
        guard let messagesSet = contact.messages as? Set<Message> else {
            print("Failed to cast messages to correct type.")
            return []
        }
        
        return messagesSet.map {
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
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            completion()
        }
        DispatchQueue.main.async { self.lastUpdated = Date() }
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
    
    func saveMessage(_ localMessage: LocalMessage) {
        let newMessage = Message(context: self.context)
        newMessage.id = localMessage.id
        newMessage.role = localMessage.role
        newMessage.content = localMessage.content
        newMessage.timestamp = localMessage.timestamp
        newMessage.characterid = self.contact.characterid
        newMessage.contact = self.contact
        self.contact.addToMessages(newMessage)
        
        do {
            try self.context.save()
            self.messages.append(localMessage)  // 这里同步更新 messages 数组
            self.lastUpdated = Date()  // 这里更新 lastUpdated 以通知 SwiftUI 进行刷新
        } catch {
            print("Error saving message: \(error.localizedDescription)")
        }
    }
    
    enum RequestType: String {
        case newMessage = "new-message"
        case appRestart = "app-restart"
    }
    
    func sendRequest(type: RequestType, retryOnTimeout: Bool = true) {
        let sendMessageEndpoint = "sendMessage"
        let completeURLString = messageService + sendMessageEndpoint
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
                    //let lastMessage = try decoder.decode(LocalMessageWithLastReply.self, from: data) //这个是新消息
                    //let newLastMessage = LocalMessage(id: UUID(), role: lastMessage.role, content: lastMessage.content, timestamp: Date())
                    //self.appendFullMessage(newLastMessage, lastUserReplyFromServer: lastMessage.lastUserMessage) {}
                    print("没有超时，正常返回结果了")
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

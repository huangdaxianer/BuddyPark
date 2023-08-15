//import Foundation
//import AudioToolbox
//import Combine
//import UIKit
//
//class SessionManager {
//    private var sessions: [Int32: MessageManager] = [:]
//    func session(for characterid: Int32) -> MessageManager {
//        if let session = sessions[characterid] {
//            return session
//        } else {
//            let newSession = MessageManager(characterid: characterid) // 创建新的MessageManager实例时传递characterid
//            sessions[characterid] = newSession
//            return newSession
//        }
//    }
//}
//
//
//
//class MessageManager: ObservableObject {
//    
//    @Published private(set) var messages: [LocalMessage] = []
//    @Published var lastUpdated = Date()
//    @Published var isTyping = false
//    let characterid: Int32
//
//    init(characterid: Int32) {
//        self.characterid = characterid
//        messages = loadMessages()
//        self.sendRequest(type: .appRestart)
//        setupNotificationObserver()
//    }
//    
//    //新方法就是输入所有完整的消息，只比长短，然后更新消息
//    func appendFullMessage(_ newMessage: LocalMessage,
//                           lastUserReplyFromServer: String?,
//                           isFromBackground: Bool? = nil,
//                           completion: @escaping () -> Void) {
//
//
//        //添加用户消息要看上一条消息是不是用户发的，如果是用户发的就通过井号添加，如果不存在或者不是用户发的就直接添加
//        if newMessage.role == .user {
//            if isFromBackground == true {
//                self.messages = self.loadMessages()
//            }
//            
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
//                self.isTyping = false
//            }
//
//             if let lastMessage = messages.last {
//                 if lastMessage.role == .user {
//                     let combinedContent = lastMessage.content + "#" + newMessage.content
//                     let combinedMessage = LocalMessage(id: newMessage.id, role: .user, content: combinedContent, timestamp: Date())
//                     DispatchQueue.main.async {
//                         self.messages.removeLast()
//                         self.messages.append(combinedMessage)
//                         self.saveMessages()
//                         completion()
//                     }
//
//                 } else {
//                     DispatchQueue.main.async {
//                         self.messages.append(newMessage)
//                         self.saveMessages()
//                         completion()
//                     }
//                 }
//             } else {
//                 DispatchQueue.main.async {
//                     self.messages.append(newMessage)
//                     self.saveMessages()
//                     completion()
//                 }
//             }
//         } else if newMessage.role == .assistant {
//            // 比较收到的消息是不是针对用户上一条的回复，如果不是的话就不添加消息
//            if let lastUserReplyFromServer = lastUserReplyFromServer,
//               let lastUserMessageIndex = messages.lastIndex(where: { $0.role == .user }),
//               messages[lastUserMessageIndex].content != lastUserReplyFromServer {
//                print("要添加的消息不是针对上一条的回复，所以不添加", messages[lastUserMessageIndex].content, lastUserReplyFromServer)
//                //这里实际上不能直接 return，还是要稍微研究一下逻辑
//                return
//            }
//             
//             self.isTyping = false
//             
//             if newMessage.content.last == "#" {
//                 // 如果是的话，就在 1.5 秒后再把  self.isTyping 设置成 true
//                 DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
//                     self.isTyping = true
//                 }
//             }
//             
//            // 先判断是不是收到的首条 assistant 的消息，如果不是且如果新消息比最后一条消息长，使用新消息替换最后一条消息
//             if let lastMessage = messages.last {
//                      if lastMessage.role == .user {
//                          DispatchQueue.main.async {
//                              self.messages.append(newMessage)
//                              self.saveMessages()
//                              AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
//                              completion()
//                          }
//                      } else if lastMessage.role == .assistant {
//                          if newMessage.content.count > lastMessage.content.count {
//                              DispatchQueue.main.async {
//                                  self.messages.removeAll { $0.role == .assistant && $0.content == lastMessage.content }
//                                  self.messages.append(newMessage)
//                                  self.saveMessages()
//                                  AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
//                                  completion()
//                              }
//                          }
//                      }
//                  } else {
//                      DispatchQueue.main.async {
//                          self.messages.append(newMessage)
//                          self.saveMessages()
//                          AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
//                          completion()
//                      }
//                  }
//              }
//        //更新 lastUpdated 属性，用来刷新视图
//        DispatchQueue.main.async {
//            self.lastUpdated = Date()
//        }
//        //把 messages 数组这个消息存起来
//        let encoder = JSONEncoder()
//        do {
//            let data = try encoder.encode(messages)
//            let userDefaults = UserDefaults(suiteName: appGroupName)
//            userDefaults?.set(data, forKey: storageKey)
//        } catch {
//            print("Error saving messages: \(error.localizedDescription)")
//        }
//        print("Saved messages: \(messages)")
//    }
//    
//    func saveMessages() {
//            let encoder = JSONEncoder()
//            do {
//                let data = try encoder.encode(messages)
//                let userDefaults = UserDefaults(suiteName: appGroupName)
//                userDefaults?.set(data, forKey: storageKey)
//            } catch {
//                print("Error saving messages: \(error.localizedDescription)")
//            }
//            print("Saved messages: \(messages)")
//        }
//
//    func sendRequest(type: RequestType, retryOnTimeout: Bool = true) {
//        guard let url = URL(string: getMessageURL) else { return }
//        var urlRequest = URLRequest(url: url)
//        let Character = UserDefaults.standard.string(forKey: "Character") ?? ""
//        let encodedCharacter = Character.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
//        let deviceToken = UserDefaults.standard.string(forKey: "deviceToken") ?? ""
//        let prompt = UserDefaults.standard.string(forKey: "prompt") ?? ""
//        let userID = UserDefaults.standard.string(forKey: "userUUID") ?? ""
//        let encodedPrompt = prompt.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
//        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
//        urlRequest.setValue(apiKey, forHTTPHeaderField: "Authorization")
//        urlRequest.setValue(getOrCreateDialogueID().uuidString, forHTTPHeaderField: "X-Dialogueid")
//        urlRequest.setValue(userID, forHTTPHeaderField: "X-Userid")
//        urlRequest.setValue(type.rawValue, forHTTPHeaderField: "X-Request-Type")
//        urlRequest.setValue(encodedCharacter, forHTTPHeaderField: "X-Character")
//        urlRequest.setValue(deviceToken, forHTTPHeaderField: "X-Device-Token")
//        urlRequest.setValue(encodedPrompt, forHTTPHeaderField: "X-Prompt")
//        print("正在通过 sendrequest 发送消息，type 是", RequestType.self)
//        
//        // Set timeout interval
//        urlRequest.timeoutInterval = 60.0
//        
//        if type == .newMessage {
//            // 获取现有的 freeMessageLeft 值
//            let userDefaults = UserDefaults(suiteName: appGroupName)
//            var freeMessageLeft = userDefaults?.integer(forKey: "freeMessageLeft") ?? 0
//
//            // 确保免费消息数量大于0，然后减少1
//            if freeMessageLeft > 0 {
//                freeMessageLeft -= 1
//                userDefaults?.set(freeMessageLeft, forKey: "freeMessageLeft")
//            } else {
//                // 如果没有免费消息，请处理此情况，例如通过返回错误或通知用户
//                print("No free messages left.")
//                return
//            }
//
//            let request = ServerRequest(messages: messages.map { $0.toServerMessage() })
//
//            do {
//                let requestBody = try JSONEncoder().encode(request)
//                urlRequest.httpBody = requestBody
//                print("sending message")
//            } catch {
//                print("Error encoding request body: \(error.localizedDescription)")
//                return
//            }
//            urlRequest.httpMethod = "POST"
//        } else {
//            urlRequest.httpMethod = "GET"
//        }
//
//        
//        URLSession.shared.dataTask(with: urlRequest) { data, response, error in
//            if let error = error {
//                print("Error fetching message: \(error.localizedDescription)")
//                
//                // If the error can be cast as an NSError, print more detailed information
//                if let nsError = error as NSError? {
//                    print("Error domain: \(nsError.domain)")
//                    print("Error code: \(nsError.code)")
//                    print("Error user info: \(nsError.userInfo)")
//                }
//                
//                // 超时重试
//                if (error as NSError).code == NSURLErrorTimedOut && retryOnTimeout {
//                    self.sendRequest(type: .appRestart, retryOnTimeout: false)
//                    print("错误了")
//                }
//                return
//            }
//            
//            if let data = data {
//                do {
//                    let decoder = JSONDecoder()
//                    let lastMessage = try decoder.decode(LocalMessageWithLastReply.self, from: data) //这个是新消息
//                    let newLastMessage = LocalMessage(id: UUID(), role: lastMessage.role, content: lastMessage.content, timestamp: Date())
//                    self.appendFullMessage(newLastMessage, lastUserReplyFromServer: lastMessage.lastUserMessage) {}
//                    print("没有超时，正常返回结果了")
//
//                } catch {
//                }
//            }
//        }.resume()
//    }
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
//    
//    private func loadMessages() -> [LocalMessage] {
//        let decoder = JSONDecoder()
//        if let userDefaults = UserDefaults(suiteName: appGroupName), let data = userDefaults.data(forKey: storageKey) {
//            do {
//                let messages = try decoder.decode([LocalMessage].self, from: data)
//                print("Loaded messages: \(messages)")
//                return messages
//            } catch {
//                print("Error loading messages: \(error.localizedDescription)")
//            }
//        }
//        
//        return []
//    }
//    
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
//
//    
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
//    
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
//    
//    
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
//    
//}
//
////本地存储的时候会有 MessageID
//extension LocalMessage {
//    func toServerMessage() -> ServerMessage {
//        ServerMessage(role: role, content: content, timestamp: timestamp) // 将 timestamp 也转换过去
//    }
//}
//
//struct ServerMessage: Codable {
//    enum Role: String, Codable {
//        case user
//        case assistant
//        case system
//    }
//    
//    let role: Role
//    let content: String
//    let timestamp: Date // 添加新字段
//}
//
//struct LocalMessage: Identifiable, Codable, Equatable {
//    let id: UUID?
//    let role: ServerMessage.Role
//    let content: String
//    let timestamp: Date // 添加的新字段
//
//    static func == (lhs: LocalMessage, rhs: LocalMessage) -> Bool {
//        return lhs.id == rhs.id && lhs.role == rhs.role && lhs.content == rhs.content && lhs.timestamp == rhs.timestamp
//    }
//}
//
//
//struct LocalMessageWithLastReply: Identifiable, Codable, Equatable {
//    let id: UUID?
//    let role: ServerMessage.Role
//    let content: String
//    let lastUserMessage: String
//    
//    static func == (lhs: LocalMessageWithLastReply, rhs: LocalMessageWithLastReply) -> Bool {
//        return lhs.id == rhs.id && lhs.role == rhs.role && lhs.content == rhs.content && lhs.lastUserMessage == rhs.lastUserMessage
//    }
//}
//
//
//struct ServerRequest: Codable {
//    let messages: [ServerMessage]
//}

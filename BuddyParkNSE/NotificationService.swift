import UserNotifications
import UIKit
import Intents

class NSE: UNNotificationServiceExtension {
    
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    
    let appGroupName = "group.com.penghao.BuddyPark"
    let storageKey = "messages"
    // 在整个 extension 中定义一个队列，用于同步对 UserDefaults 的读写操作
    let userDefaultsQueue = DispatchQueue(label: "group.com.penghao.monkey.userdefaults")

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        // 这里开始在队列中处理 UserDefaults
        userDefaultsQueue.sync {
            let userDefaults = UserDefaults(suiteName: "group.com.penghao.monkey")
            let badgeNumber = userDefaults?.integer(forKey: "badgeNumber") ?? 0
            userDefaults?.set(badgeNumber + 1, forKey: "badgeNumber")
            bestAttemptContent?.badge = NSNumber(value: badgeNumber + 1)
            
            // 从通知中提取 freeMessageLeft，并将其保存到 UserDefaults
            if let freeMessageLeftString = (request.content.userInfo["aps"] as? [String: Any])?["free-message-left"] as? String,
               let freeMessageLeft = Int(freeMessageLeftString) {
                userDefaults?.set(freeMessageLeft, forKey: "freeMessageLeft")
            }
        }

        // 从通知中获取消息并包装成结构体
        let fullText = (request.content.userInfo["aps"] as? [String: Any])?["full-text"] as? String
        let lastUserReplyFromServer = (request.content.userInfo["aps"] as? [String: Any])?["users-reply"] as? String
        let newMessage = LocalMessage(id: UUID(), role: .assistant, content: fullText ?? request.content.body, timestamp: Date())

        var NSEmessages: [LocalMessage] = []
        let userDefaults = UserDefaults(suiteName: appGroupName)
        if let data = userDefaults?.data(forKey: storageKey) {
            let decoder = JSONDecoder()
            NSEmessages = (try? decoder.decode([LocalMessage].self, from: data)) ?? []
        }
        //判断比较最后一条消息和新消息的长度
        // 比较收到的消息是不是针对用户上一条的回复，如果不是的话就不添加消息
        if let lastUserMessageIndex = NSEmessages.lastIndex(where: { $0.role == .user }),
           NSEmessages[lastUserMessageIndex].content != lastUserReplyFromServer {
            
            // 判断 lastUserReplyFromServer 是否以 $ 开头
            if (lastUserReplyFromServer ?? "").hasPrefix("$") {
                let newUserMessage = LocalMessage(id: UUID(), role: .user, content: lastUserReplyFromServer!, timestamp: Date())
                NSEmessages.append(newUserMessage)
                NSEmessages.append(newMessage)
                //print("上一条消息是系统发的消息")
            }
            print("要添加的消息不是针对上一条的回复，所以不添加，但是这里把消息变空的逻辑还没处理")
        }


        // 先判断是不是收到的首条 assistant 的消息，如果不是且如果新消息比最后一条消息长，使用新消息替换最后一条消息
        if let lastMessage = NSEmessages.last {
            if lastMessage.role == .user {
                // 如果最后一条消息的角色是用户，则直接添加新的助手消息
                NSEmessages.append(newMessage)
            } else if lastMessage.role == .assistant {
                // 如果最后一条消息的角色是助手，就比较新的助手消息和最后一条助手消息的长度
                if newMessage.content.count > lastMessage.content.count {
                    NSEmessages.removeAll { $0.role == .assistant && $0.content == lastMessage.content }
                    NSEmessages.append(newMessage)
                }
            }
        }
        
        //存储消息
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(NSEmessages) {
            userDefaults?.set(data, forKey: storageKey)
        }
        
        // 现在我们要处理 interaction，记住把 contentHandler 的调用放在异步回调中
        if let userInfo = request.content.userInfo as? [String: Any],
           let personDict = userInfo["person"] as? [String: Any],
           let character = personDict["id"] as? String {
            let sharedDirectoryUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: self.appGroupName)
            let avatarUrl = sharedDirectoryUrl?.appendingPathComponent("avatar.jpeg")
            if let avatarUrl = avatarUrl, FileManager.default.fileExists(atPath: avatarUrl.path) {
                let avatarImage = INImage(url: avatarUrl)
                
                let person = INPerson(personHandle: INPersonHandle(value: character, type: .unknown),
                                      nameComponents: nil,
                                      displayName: character,
                                      image: avatarImage,
                                      contactIdentifier: nil,
                                      customIdentifier: character)
                
                let intent = INSendMessageIntent(recipients: nil,
                                                 outgoingMessageType: .outgoingMessageText,
                                                 content: "Message content",
                                                 speakableGroupName: nil,
                                                 conversationIdentifier: "unique-conversation-id-1",
                                                 serviceName: nil,
                                                 sender: person,
                                                 attachments: nil)
                
                let interaction = INInteraction(intent: intent, response: nil)
                interaction.direction = .incoming
                
                // Donate the interaction before updating notification content.
                interaction.donate { error in
                    if let error = error {
                        // Handle errors that may occur during donation.
                        print("Interaction donation failed: \(error)")
                    }
                    
                    // After donation, update the notification content.
                    do {
                        // Update notification content before displaying the
                        // communication notification.
                        let updatedContent = try self.bestAttemptContent?.updating(from: intent)
                        
                        // Call the content handler with the updated content
                        // to display the communication notification.
                        contentHandler(updatedContent ?? request.content)
                        
                    } catch {
                        // Handle errors that may occur while updating content.
                        print("[NSE] Debug info: Updating notification content failed: \(error)")
                        contentHandler(self.bestAttemptContent ?? request.content)
                    }
                }
            } else {
                // The avatar file does not exist, fall back to the original content
                contentHandler(bestAttemptContent ?? request.content)
            }
        } else {
            contentHandler(bestAttemptContent ?? request.content)
        }
    }

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

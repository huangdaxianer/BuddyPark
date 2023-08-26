import Foundation
import SwiftUI
import CoreData

class HomeViewModel: ObservableObject {
    
    //滑动喜欢之后写入数据
    func onSwiped(userProfile: ProfileCardModel, hasLiked: Bool) {
        if hasLiked {
            let context = PersistenceController.shared.container.viewContext
            let contact = Contact(context: context)
            contact.characterid = Int32(userProfile.characterId)
            contact.name = userProfile.name
            contact.lastMessage = "你好啊"
            contact.updateTime = Date()

            
            // 创建实例消息
            let sampleMessages = ["你好#很高兴认识你！", "希望我们可以成为好朋友！", "随时可以和我聊天哦！"]
            for (index, messageContent) in sampleMessages.enumerated() {
                let message = Message(context: context)
                message.content = messageContent
                message.timestamp = Date().addingTimeInterval(TimeInterval(index * 60))
                message.role = "assistant" // 假设这些实例消息都是 AI 发出的
                message.characterid = Int32(userProfile.characterId)
                message.contact = contact // 关联 Message 和 Contact
                message.id = UUID() // 为每条消息分配一个UUID
                contact.addToMessages(message) // 将消息添加到 Contact 的 messages relationship
            }

            do {
                try context.save()
                printAllContacts()
                print("保存成功!")
            } catch {
                print("保存失败: \(error.localizedDescription)")
            }
        }
    }

    
    func printAllContacts() {
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest = NSFetchRequest<Contact>(entityName: "Contact")
        
        do {
            let contacts = try context.fetch(fetchRequest)
            contacts.forEach { contact in
                print("Name: \(contact.name ?? ""), CharacterID: \(contact.characterid)")
            }
        } catch {
            print("读取失败: \(error.localizedDescription)")
        }
    }

    
}



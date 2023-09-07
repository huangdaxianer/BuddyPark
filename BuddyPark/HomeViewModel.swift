import Foundation
import SwiftUI
import CoreData

class HomeViewModel: ObservableObject {
    
    func onSwiped(userProfile: ProfileCardModel, hasLiked: Bool) {
        let context = PersistenceController.shared.container.viewContext

        if hasLiked {
            let contact = Contact(context: context)
            contact.characterid = Int32(userProfile.characterid)
            contact.name = userProfile.name
            contact.lastMessage = "你好啊"
            contact.updateTime = Date()
            contact.id = UUID()

            // 创建实例消息
            let sampleMessages = ["你好#很高兴认识你！", "希望我们可以成为好朋友！", "随时可以和我聊天哦！"]
            for (index, messageContent) in sampleMessages.enumerated() {
                let message = Message(context: context)
                message.content = messageContent
                message.timestamp = Date().addingTimeInterval(TimeInterval(index * 60))
                message.role = "assistant"
                message.characterid = Int32(userProfile.characterid)
                message.contact = contact
                message.id = UUID()
                contact.addToMessages(message)
            }
        }

        // 使用 CharacterManager 的方法更新状态
        let newStatus: CharacterManager.CharacterStatus = hasLiked ? .liked : .unliked
        CharacterManager.shared.updateCharacterStatus(characterid: Int32(userProfile.characterid), status: newStatus)
    }
}



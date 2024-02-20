import Foundation
import SwiftUI
import CoreData

class HomeViewModel: ObservableObject {
    
    func onSwiped(userProfile: ProfileCardModel, hasLiked: Bool) {
        // 使用 mainManagedObjectContext 替代原先的 persistentContainer.viewContext
        let context = CoreDataManager.shared.mainManagedObjectContext

        if hasLiked {
            let contact = Contact(context: context)
            contact.characterid = Int32(userProfile.characterid)
            contact.name = userProfile.name
//            contact.lastMessage = "你好啊"
            contact.updateTime = Date()
            contact.id = UUID()
            contact.isNew = true
            //            contact.newMessageNum = 3
            
            // 使用 saveChanges 替代原先的 saveContext
            CoreDataManager.shared.saveChanges()
            
//            let sampleMessages = ["你好#很高兴认识你！", "希望我们可以成为好朋友！", "随时可以和我聊天哦！"]
//            for (_, messageContent) in sampleMessages.enumerated() {
//                let message = Message(context: context)
//                message.content = messageContent
//                message.timestamp = Date()
//                message.role = "assistant"
//                message.characterid = Int32(userProfile.characterid)
//                message.contact = contact
//                message.id = UUID()
//                contact.addToMessages(message)
//            }
        }
        let newStatus: CharacterManager.CharacterStatus = hasLiked ? .liked : .unliked
        CharacterManager.shared.updateCharacterStatus(characterid: Int32(userProfile.characterid), status: newStatus)
    }
}





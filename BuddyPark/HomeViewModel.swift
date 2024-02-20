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
            contact.updateTime = Date()
            contact.id = UUID()
            contact.isNew = true
            CoreDataManager.shared.saveChanges()
        }
        let newStatus: CharacterManager.CharacterStatus = hasLiked ? .liked : .unliked
        CharacterManager.shared.updateCharacterStatus(characterid: Int32(userProfile.characterid), status: newStatus)
    }
}





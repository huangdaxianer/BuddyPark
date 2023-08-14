//
//  HomeViewModel.swift
//  BuddyPark
//
//  Created by 黄鹏昊 on 2023/8/14.
//

import Foundation
import SwiftUI
import CoreData

class HomeViewModel: ObservableObject {
    func onSwiped(userProfile: ProfileCardModel, hasLiked: Bool) {
        if hasLiked {
            let context = PersistenceController.shared.container.viewContext
            let buddyContact = BuddyContact(context: context)
            buddyContact.characterid = Int32(userProfile.characterId) ?? 0
            buddyContact.name = userProfile.name

            do {
                try context.save()
                printAllBuddyContacts()
                print("保存成功!")
            } catch {
                print("保存失败: \(error.localizedDescription)")
            }
        }
    }
    
    func printAllBuddyContacts() {
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest = NSFetchRequest<BuddyContact>(entityName: "BuddyContact")
        
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



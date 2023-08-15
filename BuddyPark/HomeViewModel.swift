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
    
    //滑动喜欢之后写入数据
    func onSwiped(userProfile: ProfileCardModel, hasLiked: Bool) {
        if hasLiked {
            let context = PersistenceController.shared.container.viewContext
            let contact = Contact(context: context)
            contact.characterid = Int32(userProfile.characterId)
            contact.name = userProfile.name
            contact.lastMessage = "你好啊"
            contact.updateTime = Date() // 写入现在的时间

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



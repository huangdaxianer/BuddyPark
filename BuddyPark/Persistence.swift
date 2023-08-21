//
//  Persistence.swift
//  BuddyPark
//
//  Created by 黄鹏昊 on 2023/8/11.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()
    
    static var preview: PersistenceController = {
           let result = PersistenceController(inMemory: true)
           let viewContext = result.container.viewContext
           
           // 创建一些 Character 对象
           let characterNames = ["Alice", "Bob", "Charlie", "David"]
           var characters: [Character] = []
           for name in characterNames {
               let character = Character(context: viewContext)
               character.name = name
               character.age = 30
               character.prompt = "How are you?"
               character.characterid = Int32(characters.count)
               characters.append(character)
           }
           
           // 创建一些 Contact 对象并与 Character 关联
           for character in characters {
               let contact = Contact(context: viewContext)
               contact.characterid = character.characterid
               contact.name = character.name
               contact.lastMessage = "Hello, \(character.name ?? "")!"
               contact.updateTime = Date()
               contact.character = character // 设置一对一双向匹配
           }
           
           // 创建一些 Message 对象并与 Contact 关联
        do {
            let fetchedContacts = try viewContext.fetch(Contact.fetchRequest()) as! [Contact]
            for contact in fetchedContacts {
                for i in 0..<5 {
                    let message = Message(context: viewContext)
                    message.id = UUID()
                    message.content = "Message \(i) to \(contact.name ?? "")"
                    message.timestamp = Date()
                    message.role = i % 2 == 0 ? "user" : "assistant"
                    message.characterid = contact.characterid
                    contact.addToMessages(message) // 设置一对多双向匹配
                }
            }
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }


           do {
               try viewContext.save()
           } catch {
               let nsError = error as NSError
               fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
           }
           return result
       }()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "BuddyPark")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}

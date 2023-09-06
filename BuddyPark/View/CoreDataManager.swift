import CoreData
import UIKit

class CoreDataManager {
    static let shared = CoreDataManager()
    
    var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "BuddyPark")  // 替换为你的 Core Data 模型文件的名称
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    
    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let error = error as NSError
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
    }
}

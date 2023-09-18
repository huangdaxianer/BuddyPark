import CoreData
import UIKit

final class CoreDataManager {
    static let shared = CoreDataManager(modelName: "BuddyPark")
    
    private let modelName: String
    
    init(modelName: String) {
        self.modelName = modelName
        setupNotificationHandling()
    }
    
    private(set) lazy var mainManagedObjectContext: NSManagedObjectContext = {
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = self.persistantStoreCoordinator
        context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        return context
    }()
    
    private lazy var managedObjectModel: NSManagedObjectModel = {
        guard let dataModelUrl = Bundle.main.url(forResource: self.modelName, withExtension: "momd") else { fatalError("Unable to find data model url") }
        guard let dataModel = NSManagedObjectModel(contentsOf: dataModelUrl) else { fatalError("Unable to find data model") }
        return dataModel
    }()
    
    private lazy var persistantStoreCoordinator: NSPersistentStoreCoordinator = {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let fileManager = FileManager.default
        let storeName = "\(self.modelName).sqlite"
        let directory = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.com.penghao.BuddyPark")!
        let storeUrl = directory.appendingPathComponent(storeName)
        
        let options = [
            NSMigratePersistentStoresAutomaticallyOption : true,
            NSInferMappingModelAutomaticallyOption : true,
        ]
        
        do {
            try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeUrl, options: options)
        } catch {
            fatalError("Unable to add store: \(error)")
        }
        
        return coordinator
    }()
    
    func saveChanges() {
        mainManagedObjectContext.perform {
            do {
                if self.mainManagedObjectContext.hasChanges {
                    try self.mainManagedObjectContext.save()
                }
            } catch {
                print("Saving error (child context): \(error.localizedDescription)")
            }

        }
    }


    
    @objc private func saveChanges(notification: Notification) {
        saveChanges()
    }
    
    private func setupNotificationHandling() {
        NotificationCenter.default.addObserver(self, selector: #selector(saveChanges(notification:)), name: UIApplication.willTerminateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(saveChanges(notification:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    func deleteAllData() {
        let entityNames = managedObjectModel.entities.compactMap { $0.name }
        mainManagedObjectContext.perform {
            for entityName in entityNames {
                let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: entityName)
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

                do {
                    try self.mainManagedObjectContext.execute(deleteRequest)
                } catch {
                    print("Error deleting entity data for \(entityName): \(error)")
                }
            }
        }
    }

}



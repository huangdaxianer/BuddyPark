import CoreData

final class CoreDataStack {
    
    //MARK: - Property
    
    private let moduleName: String
    
    //MARK: Persistant Container
    
    private(set) lazy var persistantContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: self.moduleName)
        let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.penghao.BuddyPark")!
        let storeName = "\(self.moduleName).sqlite"
        let storeUrl =  directory.appendingPathComponent(storeName)
        
        let description =  NSPersistentStoreDescription(url: storeUrl)
        container.persistentStoreDescriptions = [description]
        return container
    }()
    
    //MARK: - Managed Object Context
    
    //PARENT - .private
    private(set) lazy var context: NSManagedObjectContext = {
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.parent = mainContext
        return context
    }()
    
    //CHILD - .main
    private lazy var mainContext: NSManagedObjectContext = {
        return persistantContainer.viewContext
    }()
    
    //MARK: - Initializer
    
    init(moduleName: String) {
        self.moduleName = moduleName
        
        //MARK: Loading PersistantStore
        loadPersistantStore {
            //TODO:
        }
    }
    
    //MARK: - Load Persistant Store
    
    func loadPersistantStore(completionHandler: @escaping () -> Void) -> Void {
        persistantContainer.loadPersistentStores { (_, error) in
            if let _ = error {
                fatalError("Error in loading persistant store")
            } else {
                completionHandler()
            }
        }
    }
    
    //MARK: - Perform Operation Synchronously
    
    func performSyncOperation(block: () -> Void) -> Void {
        context.performAndWait {
            block()
        }
    }
    
    //MARK: - Perform Operation ASynchronously
    
    func performAsyncOperation(block: @escaping () -> Void) -> Void {
        context.perform {
            block()
        }
    }
    
    //MARK: - Save Operation
    
    func save() {
        context.performAndWait {
            if self.context.hasChanges {
                do {
                    try self.context.save()
                } catch {
                    print("saving error 1")
                }
                do {
                    try self.mainContext.save()
                } catch {
                    print("saving error 2")
                }
            }
        }
    }
}

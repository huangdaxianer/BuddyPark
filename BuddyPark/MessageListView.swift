import SwiftUI
import CoreData

struct MessageListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: BuddyContact.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \BuddyContact.name, ascending: true)]
    ) private var contacts: FetchedResults<BuddyContact> {
        didSet {
            print("Fetched \(contacts.count) contacts.") // 当contacts发生改变时打印信息
        }
    }
    
    var body: some View {
        NavigationView {
            List(contacts, id: \.self) { contact in
                NavigationLink(
                    destination: Text("Detail for \(contact.name ?? "")")
                ) {
                    Text(contact.name ?? "")
                }
                .onAppear {
                    print("NavigationLink for \(contact.name ?? "") appeared.") // 当单个联系人的NavigationLink出现时打印信息
                }
            }
            .navigationTitle("Messages")
            .onAppear {
                print("MessageListView appeared.") // 当MessageListView出现时打印信息
            }
        }
        .onAppear {
            print("NavigationView appeared with \(contacts.count) contacts.") // 当NavigationView出现时打印信息
        }
    }
}

struct MessageListView_Previews: PreviewProvider {
    static var previews: some View {
        MessageListView()
            .environment(\.managedObjectContext, preview.container.viewContext)
    }
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext

        // 随机填充一些名字
        let names = ["Alice", "Bob", "Charlie", "David", "Eva", "Frank", "Grace", "Helen"]
        for name in names {
            let buddyContact = BuddyContact(context: viewContext)
            buddyContact.name = name
            buddyContact.characterid = Int32.random(in: 1000...9999)
        }

        do {
            try viewContext.save()
        } catch {
            // 处理错误
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }

        return result
    }()
}




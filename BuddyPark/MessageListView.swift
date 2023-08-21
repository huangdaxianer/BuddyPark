import SwiftUI
import CoreData

struct MessageListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var sessionManager: SessionManager
    @Binding var selectedCharacterId: Int32?
    
    @FetchRequest(
        entity: Contact.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Contact.name, ascending: true)]
    ) private var contacts: FetchedResults<Contact>

    var body: some View {
        List(contacts, id: \.self) { contact in
            NavigationLink(
                destination: MessageView(characterid: contact.characterid,
                                         context: viewContext,
                                         messageManager: sessionManager.session(for: contact.characterid)),
                label: {
                    HStack {
                        Image(contact.name ?? "")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                        VStack(alignment: .leading) {
                            Text(contact.name ?? "")
                                .font(.headline)
                            Text(contact.lastMessage ?? "")
                                .font(.subheadline)
                        }
                        Spacer()
                        Text(contact.updateTime != nil ? DateFormatter.localizedString(from: contact.updateTime!, dateStyle: .short, timeStyle: .short) : "")
                            .font(.footnote)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 10)
                })
        }
        .navigationTitle("Messages")
        .navigationBarTitleDisplayMode(.inline)
    }
}




//struct MessageListView_Previews: PreviewProvider {
//    static var previews: some View {
//        MessageListView()
//            .environment(\.managedObjectContext, preview.container.viewContext)
//            .environmentObject(SessionManager(context: preview.container.viewContext)) // 添加 SessionManager 作为环境对象
//    }
//    
//    static var preview: PersistenceController = {
//        let result = PersistenceController(inMemory: true)
//        let viewContext = result.container.viewContext
//
//        // 随机填充一些名字
//        let names = ["junxi", "Bob", "Charlie", "David", "Eva", "Frank", "Grace", "Helen"]
//        for name in names {
//            let contact = Contact(context: viewContext)
//            contact.name = name
//            contact.characterid = Int32.random(in: 1000...9999)
//            contact.lastMessage = "最近怎么样？" // 填充最后一条消息
//            contact.updateTime = Date() // 填充当前时间
//        }
//
//        do {
//            try viewContext.save()
//        } catch {
//            // 处理错误
//            let nsError = error as NSError
//            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
//        }
//
//        return result
//    }()
//}
//





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
        ZStack {
            // 设置背景颜色
            Color.backgroundBlue.edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack {
                    ForEach(contacts, id: \.self) { contact in
                        MessageRowView(contact: contact,
                                       context: viewContext,
                                       messageManager: sessionManager.session(for: contact.characterid))
                    }
                }
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}


struct MessageRowView: View {
    let contact: Contact
    let context: NSManagedObjectContext
    let messageManager: MessageManager
    
    var body: some View {
        VStack {
            ZStack {
                // White rounded rectangle as the background
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .frame(height: 125)
                    .shadow(color: Color.black, radius: 0, x: 2, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.black, lineWidth: 2)
                    )
                
                HStack {
                    // Avatar
                    Image(contact.name ?? "")
                        .resizable()
                        .frame(width: 77, height: 77)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.black, lineWidth: 2))
                        .padding(.leading, 19)
                    
                    // Message and time area
                    VStack(alignment: .leading) {
                        HStack {
                            Text(contact.name ?? "")
                                .font(.system(size: 16))
                                .frame(alignment: .leading)
                            
                            Spacer()
                            
                            Text(contact.updateTime != nil ? DateFormatter.localizedString(from: contact.updateTime!, dateStyle: .none, timeStyle: .short) : "")
                                .font(.custom("SF Pro Rounded", size: 16))
                                .frame(alignment: .trailing)
                        }
                        
                        // Message bubble
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 45)
                                .fill(Color(red: 0, green: 102 / 255, blue: 255 / 255))
                                .frame(height: 44)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 45)
                                        .stroke(Color.black, lineWidth: 2)
                                )

                            Text(contact.lastMessage ?? "")
                                .font(.system(size: 14))
                                .foregroundColor(Color(white: 100))
                                .padding(.leading, 29) // 19 from the original padding + 10 for the extra space
                        }

                    }
                    .padding(.horizontal, 10)
                }
            }
            .frame(height: 125)
            .padding(.horizontal, 20)
        }
        .frame(height: 140)
        .background(NavigationLink("", destination: MessageView(characterid: contact.characterid, context: context, messageManager: messageManager)).opacity(0))
    }
}




struct MessageListView_Previews: PreviewProvider {
    @State static var selectedCharacterId: Int32? = nil
    
    static var previews: some View {
        MessageListView(selectedCharacterId: $selectedCharacterId)
            .environment(\.managedObjectContext, preview.container.viewContext)
            .environmentObject(SessionManager(context: preview.container.viewContext)) // 添加 SessionManager 作为环境对象
    }
    
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext

        // 随机填充一些名字
        let names = ["junxi", "Bob", "Charlie", "David", "Eva", "Frank", "Grace", "Helen"]
        for name in names {
            let contact = Contact(context: viewContext)
            contact.name = name
            contact.characterid = Int32.random(in: 1000...9999)
            contact.lastMessage = "最近怎么样？" // 填充最后一条消息
            contact.updateTime = Date() // 填充当前时间
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






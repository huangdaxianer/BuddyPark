import SwiftUI
import CoreData

struct MessageListView: View {
    let viewContext = CoreDataManager.shared.mainManagedObjectContext // 修改这一行
    @EnvironmentObject var sessionManager: SessionManager
    @Binding var selectedCharacterId: Int32?
    
    @FetchRequest(
        entity: Contact.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Contact.name, ascending: true)],
        predicate: NSPredicate(format: "isNew == %@", NSNumber(value: false)) //过滤到全新添加，没有消息的联系人
    ) private var contacts: FetchedResults<Contact>
    
    var body: some View {
        ZStack {
            Color.backgroundBlue.edgesIgnoringSafeArea(.all)
            VStack {
                Image("Messages")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120)
                Spacer() // 将下方内容推到底部
            }
            ScrollView {
                VStack {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 45)
                    ForEach(contacts.sorted(by: {
                        let timestamp1 = ($0.messages?.lastObject as? Message)?.timestamp
                        let timestamp2 = ($1.messages?.lastObject as? Message)?.timestamp
                        return timestamp1 ?? Date.distantPast > timestamp2 ?? Date.distantPast
                    }), id: \.self) { contact in
                        MessageRowView(contact: contact,
                                       context: viewContext, // 使用统一的 viewContext
                                       messageManager: sessionManager.session(for: contact.characterid))
                    }
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 120)
                }
            }
        }
        .navigationTitle("消息")
        .navigationBarHidden(true)  // 隐藏 Navigation Bar
    }
}

struct MessageRowView: View {
    let contact: Contact
    let context: NSManagedObjectContext
    let messageManager: MessageManager
    @State private var avatarImage: UIImage? = nil
    @State private var isSelected: Bool = false // 添加这个状态来控制导航

    var lastMessage: Message? {
        let lastMsg = (contact.messages?.array as? [Message])?.last
        print("Last message fetched: \(String(describing: lastMsg))")
        return lastMsg
    }

    var lastMessageTimestamp: Date? {
        let timestamp = (contact.messages?.lastObject as? Message)?.timestamp
        print("Timestamp of last message: \(String(describing: timestamp))") // Print the timestamp of the last message
        return timestamp
    }   

    var processedLastMessage: String {
        guard let content = lastMessage?.content else { return "" }
        let mainContentComponents = content.split(separator: "@", maxSplits: 1).map(String.init)
        let mainContent = mainContentComponents.count > 1 ? mainContentComponents[1] : content
        let lastSubContent = mainContent.split(separator: "#").last ?? ""
        let finalContent = lastSubContent.split(separator: "$", maxSplits: 1).first ?? ""
        return String(finalContent)
    }


    
    var body: some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .frame(height: 125)
                    .shadow(color: Color.black, radius: 0, x: 2, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.black, lineWidth: 2)
                    )
                HStack {
                    
                    ZStack {
                        // Avatar
                        if let avatar = avatarImage {
                            Image(uiImage: avatar)
                                .resizable()
                                .frame(width: 77, height: 77)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.black, lineWidth: 2))
                        } else {
                            Image("default_avatar")  // 默认头像
                                .resizable()
                                .frame(width: 77, height: 77)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.black, lineWidth: 2))
                        }

                        // New message badge
                        if contact.newMessageNum > 0 {
                            ZStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 31, height: 31)
                                    .overlay(Circle().stroke(Color.black, lineWidth: 2))

                                Text("\(contact.newMessageNum)")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            .offset(x: 25, y: -25)  // 根据需要调整位置
                        }
                    }
                    .padding(.leading, 19)



                    // Message and time area
                    VStack(alignment: .leading) {
                        HStack {
                            Text(contact.name ?? "")
                                .font(.system(size: 16))
                                .fontWeight(.bold)
                                .frame(alignment: .leading)
                                .padding(.leading, 5)
                            Spacer()
                            Text(lastMessage?.timestamp != nil ? DateFormatter.localizedString(from: lastMessage!.timestamp!, dateStyle: .none, timeStyle: .short) : "")
                                .font(.system(size: 16, weight: .regular, design: .rounded))
                                              .fontWeight(.black)
                                              .frame(alignment: .trailing)
                                              .padding(.trailing, 10)

                        }

                        ZStack(alignment: .leading) {
                            if lastMessage?.role == "user" {
                                RoundedRectangle(cornerRadius: 45)
                                    .fill(Color(white: 100))
                                    .frame(height: 44)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 45)
                                            .stroke(Color.black, lineWidth: 2)
                                    )
                                Text(processedLastMessage)
                                    .font(.system(size: 16))
                                    .fontWeight(.bold)
                                    .foregroundColor(Color.black)
                                    .padding(.leading, 19)
                                    .padding(.trailing, 5)
                                    .truncationMode(.tail)
                                    .lineLimit(1)
                            } else {
                                RoundedRectangle(cornerRadius: 45)
                                    .fill(Color(red: 0, green: 102 / 255, blue: 255 / 255))
                                    .frame(height: 44)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 45)
                                            .stroke(Color.black, lineWidth: 2)
                                    )
                                Text(processedLastMessage)
                                    .font(.system(size: 16))
                                    .fontWeight(.bold)
                                    .foregroundColor(Color.white)
                                    .padding(.leading, 19)
                                    .padding(.trailing, 5)
                                    .truncationMode(.tail)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.leading, 5)
                    .padding(.trailing, 10)
                }
                NavigationLink(
                    destination: MessageView(characterid: contact.characterid, messageManager: messageManager),
                    isActive: $isSelected,
                    label: { EmptyView() }
                )
                .opacity(0) // 或者使用 .hidden()
            }
            .frame(height: 125)
            .padding(.leading, 18)
            .padding(.trailing, 20)

        }
        .frame(height: 135)
        .onAppear {
            avatarImage = CharacterManager.shared.loadImage(characterid: contact.characterid, type: .avatar)
        }

        .onTapGesture {
            CharacterManager.shared.resetNewMessageNumForContact(characterid: contact.characterid)
            isSelected.toggle() // 当点击时，修改 isSelected 的值来触发导航
        }
    }
}


//
//struct MessageListView_Previews: PreviewProvider {
//    @State static var selectedCharacterId: Int32? = nil
//    
//    static var previews: some View {
//        MessageListView(selectedCharacterId: $selectedCharacterId)
//            .environment(\.managedObjectContext, preview.container.viewContext)
//            .environmentObject(SessionManager(context: preview.container.viewContext)) // 添加 SessionManager 作为环境对象
//    }
//    
//    static var preview: PersistenceController = {
//        let result = PersistenceController(inMemory: true)
//        let viewContext = result.container.viewContext
//
//        // 随机填充一些名字
//        let names = ["junxi", "Bob", "Charlie", "David", "Eva", "Frank", "Grace", "elon_musk"]
//        for name in names {
//            let contact = Contact(context: viewContext)
//            contact.name = name
//            contact.characterid = Int32.random(in: 1000...9999)
//            contact.lastMessage = "最近怎么样？我想知道你最近的消息到底怎么回事" // 填充最后一条消息
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






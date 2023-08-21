import SwiftUI
import CoreData

class UserInput: ObservableObject {
    @Published var text: String = ""
    @Published var textWithTime: String = ""
}

class KeyboardManager: ObservableObject {
    @Published var isFirstResponder = true
}

struct ResignKeyboardAndLoseFocusGesture: ViewModifier {
    @Binding var isFirstResponder: Bool

    var gesture: some Gesture {
        DragGesture().onChanged { _ in
            UIApplication.shared.endEditing()
            isFirstResponder = false
        }
    }

    func body(content: Content) -> some View {
        content.gesture(gesture)
    }
}

struct CustomTextFieldView: View {
    @ObservedObject var userInput: UserInput
    @Binding var isFirstResponder: Bool
    var onCommit: () -> Void

    var body: some View {
        UIKitTextFieldRepresentable(text: $userInput.text, isFirstResponder: $isFirstResponder, onCommit: onCommit)
            .padding()
            .frame(maxWidth: UIScreen.main.bounds.width - 30, maxHeight: 40)
            .clipped()  // 添加这行代码来截取超出的部分
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color.gray.opacity(0.15))
            )
            .offset(y: -10) // 添加这行代码使文本输入框向上移动
            .onTapGesture {
                isFirstResponder = true
            }
    }
}

struct MessageView: View {
    
    @Environment(\.managedObjectContext) var context
     @ObservedObject var messageManager: MessageManager
    @State var isFirstResponder: Bool = true
    @StateObject var userInput = UserInput()
    
    // 接受 characterid 和 context 作为参数
    init(characterid: Int32, context: NSManagedObjectContext, messageManager: MessageManager) {
        self.messageManager = messageManager
    }
    
    var body: some View {
        NavigationView {
            VStack {
                ScrollViewReader { scrollViewProxy in
                    ScrollView {
                        LazyVStack {
                            ForEach(Array(messageManager.messages.enumerated()), id: \.element.id) { index, message in
                                let previousMessageTimestamp: Date = index > 0 ? messageManager.messages[index - 1].timestamp : Date.distantPast
                                MessageRow(message: message, previousMessageTimestamp: previousMessageTimestamp)
                            }
                            // 当消息更新的时候自动滚动
                            .onChange(of: messageManager.lastUpdated) { _ in
                                withAnimation {
                                    scrollViewProxy.scrollTo(messageManager.messages.last?.id, anchor: .bottom)
                                }
                            }
                        }
                        .modifier(ResignKeyboardAndLoseFocusGesture(isFirstResponder: $isFirstResponder))
                    }
                    .padding(.top, 0)
                    .padding(.bottom, 10)
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                        //                    messageManager.reloadMessages() //当应用返回前台的时候重新加载信息
                    }
                    .gesture(DragGesture().onChanged { _ in
                        UIApplication.shared.endEditing()
                    })
                    .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                        print("Keyboard will show")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                scrollViewProxy.scrollTo(messageManager.messages.last?.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                CustomTextFieldView(userInput: userInput, isFirstResponder: $isFirstResponder, onCommit: {
                    DispatchQueue.main.async {
                        // 这里会把最新一条消息加上发送时间
                        let date = Date()
                        let formatter = DateFormatter()
                        formatter.dateFormat = "MM月dd日ahh:mm"
                        formatter.locale = Locale(identifier: "zh_CN")
                        let timeString = formatter.string(from: date)
                        userInput.textWithTime = "\(userInput.text)$\(timeString)"
                    //    let userMessage = LocalMessage(id: UUID(), role: .user, content: userInput.textWithTime, timestamp: Date())
                        //                    messageManager.appendFullMessage(userMessage, lastUserReplyFromServer: nil) {
                        // 这个闭包将在 'appendFullMessage' 执行完毕后执行
                        //                         messageManager.sendRequest(type: .newMessage)
                        //                    }
                        //                     messageManager.testNetwork()
                        userInput.text = ""
                    }
                })
                
            }
            .navigationBarTitle(Text(messageManager.isTyping ? "对方正在输入..." : messageManager.contactName), displayMode: .inline)
            //.navigationViewStyle(.stack)
            //              .environmentObject(avatarUpdater)
        }
    }
}
    
    
    
    
////    @ObservedObject var messageManager = MessageManager.shared
//    @StateObject var userInput = UserInput()
//    @State var isFirstResponder: Bool = true
//    @StateObject var avatarUpdater = AvatarUpdater()
//    @State private var currentUser: User? = nil
//
//    var body: some View {
//        NavigationView {
//            VStack {
//                ScrollViewReader { scrollViewProxy in
//                    ScrollView {
//                        LazyVStack {
//                            ForEach(Array(messageManager.messages.enumerated()), id: \.element.id) { index, message in
//                                let previousMessageTimestamp: Date = index > 0 ? messageManager.messages[index - 1].timestamp : Date.distantPast
//                                MessageRow(message: message, previousMessageTimestamp: previousMessageTimestamp)
//                            }
//                            // 当消息更新的时候自动滚动
//                            .onChange(of: messageManager.lastUpdated) { _ in
//                                withAnimation {
//                                    scrollViewProxy.scrollTo(messageManager.messages.last?.id, anchor: .bottom)
//                                }
//                            }
//                        }
//                        .modifier(ResignKeyboardAndLoseFocusGesture(isFirstResponder: $isFirstResponder))
//                    }
//                    .padding(.top, 0)
//                    .padding(.bottom, 10)
//                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
//                        messageManager.reloadMessages() //当应用返回前台的时候重新加载信息
//                    }
//                    .gesture(DragGesture().onChanged { _ in
//                        UIApplication.shared.endEditing()
//                    })
//                    .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
//                        print("Keyboard will show")
//                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                            withAnimation {
//                                scrollViewProxy.scrollTo(messageManager.messages.last?.id, anchor: .bottom)
//                            }
//                        }
//                    }
//                }
//                .onAppear {
//                    if currentCharacter.isEmpty {
//                        showingModal = true
//                    }
//                }
//                CustomTextFieldView(userInput: userInput, isFirstResponder: $isFirstResponder, onCommit: {
//                    DispatchQueue.main.async {
//
//                        // 这里会把最新一条消息加上发送时间
//                        let date = Date()
//                        let formatter = DateFormatter()
//                        formatter.dateFormat = "MM月dd日ahh:mm"
//                        formatter.locale = Locale(identifier: "zh_CN")
//                        let timeString = formatter.string(from: date)
//                        userInput.textWithTime = "\(userInput.text)$\(timeString)"
//                        let userMessage = LocalMessage(id: UUID(), role: .user, content: userInput.textWithTime, timestamp: Date())
//                        messageManager.appendFullMessage(userMessage, lastUserReplyFromServer: nil) {
//                            // 这个闭包将在 'appendFullMessage' 执行完毕后执行
//                            messageManager.sendRequest(type: .newMessage)
//                        }
//                        messageManager.testNetwork()
//                        userInput.text = ""
//                    }
//                })
//
//            }
//            .navigationBarTitle(Text(messageManager.isTyping ? "对方正在输入..." : currentCharacter), displayMode: .inline)
//            .navigationViewStyle(.stack)
//            .environmentObject(avatarUpdater)
//        }
//    }


struct MessageRow: View {
    @Environment(\.colorScheme) var colorScheme // 添加这行代码获取当前系统模式
    @AppStorage("Character") var storedUserInput: String = ""
    @State private var selectedUserAvatar: UIImage?
    @State private var selectedCharacterAvatar: UIImage?
    @State private var showingAlert = false
    @EnvironmentObject var avatarUpdater: AvatarUpdater
    @State private var showingSubscriptionView = false
    let appGroupName = "group.com.penghao.monkey"
    var message: LocalMessage
    var previousMessageTimestamp: Date?  // 新添加的属性

    var body: some View {
        VStack(alignment: .center, spacing: 10) {  // 添加 VStack 包裹所有的内容，并在每个元素之间添加 10 点的间隔
            // 如果上一条消息的发送时间和当前消息的发送时间之间的间隔大于两分钟，那么显示时间提示
            if shouldShowTime() {
                HStack {
                    Spacer() // 添加此行将使时间标签居中
                    Text(message.timestamp.formatTimestamp())
                        .font(.system(size: 13))
                        .padding([.horizontal, .top])
                        .foregroundColor(.gray)
                    Spacer() // 添加此行将使时间标签居中
                }
            }

            // 分割 message.content 到 emotion 和 content
            let contentComponents = message.content.split(separator: "@", maxSplits: 1).map { String($0) }
          //  let emotion = contentComponents.count > 1 ? contentComponents[0] : ""
            let content = contentComponents.count > 1 ? contentComponents[1] : message.content
            let contents = content.split(separator: "#") // 使用换行符分割消息内容

            // If message.role is user, remove the timestamp after $
            let userMessage = content.split(separator: "$", maxSplits: 1).map { String($0) }
            let displayedContent = userMessage.count > 1 ? userMessage[0] : String(content)

            // Check if displayedContent starts with $
            if !displayedContent.hasPrefix("$") {
                HStack {
                    if message.role == .assistant {
                        ZStack(alignment: Alignment(horizontal: .leading, vertical: .top)) {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(contents, id: \.self) { content in
                                    let assistantMessage = content.split(separator: "$", maxSplits: 1).map { String($0) }
                                          let displayedContent = assistantMessage.count > 1 ? assistantMessage[0] : String(content)
                                    Text(displayedContent)
                                        .foregroundColor(colorScheme == .dark ? .white : .black)
                                        .padding()
                                        .background(Color.secondary.opacity(0.2))
                                        .cornerRadius(10)
                                }
                            }
                            .padding(.leading, 15)
                            .padding(.top, 15)
                            Button(action: {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                            }) {
                                Image(uiImage: loadImageFromSharedContainer(named: "avatar.jpeg") ?? UIImage(named: "ProfileDefault") ?? UIImage())
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 30, height: 30)
                                    .clipShape(Circle())
                                    .offset(x: 0, y: 0)
                                    .id(avatarUpdater.lastUpdate)
                            }


                        }
                        Spacer()
                    } else {
                        Spacer()
                        ZStack(alignment: Alignment(horizontal: .trailing, vertical: .top)) {
                            VStack(alignment: .trailing, spacing: 8) { // 修改alignment为.trailing
                                ForEach(contents, id: \.self) { content in
                                    // If message.role is user, remove the timestamp after $
                                    let userMessage = content.split(separator: "$", maxSplits: 1).map { String($0) }
                                    let displayedContent = userMessage.count > 1 ? userMessage[0] : String(content)

                                    Text(displayedContent)
                                        .foregroundColor(Color.white)
                                        .padding()
                                        .background(Color.blue)
                                        .cornerRadius(10)

                                }
                            }
                            .padding(.trailing, 15) // Add trailing padding
                            .padding(.top, 15)  // Add top padding
                            Button(action: {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                            }) {
                                Image(uiImage: loadImageFromSharedContainer(named: "profile.jpeg") ?? UIImage(named: "ProfileDefault") ?? UIImage())
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 30, height: 30)
                                    .clipShape(Circle())
                                    .offset(x: 0, y: 0)
                                    .id(avatarUpdater.lastUpdate)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .id(message.id) // 给 MessageRow 添加 id 以便 ScrollViewReader 使用
            }

        }
    }

    func loadImageFromSharedContainer(named filename: String) -> UIImage? {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.penghao.monkey") {
            let fileURL = url.appendingPathComponent(filename)
            do {
                let imageData = try Data(contentsOf: fileURL)
                return UIImage(data: imageData)
            } catch {
                print("Unable to load image: \(error)")
            }
        }
        return nil
    }

    func getFormattedTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    func shouldShowTime() -> Bool {
        let interval = message.timestamp.timeIntervalSince(previousMessageTimestamp ?? Date.distantPast)
        return interval > 60 * 3 //三分钟
    }

}

extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

class AvatarUpdater: ObservableObject {
    @Published var lastUpdate = Date()

    func imageUpdated() {
        lastUpdate = Date()
    }
}

class PreviewMessageManager: MessageManager {
    override init(characterid: Int32, context: NSManagedObjectContext) {
        super.init(characterid: characterid, context: context)
        // 添加预览消息
        messages = [
            LocalMessage(id: UUID(), role: .user, content: "你好！", timestamp: Date()),
            LocalMessage(id: UUID(), role: .assistant, content: "你好，有什么可以帮助你的吗？", timestamp: Date())
        ]
    }
}

struct MessageView_Previews: PreviewProvider {
    static var previews: some View {
        // 创建一个模拟的 NSManagedObjectContext
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)

        // 创建一个模拟的 Contact 实体
        let contact = Contact(context: context)
        contact.name = "测试联系人"
        contact.characterid = 1234
        
        // 使用预览专用的 MessageManager
        let previewMessageManager = PreviewMessageManager(characterid: contact.characterid, context: context)
        
        return MessageView(characterid: contact.characterid, context: context, messageManager: previewMessageManager)
            .environment(\.managedObjectContext, context) // 设置预览的上下文
    }
}


struct User {
    let uuid: String
    let isNewUser: Bool
}

import SwiftUI
import CoreData
import AudioToolbox

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
            .padding(.horizontal) // 为文本输入框提供水平的内边距
            .frame(maxWidth: UIScreen.main.bounds.width - 30, maxHeight: 56)
            .clipped()  // 该行代码用于裁剪超出部分
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color.white)  // 纯白色背景
                    .shadow(color: Color.black, radius: 0, x: 2, y: 2)  // 黑色阴影，向右下角偏移
                    .overlay(
                        RoundedRectangle(cornerRadius: 40)
                            .stroke(Color.black, lineWidth: 2)  // 黑色宽度为2的实线边框
                    )
            )
            .onTapGesture {
                isFirstResponder = true
            }
    }
}

struct MessageView: View {
    
    let context = CoreDataManager.shared.mainManagedObjectContext // 使用 mainManagedObjectContext 替代原来的 viewContext
    let characterid: Int32
    @Environment(\.presentationMode) var presentationMode // 用于回到上一个页面
    @ObservedObject var messageManager: MessageManager
    @State var isFirstResponder: Bool = false
    @StateObject var userInput = UserInput()
    @State private var keyboardDynamicPadding: CGFloat = 0
    @State private var keyboardHeight: CGFloat = 0
    @State private var ifShowIndicator: Bool = true
    @State private var paddingHeight: CGFloat = 95

    
    init(characterid: Int32, messageManager: MessageManager) {
        self.characterid = characterid  // 设置 characterid
        self.messageManager = messageManager
    }
    
    var body: some View {
        ZStack {
            Color("chat_bg_color")
                .edgesIgnoringSafeArea(.all)
            
            ScrollViewReader { scrollViewProxy in
                ScrollView(showsIndicators: ifShowIndicator)  {
                    LazyVStack {
                        ForEach(Array(messageManager.messages.enumerated()), id: \.element.id) { index, message in
                            let previousMessageTimestamp: Date = index > 0 ? messageManager.messages[index - 1].timestamp : Date.distantPast
                            MessageRow(message: message, previousMessageTimestamp: previousMessageTimestamp)
                        }
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 0.1)  // 新添加的10点高的Rectangle
                            .id("additionalOffset")
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: paddingHeight)
                            .id("bottomRectangle")
                            .onChange(of: messageManager.lastUpdated) { _ in
                                withAnimation {
                                    scrollViewProxy.scrollTo("bottomRectangle", anchor: .bottom)
                                }
                            }
                    }
                    .modifier(ResignKeyboardAndLoseFocusGesture(isFirstResponder: $isFirstResponder))
                }
                .padding(.top, 50)
                .padding(.bottom, 10)
                .onAppear {
                    scrollToBottom(with: scrollViewProxy)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    scrollToBottom(with: scrollViewProxy)
                }
                .gesture(DragGesture().onChanged { _ in
                    UIApplication.shared.endEditing()
                })
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now()) {
                        withAnimation {
                            scrollViewProxy.scrollTo("additionalOffset", anchor: .bottom)
                        }
                    }
                }
                .edgesIgnoringSafeArea(.bottom)  // 忽略底部的安全区
            }
            .onAppear {
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { (noti) in
                    ifShowIndicator=false
                    keyboardHeight = 70
                    paddingHeight = 0.1
                }
                
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { (noti) in
                    ifShowIndicator=true
                    keyboardHeight = 0
                    paddingHeight = 95
                }
            }.padding(.bottom, keyboardHeight)
            
            
            VStack() {
                ZStack {
                    Color("naviBlue")
                        .frame(height: 110)
                        .overlay(
                            Rectangle()
                                .stroke(Color.black, lineWidth: 2)
                        )
                    
                    VStack {
                        Rectangle()
                            .fill(Color.clear)  // 设置填充色为透明
                            .frame(height: 44)
                        
                        HStack {
                            Button(action: {
                                presentationMode.wrappedValue.dismiss()
                                CharacterManager.shared.resetNewMessageNumForContact(characterid: characterid) // 使用 characterid 属性
                            }) {
                                Image(systemName: "arrow.left")
                                    .font(.system(size: 20))
                                    .foregroundColor(.black)
                                    .fontWeight(.bold)
                                    .padding(.horizontal)
                            }
                            
                            Spacer()  // 这个 Spacer 将会把 Button 推到左边
                            
                            Text(messageManager.contactName)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                            
                            Spacer()  // 这个 Spacer
                            Button(action: {
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                Image(systemName: "arrow.left")
                                    .font(.system(size: 20))
                                    .foregroundColor(.clear)
                                    .padding(.horizontal)
                            }
                        }
                        
                    }
                }
                .edgesIgnoringSafeArea(.top)
                Spacer()
            }
            
            
            VStack {
                Spacer()  // 推动下面的视图到底部
                CustomTextFieldView(userInput: userInput, isFirstResponder: $isFirstResponder, onCommit: {
                    DispatchQueue.main.async {
                        let date = Date()
                        let formatter = DateFormatter()
                        formatter.dateFormat = "MM月dd日ahh:mm"
                        formatter.locale = Locale(identifier: "zh_CN")
                        let timeString = formatter.string(from: date)
                        userInput.textWithTime = "\(userInput.text)$\(timeString)"
                        
                        let userMessage = LocalMessage(id: UUID(), role: "user", content: userInput.textWithTime, timestamp: Date())
                        messageManager.appendFullMessage(userMessage, lastUserReplyFromServer: nil) {
                            messageManager.sendRequest(type: .newMessage)
                        }
                        //messageManager.testNetwork()
                        
                        userInput.text = ""
                    }
                })
            }
            .onAppear {
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { (noti) in
                    keyboardDynamicPadding = 10
                }

                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { (noti) in
                    keyboardDynamicPadding = 0
                }
            }
            .padding(.bottom, keyboardDynamicPadding) // 添加这一行
            
            
        }
        .navigationBarHidden(true)  // 隐藏 Navigation Bar
    }
    
    private func scrollToBottom(with scrollViewProxy: ScrollViewProxy, delay: Double = 0.1) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            scrollViewProxy.scrollTo("bottomRectangle", anchor: .bottom)
        }
    }
}

struct MessageRow: View {
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("Character") var storedUserInput: String = ""
    @State private var selectedUserAvatar: UIImage?
    @State private var selectedCharacterAvatar: UIImage?
    @State private var showingAlert = false
    @EnvironmentObject var avatarUpdater: AvatarUpdater
    @State private var showingSubscriptionView = false
    var message: LocalMessage
    var previousMessageTimestamp: Date?
    
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
            let content = contentComponents.count > 1 ? contentComponents[1] : message.content
            let contents = content.split(separator: "#")
            
            // If message.role is user, remove the timestamp after $
            let userMessage = content.split(separator: "$", maxSplits: 1).map { String($0) }
            let displayedContent = userMessage.count > 1 ? userMessage[0] : String(content)
            
            // Check if displayedContent starts with $
            if !displayedContent.hasPrefix("$") {
                HStack {
                    if message.role == "assistant" {
                        ZStack(alignment: Alignment(horizontal: .leading, vertical: .top)) {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(contents, id: \.self) { content in
                                    let assistantMessage = content.split(separator: "$", maxSplits: 1).map { String($0) }
                                    let displayedContent = assistantMessage.count > 1 ? assistantMessage[0] : String(content)
                                    Text(displayedContent)
                                        .fontWeight(.bold)
                                        .foregroundColor(Color.white)
                                        .padding()
                                        .background(Color.blue)
                                        .cornerRadius(29)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 29)
                                                .stroke(Color.black, lineWidth: 2)
                                        )
                                }
                            }
                            .padding(.leading, 10)
                            .padding(.top, 15)
                        }
                        Spacer()
                    } else {
                        Spacer()
                        ZStack(alignment: Alignment(horizontal: .trailing, vertical: .top)) {
                            VStack(alignment: .trailing, spacing: 8) {
                                ForEach(contents, id: \.self) { content in
                                    let userMessage = content.split(separator: "$", maxSplits: 1).map { String($0) }
                                    let displayedContent = userMessage.count > 1 ? userMessage[0] : String(content)
                                    
                                    Text(displayedContent)
                                        .fontWeight(.bold)
                                        .foregroundColor(Color.black)
                                        .padding()
                                        .background(Color.white)
                                        .cornerRadius(29)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 29)
                                                .stroke(Color.black, lineWidth: 2)
                                        )
                                }
                            }
                            .padding(.trailing, 10)
                            .padding(.top, 15)
                        }
                    }
                }
                .padding(.horizontal)
                .id(message.id) // 给 MessageRow 添加 id 以便 ScrollViewReader 使用
            }
            
        }
    }
    
    func loadImageFromSharedContainer(named filename: String) -> UIImage? {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName) {
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


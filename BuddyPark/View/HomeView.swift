import SwiftUI

struct HomeView: View {
    let viewContext = CoreDataManager.shared.persistentContainer.viewContext // 从CoreDataManager中获取viewContext
    @StateObject private var characterData = CharacterData()
    @StateObject private var viewModel = HomeViewModel()
    @ObservedObject var sessionManager: SessionManager
    @State private var selectedTab: Int = 0
    @State private var selectedCharacterId: Int32? //用于跟踪所选的角色ID
    @State private var isNavigatingToMessageView: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.backgroundBlue.edgesIgnoringSafeArea(.all)
                ZStack {
                    switch selectedTab {
                    case 0:
                        SwipeView(profiles: $characterData.characters, onSwiped: viewModel.onSwiped)
                            .environmentObject(characterData)
                    case 1:
                        MessageListView(selectedCharacterId: $selectedCharacterId)
                            .environmentObject(sessionManager)
                            .edgesIgnoringSafeArea(.bottom)

                    case 2:
                        ProfileView()
                    default:
                        EmptyView()
                    }
                    VStack {
                        Spacer() // 用于推动 CustomTabBar 到底部
                        CustomTabBar(selectedTab: $selectedTab)
                    }
                }
                .navigationBarTitleDisplayMode(.inline) // 禁用大标题样式
                .edgesIgnoringSafeArea(.bottom)

                NavigationLink(
                    "",
                    destination: selectedCharacterId.map { characterId in
                        MessageView(characterid: characterId,
                                    messageManager: sessionManager.session(for: characterId))
                    },
                    isActive: $isNavigatingToMessageView
                )
                .hidden()
            }
        }
    }
}


struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @FetchRequest(
        entity: Contact.entity(),
        sortDescriptors: []
    ) var contacts: FetchedResults<Contact>
    
    var totalNewMessages: Int {
        return contacts.map { Int($0.newMessageNum) }.reduce(0, +)
    }

    var body: some View {
        ZStack {
            // 背景
            RoundedRectangle(cornerRadius: 129)
                .fill(Color(hex: "FFB800"))
                .frame(width: 293, height: 75)
                .shadow(color: Color.black, radius: 0, x: 2, y: 2) // 阴影
                .overlay(
                    RoundedRectangle(cornerRadius: 129)
                        .stroke(Color.black, lineWidth: 2) // 边框
                )
            
            // 按钮组
            HStack(spacing: 20) {
                TabBarButton(imageName: "SwipeView", selectedTab: $selectedTab, index: 0)
                TabBarButton(imageName: "MessageListView", selectedTab: $selectedTab, index: 1, badgeCount: totalNewMessages)
                TabBarButton(imageName: "ProfileView", selectedTab: $selectedTab, index: 2)
            }
        }
        .padding()
        .background(Color.clear)  // 确保ZStack背景是透明的
        .offset(y: -10)  // 向上偏移10个单位，可以根据你的需要调整
    }
}


struct TabBarButton: View {
    let imageName: String
    @Binding var selectedTab: Int
    let index: Int
    var badgeCount: Int? = nil  // 添加可选的 Badge 计数
    
    var badgeBackgroundColor: Color {
        if index == 1 && selectedTab == 1 {
            return Color.red
        } else {
            return Color.white
        }
    }
    
    var badgeTextColor: Color {
        if index == 1 && selectedTab == 1 {
            return Color.white
        } else {
            return Color.black
        }
    }

    var body: some View {
        ZStack {
            Button(action: { selectedTab = index }) {
                Image(selectedTab == index ? imageName : "\(imageName)_empty")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 45, height: 45)
            }
            .padding()
            .cornerRadius(10)
            
            // 如果 badgeCount 不为 nil 并且大于 0，就显示它
            if let count = badgeCount, count > 0 {
                ZStack {
                    Circle()
                        .fill(badgeBackgroundColor)
                        .frame(width: 25, height: 25)
                        .overlay(Circle().stroke(Color.black, lineWidth: 2))  // 黑色边框
                    
                    Text("\(count)")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(badgeTextColor)
                }
                .offset(x: 15, y: -15)  // 根据需要调整位置
            }
        }
    }
}







//struct HomeView_Previews: PreviewProvider {
//    static var previews: some View {
//        let context = PersistenceController.preview.container.viewContext
//        let sessionManager = SessionManager(context: context)
//        
//        return HomeView(sessionManager: sessionManager)
//            .environment(\.managedObjectContext, context)
//    }
//}


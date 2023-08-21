import SwiftUI

struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var profileData = ProfileData()
    @StateObject private var viewModel = HomeViewModel()
    @ObservedObject var sessionManager: SessionManager
    @State private var selectedTab: Int = 0
    @State private var selectedCharacterId: Int32? //用于跟踪所选的角色ID
    @State private var isNavigatingToMessageView: Bool = false

    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                switch selectedTab {
                case 0:
                    SwipeView(profiles: $profileData.profiles, onSwiped: viewModel.onSwiped)
                        .environmentObject(profileData)
                case 1:
                    MessageListView(selectedCharacterId: $selectedCharacterId)
                        .environment(\.managedObjectContext, viewContext)
                        .environmentObject(sessionManager)

                default:
                    EmptyView()
                }
                // 自定义的底部按钮栏
                HStack(spacing: 20) { // 增加按钮之间的间距
                    Button(action: { selectedTab = 0 }) {
                        Label("Swipe", systemImage: "rectangle.stack")
                    }
                    .padding()
                    .background(selectedTab == 0 ? Color.blue.opacity(0.1) : Color.clear)
                    .cornerRadius(10)
                    
                    Button(action: { selectedTab = 1 }) {
                        Label("Tab 2", systemImage: "square.and.pencil")
                    }
                    .padding()
                    .background(selectedTab == 1 ? Color.blue.opacity(0.1) : Color.clear)
                    .cornerRadius(10)
                }
                .padding()
                .background(Color(.systemGray6)) // 为底部栏增加背景颜色
            }
            .navigationTitle(selectedTab == 1 ? "Messages" : "")
            .navigationBarTitleDisplayMode(.inline) // 禁用大标题样式
            .edgesIgnoringSafeArea(.bottom)

            NavigationLink(
                "",
                destination: selectedCharacterId.map { characterId in
                    MessageView(characterid: characterId,
                                context: viewContext,
                                messageManager: sessionManager.session(for: characterId))
                },
                isActive: $isNavigatingToMessageView
            )
            .hidden()
        }
    }
}




struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let sessionManager = SessionManager(context: context)
        
        return HomeView(sessionManager: sessionManager)
            .environment(\.managedObjectContext, context)
    }
}


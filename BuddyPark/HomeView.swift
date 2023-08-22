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
            ZStack {
                Color.backgroundBlue.edgesIgnoringSafeArea(.all)
                VStack(spacing: 0) {
                    switch selectedTab {
                    case 0:
                        SwipeView(profiles: $profileData.profiles, onSwiped: viewModel.onSwiped)
                            .environmentObject(profileData)
                    case 1:
                        MessageListView(selectedCharacterId: $selectedCharacterId)
                            .environment(\.managedObjectContext, viewContext)
                            .environmentObject(sessionManager)
                    case 2:
                        ProfileView()
                    default:
                        EmptyView()
                    }
                    // 自定义的底部按钮栏
                    HStack(spacing: 20) { // 增加按钮之间的间距
                        Button(action: { selectedTab = 0 }) {
                            Image(selectedTab == 0 ? "SwipeView" : "SwipeView_empty")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 45, height: 45)
                        }
                        .padding()
                        .cornerRadius(10)
                        
                        Button(action: { selectedTab = 1 }) {
                            Image(selectedTab == 1 ? "MessageListView" : "MessageListView_empty")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 45, height: 45)
                        }
                        .padding()
                        .cornerRadius(10)
                        
                        Button(action: { selectedTab = 2 }) {
                            Image(selectedTab == 2 ? "ProfileView" : "ProfileView_empty")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 45, height: 45)
                        }
                        .padding()
                        .cornerRadius(10)
                        
                    }
                    .padding()
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


}





struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let sessionManager = SessionManager(context: context)
        
        return HomeView(sessionManager: sessionManager)
            .environment(\.managedObjectContext, context)
    }
}


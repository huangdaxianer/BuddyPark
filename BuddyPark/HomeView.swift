import SwiftUI

struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var profileData = ProfileData()
    @StateObject private var viewModel = HomeViewModel()
    @ObservedObject var sessionManager: SessionManager

    var body: some View {
        TabView {
            // 第一个 Tab，展示 SwipeView
            SwipeView(profiles: $profileData.profiles, onSwiped: viewModel.onSwiped)
            .tabItem {
                Label("Swipe", systemImage: "rectangle.stack")
            }
            .environmentObject(profileData) // 将 profileData 作为环境对象传递
            
            // 第二个 Tab，进入已经写好的 ContentView
            MessageListView()
                .environment(\.managedObjectContext, viewContext) // 设置环境对象
                .environmentObject(sessionManager) // 添加 sessionManager 作为环境对象
                .tabItem {
                    Label("Tab 2", systemImage: "square.and.pencil")
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


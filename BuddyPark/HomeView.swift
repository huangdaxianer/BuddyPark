import SwiftUI

struct HomeView: View {
    @StateObject private var profileData = ProfileData()
    @StateObject private var viewModel = HomeViewModel()

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
                .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext) // 设置环境对象
                .tabItem {
                    Label("Tab 2", systemImage: "square.and.pencil")
                }

            // 第三个 Tab，进入已经写好的 ContentView
            ContentView()
                .tabItem {
                    Label("Tab 3", systemImage: "plus")
                }
        }
    }
}


struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}

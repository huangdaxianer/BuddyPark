import SwiftUI

@main
struct BuddyParkApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var profileData = ProfileData()

       var body: some Scene {
           WindowGroup {
               SwipeView(profiles: $profileData.profiles, onSwiped: { _, _ in
                   // 这里是 swipeUser 的方法，你可以留空或添加自己的逻辑
               })
               .environmentObject(profileData) // 将 profileData 作为环境对象传递
           }
       }
}


class ProfileData: ObservableObject {
    @Published var profiles: [ProfileCardModel] = [
        ProfileCardModel(userId: "defdwsfewfes", name: "Michael Jackson", age: 50, pictures: [UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!]),
              ProfileCardModel(userId: "defdwsfewfes", name: "Michael Jackson", age: 50, pictures: [UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!])
    ]
}

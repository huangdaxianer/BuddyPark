import SwiftUI

@main
struct BuddyParkApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}


class ProfileData: ObservableObject {
    @Published var profiles: [ProfileCardModel] = [
        ProfileCardModel(userId: "defdwsfewfes", name: "Michael Jackson", age: 50, pictures: [UIImage(named: "junxi")!]),
              ProfileCardModel(userId: "defdwsfewfes", name: "Michael Jackson", age: 50, pictures: [UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!])
    ]
}

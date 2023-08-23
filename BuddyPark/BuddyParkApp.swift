import SwiftUI

@main
struct BuddyParkApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject var sessionManager: SessionManager

    init() {
        let context = persistenceController.container.viewContext
        _sessionManager = StateObject(wrappedValue: SessionManager(context: context))
    }


    var body: some Scene {
        WindowGroup {
            HomeView(sessionManager: sessionManager)
                 .environment(\.managedObjectContext, persistenceController.container.viewContext)
                 .environmentObject(sessionManager) // 传递 SessionManager 作为环境对象
        }
    }
}


class ProfileData: ObservableObject {
    @Published var profiles: [ProfileCardModel] = []

    init() {
        for i in 1...20 { // 使用 1...10 而不是 0..<10
            let characterId: Int32 = Int32(arc4random_uniform(1000)) // 生成0到999之间的随机整数
            let name = "俊熙\(i)号"  // 在这里，我们将索引值 i 加到名字后面
            let age = 21
            let pictures: [UIImage] = [UIImage(named: "junxi")!]
            let intro = "体育校队队长，母胎单身，肌肉发达头脑也不简单，喜欢大哥哥。"
            let profile = ProfileCardModel(characterId: characterId, name: name, age: age, pictures: pictures, intro: intro)
            profiles.append(profile)
        }
    }
}



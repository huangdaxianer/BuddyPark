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
    @Published var profiles: [ProfileCardModel] = []

    init() {
        for _ in 0..<10 { // 填充10个样本数据
            let characterId: Int32 = Int32(arc4random_uniform(1000)) // 生成0到999之间的随机整数
            let name = "Michael Jackson"
            let age = 50
            let pictures: [UIImage] = [UIImage(named: "elon_musk")!, UIImage(named: "jeff_bezos")!]
            let profile = ProfileCardModel(characterId: characterId, name: name, age: age, pictures: pictures)
            profiles.append(profile)
        }
    }
}


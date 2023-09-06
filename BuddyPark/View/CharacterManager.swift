import Foundation
import SwiftUI
import UIKit

class CharacterData: ObservableObject {
    @Published var characters: [ProfileCardModel] = []

    init() {
        for i in 1...20 { // 使用 1...10 而不是 0..<10
            let characterId: Int32 = 705
            let name = "俊熙\(i)号"  // 在这里，我们将索引值 i 加到名字后面
            let age = 21
            let pictures: [UIImage] = [UIImage(named: "junxi")!]
            let intro = "体育校队队长，母胎单身，肌肉发达头脑也不简单，喜欢大哥哥。"
            let profile = ProfileCardModel(characterId: characterId, name: name, age: age, pictures: pictures, intro: intro)
            characters.append(profile)
        }
    }
}

struct ProfileCardModel {
    let characterId: Int32
    let name: String
    let age: Int
    let pictures: [UIImage]
    let intro: String
}



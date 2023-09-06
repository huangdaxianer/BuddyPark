import Foundation
import SwiftUI
import UIKit
import CoreData


class CharacterData: ObservableObject {
    @Published var characters: [ProfileCardModel] = []
    
    init() {
        loadCharactersFromCoreData()
        if characters.isEmpty {
      //      createCharactersInCoreData()
            loadCharactersFromCoreData()
        }
    }
    
    private func loadCharactersFromCoreData() {
        let fetchRequest: NSFetchRequest<Character> = Character.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "characterid", ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "status == %@", "raw") // 添加此行来过滤结果
        do {
            let context = CoreDataManager.shared.persistentContainer.viewContext
            let fetchedCharacters = try context.fetch(fetchRequest)
            self.characters = fetchedCharacters.map { ProfileCardModel(character: $0) }
        } catch {
            print("Failed to fetch characters: \(error)")
        }
    }

    
    private func createCharactersInCoreData() {
        let context = CoreDataManager.shared.persistentContainer.viewContext
        
        guard let junxiImage = UIImage(named: "junxi") else {
            print("Failed to load 'junxi' image from assets")
            return
        }
        
        for i in 1...20 {
            let character = Character(context: context)
            character.characterid = Int32(705 + i)
            character.name = "俊熙\(i)号"
            character.age = 21
            character.intro = "体育校队队长，母胎单身，肌肉发达头脑也不简单，喜欢大哥哥。"
            character.status = "raw"
            CharacterManager.shared.saveImage(characterid: character.characterid, image: junxiImage, type: .profile)
        }
        
        CoreDataManager.shared.saveContext()
    }
}


struct ProfileCardModel {
    let characterid: Int32
    let name: String
    let age: Int
    let intro: String
    let image: UIImage?  // 新增一个 UIImage 类型的属性来保存图片
    
    init(character: Character) {
        self.characterid = character.characterid
        self.name = character.name ?? ""
        self.age = Int(character.age)
        self.intro = character.intro ?? ""
        self.image = CharacterManager.shared.loadImage(characterid: character.characterid, type: .profile)
    }
}


class CharacterManager {
    // 单例模式
    static let shared = CharacterManager()

    private init() {}  // 私有化构造器以确保外部不能创建该类的实例

    enum ImageType {
        case profile
        case avatar
    }

    enum CharacterStatus: String {
        case raw
        case liked
        case unliked
    }

    // 文件系统的目录路径
    private var documentDirectory: URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func directory(for type: ImageType) -> URL {
        switch type {
        case .profile:
            return documentDirectory.appendingPathComponent("CharacterProfile", isDirectory: true)
        case .avatar:
            return documentDirectory.appendingPathComponent("CharacterAvatar", isDirectory: true)
        }
    }
    
    // 初始化方法，在应用启动时可以调用这个方法来创建存储目录
    func setupImageDirectory(for type: ImageType) {
        let directory = self.directory(for: type)
        if !FileManager.default.fileExists(atPath: directory.path) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Could not create directory: \(error)")
            }
        }
    }

    func loadImage(characterid: Int32, type: ImageType) -> UIImage? {
        let imagePath = directory(for: type).appendingPathComponent("\(characterid)").path
        if FileManager.default.fileExists(atPath: imagePath), let image = UIImage(contentsOfFile: imagePath) {
            return image
        }
        return nil
    }
    
    func saveImage(characterid: Int32, image: UIImage, type: ImageType) {
        let imagePath = directory(for: type).appendingPathComponent("\(characterid)")
        // 将 UIImage 转换为 Data
        if let imageData = image.jpegData(compressionQuality: 1.0) {
            do {
                try imageData.write(to: imagePath)
            } catch {
                print("Error saving image: \(error)")
            }
        }
    }
    
    func updateCharacterStatus(characterid: Int32, status: CharacterStatus) {
        let context = CoreDataManager.shared.persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<Character> = Character.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "characterid == %d", characterid)
        
        do {
            let characters = try context.fetch(fetchRequest)
            if let character = characters.first {
                character.status = status.rawValue
                try context.save()
            }
        } catch {
            print("Error updating character status: \(error)")
        }
    }

}




import Foundation
import SwiftUI
import UIKit
import CoreData

class CharacterData: ObservableObject {
    @Published var isLoading: Bool = false

    @Published var characters: [ProfileCardModel] = [] {
        didSet {
            if characters.count < 5 && !isLoading {
                isLoading = true
                updateCharactersInCoreData {
                    self.loadCharactersFromCoreData()
                    self.isLoading = false
                }
            }
        }
    }

    init() {
        loadCharactersFromCoreData()
        if characters.isEmpty && !isLoading {
            isLoading = true
            updateCharactersInCoreData {
                self.loadCharactersFromCoreData()
                self.isLoading = false
            }
        }
    }

    private func loadCharactersFromCoreData() {
        let fetchRequest: NSFetchRequest<Character> = Character.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "characterid", ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "status == %@", "raw")
        
        do {
            let context = CoreDataManager.shared.mainManagedObjectContext // Use main context for fetching
            let fetchedCharacters = try context.fetch(fetchRequest)
            self.characters = fetchedCharacters.map { ProfileCardModel(character: $0) }
        } catch {
            print("Failed to fetch characters: \(error)")
        }
    }

    func updateCharactersInCoreData(completion: @escaping () -> Void) {
        let currentMaxid = UserDefaults.standard.string(forKey: "currentMaxCharacterid") ?? "0"
        let nextCharacterid = String(Int(currentMaxid)! + 1)
        fetchCharactersFromServer(characterId: nextCharacterid) { (characters, error) in
            if let characters = characters {
                self.createCharactersInCoreData(characters: characters) {
                    if let maxFetchedCharacterid = characters.max(by: { $0.characterid < $1.characterid })?.characterid {
                        UserDefaults.standard.setValue(maxFetchedCharacterid, forKey: "currentMaxCharacterid")
                    }
                    completion()
                }
            } else {
                print("Error fetching characters: \(error?.localizedDescription ?? "Unknown error")")
                completion()
            }
        }
    }
    
    private func createCharactersInCoreData(characters: [CharacterDataModel], completion: @escaping () -> Void) {
        let context = CoreDataManager.shared.mainManagedObjectContext // Use main context for creating
        let group = DispatchGroup()

        for characterData in characters {
            if let intId = Int(characterData.characterid) {
                let characterID = Int32(intId)

                // Check if the character with this characterid already exists
                if characterExists(withID: characterID, in: context) {
                    continue
                }

                let character = Character(context: context)
                character.characterid = characterID
                character.name = characterData.characterName
                character.age = Int16(characterData.age) ?? 0
                character.intro = characterData.intro
                character.status = "raw"

                group.enter()
                CharacterManager.shared.downloadImage(from: URL(string: characterData.avatarImage)!) { image in
                    if let image = image {
                        CharacterManager.shared.saveImage(characterid: character.characterid, image: image, type: .avatar)
                    }
                    group.leave()
                }

                group.enter()
                CharacterManager.shared.downloadImage(from: URL(string: characterData.profileImage)!) { image in
                    if let image = image {
                        CharacterManager.shared.saveImage(characterid: character.characterid, image: image, type: .profile)
                    }
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            CoreDataManager.shared.saveChanges() // Change from saveContext to the new method saveChanges
            completion()
        }
    }

    private func characterExists(withID id: Int32, in context: NSManagedObjectContext) -> Bool {
        let fetchRequest: NSFetchRequest<Character> = Character.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "characterid == %d", id)
        fetchRequest.fetchLimit = 1

        do {
            let count = try context.count(for: fetchRequest)
            return count > 0
        } catch {
            print("Error checking if character exists: \(error)")
            return false
        }
    }
    
    func fetchCharactersFromServer(characterId: String, completion: @escaping ([CharacterDataModel]?, Error?) -> Void) {
        let urlString = messageService + "getCharacters?characterid=\(characterId)"
        
        guard let url = URL(string: urlString) else {
            completion(nil, NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        URLSession.shared.dataTask(with: url) { (data, response, error) in
            if let data = data {
                do {
                    let characters = try JSONDecoder().decode([CharacterDataModel].self, from: data)
                    completion(characters, nil)
                } catch {
                    completion(nil, error)
                }
            } else {
                completion(nil, error)
            }
        }.resume()
    }
}

struct CharacterDataModel: Codable {
    let age: String
    let avatarImage: String
    let characterName: String
    let profileImage: String
    let intro: String
    let characterid: String
}


struct ProfileCardModel: Identifiable {
    var id: Int32 { characterid }
    let characterid: Int32
    let name: String
    let age: Int
    let intro: String
    let image: UIImage?  
    
    init(character: Character) {
        self.characterid = character.characterid
        self.name = character.name ?? ""
        self.age = Int(character.age)
        self.intro = character.intro ?? ""
        self.image = CharacterManager.shared.loadImage(characterid: character.characterid, type: .profile)
    }
}

extension ProfileCardModel: Equatable {
    static func == (lhs: ProfileCardModel, rhs: ProfileCardModel) -> Bool {
        return lhs.characterid == rhs.characterid
    }
}


class CharacterManager {
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
    
    private var documentDirectory: URL {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)!
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
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: imagePath) {
            if let image = UIImage(contentsOfFile: imagePath) {
                print("成功加载了照片")
                return image
            }
        }
        return nil
    }

    
    func downloadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            completion(UIImage(data: data))
        }
        task.resume()
    }
    
    func saveImage(characterid: Int32, image: UIImage, type: ImageType) {
        let directoryPath = directory(for: type)
        let imagePath = directoryPath.appendingPathComponent("\(characterid)")
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: directoryPath.path) {
            do {
                // 如果文件夹不存在，创建它
                try fileManager.createDirectory(at: directoryPath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                return
            }
        } else {
        }
        
        // 将 UIImage 转换为 Data
        if let imageData = image.jpegData(compressionQuality: 1.0) {
            do {
                try imageData.write(to: imagePath)
            } catch {
            }
        } else {
            print("Error: Unable to convert UIImage to jpegData for character ID: \(characterid)")
        }
    }


    
    func updateCharacterStatus(characterid: Int32, status: CharacterStatus) {
        let context = CoreDataManager.shared.mainManagedObjectContext
        let fetchRequest: NSFetchRequest<Character> = Character.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "characterid == %d", characterid)
        
        do {
            let characters = try context.fetch(fetchRequest)
            if let character = characters.first {
                character.status = status.rawValue
                CoreDataManager.shared.saveChanges()
            }
        } catch {
            print("Error updating character status: \(error)")
        }
    }
    
    func resetNewMessageNumForContact(characterid: Int32) {
        let context = CoreDataManager.shared.mainManagedObjectContext
        let fetchRequest: NSFetchRequest<Contact> = Contact.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "characterid == %d", characterid)
        
        do {
            let contacts = try context.fetch(fetchRequest)
            if let contact = contacts.first {
                contact.newMessageNum = 0
                CoreDataManager.shared.saveChanges()
            }
        } catch {
            print("Error resetting newMessageNum for Contact: \(error)")
        }
    }
}

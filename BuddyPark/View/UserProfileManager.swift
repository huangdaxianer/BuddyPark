import Foundation
import AuthenticationServices
import CoreData

struct User {
    let uuid: String
    let isNewUser: Bool
}

class UserProfileManager: ObservableObject {
    static let shared = UserProfileManager()
    
    @Published var currentUser: User?
    
    private init() {
        currentUser = loadUser()
    }
    
    func getUserID() -> String? {
        let defaults = UserDefaults.standard
        return defaults.string(forKey: "userUUID")
    }

    
    func persistUser(_ user: User) {
        let defaults = UserDefaults.standard
        defaults.set(user.uuid, forKey: "userUUID")
        defaults.set(user.isNewUser, forKey: "userIsNewUser")
        currentUser = user
    }
    
    func loadUser() -> User? {
        let defaults = UserDefaults.standard
        if let uuid = defaults.string(forKey: "userUUID") {
            let isNewUser = defaults.bool(forKey: "userIsNewUser")
            return User(uuid: uuid, isNewUser: isNewUser)
        }
        return nil
    }
    
    func saveUserName(_ name: String) {
        let defaults = UserDefaults.standard
        defaults.set(name, forKey: "userName")
    }
    
    func saveUserDescription(_ description: String) {
        let defaults = UserDefaults.standard
        defaults.set(description, forKey: "userDescription")
    }
    
    func saveUserGender(_ gender: String) {
        let defaults = UserDefaults.standard
        defaults.set(gender, forKey: "userGender")
    }
    
    func saveRoleGender(_ gender: String) {
        let defaults = UserDefaults.standard
        defaults.set(gender, forKey: "roleGender")
    }
    
    func signInWithAppleID(identityToken: String, userGender: String, roleGender: String, userName: String, userBio: String, completion: @escaping (Result<User, Error>) -> Void) {
        let completeURLString = serviceURL + "auth"
        guard let url = URL(string: completeURLString) else {
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // 包含所有新增的用户信息参数
        let parameters = [
            "identityToken": identityToken,
            "userGender": userGender, // 新增用户性别
            "roleGender": roleGender, // 新增角色性别
            "userName": userName, // 用户名称
            "userBio": userBio // 用户描述
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)

        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data"])))
                }
                return
            }

            do {
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                print("Received JSON response:", json ?? "nil")
                guard let success = json?["success"] as? Bool, success == true,
                      let uuid = json?["uuid"] as? String,
                      let isNewUser = json?["isNewUser"] as? Bool,
                      let freeMessageLeft = json?["freeMessageLeft"] as? Int else {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                    }
                    return
                }

                let user = User(uuid: uuid, isNewUser: isNewUser)
                DispatchQueue.main.async {
                    self.persistUser(user)
                    let userDefaults = UserDefaults(suiteName: appGroupName)
                    userDefaults?.set(freeMessageLeft, forKey: "freeMessageLeft")
                    // 这里保存用户的额外信息
                    self.saveUserGender(userGender)
                    self.saveRoleGender(roleGender)
                    self.saveUserName(userName)
                    self.saveUserDescription(userBio)
                    completion(.success(user))
                }
            } catch {
                print("JSON parsing error:", error.localizedDescription)
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }

        task.resume()
    }

    
    
    func signOut() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "userUUID")
        defaults.removeObject(forKey: "userIsNewUser")
        defaults.removeObject(forKey: "userName")
        defaults.removeObject(forKey: "userDescription")
        currentUser = nil
        CoreDataManager.shared.deleteAllData()
        objectWillChange.send()
    }
    
        func isUserLoggedIn() -> Bool {
            return loadUser() != nil
        }
}



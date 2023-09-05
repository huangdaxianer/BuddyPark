import Foundation
import AuthenticationServices

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
        return UUID().uuidString
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

//    func signInWithAppleID(identityToken: String, completion: @escaping (Result<User, Error>) -> Void) {
//        // URL 是你的云函数的 URL
//        guard let url = URL(string: "https://service-nwqor1b8-1251732024.jp.apigw.tencentcs.com/release/") else {
//            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
//            return
//        }
//
//        var request = URLRequest(url: url)
//        request.httpMethod = "POST"
//        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
//
//        let parameters = ["identityToken": identityToken]
//        request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
//
//        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
//            if let error = error {
//                DispatchQueue.main.async {
//                    completion(.failure(error))
//                }
//                return
//            }
//
//            guard let data = data else {
//                DispatchQueue.main.async {
//                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data"])))
//                }
//                return
//            }
//
//            do {
//                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
//                guard let success = json?["success"] as? Bool, success == true,
//                      let uuid = json?["uuid"] as? String,
//                      let isNewUser = json?["isNewUser"] as? Bool,
//                      let freeMessageLeft = json?["freeMessageLeft"] as? Int else {
//                    DispatchQueue.main.async {
//                        completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
//                    }
//                    return
//                }
//
//                let user = User(uuid: uuid, isNewUser: isNewUser)
//                DispatchQueue.main.async {
//                    // 将用户存储到某处
//                    self.persistUser(user)
//
//                    // 将 freeMessageLeft 存储到 UserDefaults
//                    let userDefaults = UserDefaults(suiteName: self.appGroupName)
//                    userDefaults?.set(freeMessageLeft, forKey: "freeMessageLeft")
//                    completion(.success(user))
//                }
//            }catch {
//                DispatchQueue.main.async {
//                    completion(.failure(error))
//                }
//            }
//        }
//
//        task.resume()
//    }

    func signOut() {
        // 在这里实现注销用户的代码，例如删除存储的用户信息
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "userUUID")
        defaults.removeObject(forKey: "userIsNewUser")
        currentUser = nil
    }


}


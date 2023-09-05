import Foundation
import StoreKit

class SubscriptionManager: NSObject, SKProductsRequestDelegate, SKPaymentTransactionObserver, ObservableObject {
    static let shared = SubscriptionManager()
    private var product: SKProduct? // 保存商品对象
    @Published var productInfo: ProductInfo?  // 商品信息
    var onSubscriptionFailure: ((String) -> Void)?
    var onSubscriptionSuccess: (() -> Void)? // 添加订阅成功的回调
    private let baseURL = "https://service-1s3fy2a0-1251732024.jp.apigw.tencentcs.com/release"

    @Published var subscriptionStatus: Bool = false
    @Published var expiresDate: Int64 = 0
    @Published var hasUsedTrial: Bool = false
    @Published var isTrialPeriod: Bool = false
    @Published var freeMessageLeft: Int = 0
    
    func canSendMessage() -> Bool {
        return true

        
//        let userDefaults = UserDefaults(suiteName: appGroupName)
//        var freeMessageLeft = userDefaults?.integer(forKey: "freeMessageLeft") ?? 0
//
//        if freeMessageLeft > 0 {
//            freeMessageLeft -= 1
//            userDefaults?.set(freeMessageLeft, forKey: "freeMessageLeft")
//            return true
//        } else {
//            print("No free messages left.")
//            return false
//        }
    }

    
    private override init() {
        super.init()
        SKPaymentQueue.default().add(self)
    }
    // 商品ID
    private var subscriptionProductID: String {
        // 你需要将这个值替换为你的商品ID
        return "back_weekly_subscription_1"
    }
    // 购买订阅
    func purchaseSubscription() {
        guard let product = self.product else {
            print("Error: Product is nil. Fetch product info first.")
            return
        }
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }

    // 恢复购买
    func restorePurchases() {
        SKPaymentQueue.default().restoreCompletedTransactions()
    }

    // 获取订阅商品的信息
    func fetchSubscriptionInfo() {
        let request = SKProductsRequest(productIdentifiers: [subscriptionProductID])
        request.delegate = self
        request.start()
    }
    
    // SKProductsRequestDelegate
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        if let product = response.products.first {
            DispatchQueue.main.async {
                // 更新商品信息
                self.productInfo = ProductInfo(title: product.localizedTitle,
                                               description: product.localizedDescription,
                                               price: product.localizedPrice()) // 添加这一行
                // 更新商品对象
                self.product = product
            }
        } else {
            print("Error: No product found for identifier \(subscriptionProductID)")
        }
    }

    // SKPaymentTransactionObserver
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased, .restored:
                // 你可能需要在这里实现你的逻辑，比如更新用户的订阅状态，发送通知，等等
                let receiptData = fetchReceipt() // 这个函数从 Bundle 中获取 App 收据
                let uuid = UserDefaults.standard.string(forKey: "userUUID") ?? ""

                var request = URLRequest(url: URL(string: "\(baseURL)/verify-receipt")!)
                request.httpMethod = "POST"
                let postDictionary = ["receiptData": receiptData, "userIdentifier": uuid]
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: postDictionary, options: .fragmentsAllowed)
                    request.httpBody = jsonData
                } catch {
                    print("Error: Unable to convert dictionary to JSON data")
                }

                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                    if let error = error {
                        print("Error: \(error)")
                    } else if let httpResponse = response as? HTTPURLResponse, let data = data {
                        let statusCode = httpResponse.statusCode
                        if statusCode == 402 {
                            if let errorMessage = String(data: data, encoding: .utf8) {
                                DispatchQueue.main.async {
                                    self.onSubscriptionFailure?(errorMessage)
                                }
                            }
                        } else {
                            DispatchQueue.main.async {
                                self.getSubscriptionStatus()
                                self.onSubscriptionSuccess?()
                            }
                        }
                    }
                }
                task.resume()

                SKPaymentQueue.default().finishTransaction(transaction)
            case .failed, .deferred:
                // 你可能需要在这里实现你的逻辑，比如显示错误信息，发送通知，等等
                if let error = transaction.error {
                    print("Error: Transaction failed or deferred with error: \(error.localizedDescription)")
                }
                SKPaymentQueue.default().finishTransaction(transaction)
            case .purchasing:
                break
            @unknown default:
                break
            }
        }
    }
    
    func getSubscriptionStatus() {
        let userIdentifier = UserDefaults.standard.string(forKey: "userUUID") ?? ""
        guard !userIdentifier.isEmpty, let url = URL(string: "\(baseURL)/subscription-status/\(userIdentifier)") else {
            print("Invalid URL or missing user UUID")
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                    let subscriptionStatus = json?["subscriptionStatus"] as? [String: Any]
                    DispatchQueue.main.async {
                        self.subscriptionStatus = subscriptionStatus?["isSubscribed"] as? Bool ?? false
                        self.expiresDate = subscriptionStatus?["expiresDate"] as? Int64 ?? 0
                        self.hasUsedTrial = subscriptionStatus?["hasUsedTrial"] as? Bool ?? false
                        self.isTrialPeriod = subscriptionStatus?["isTrialPeriod"] as? Bool ?? false
                        self.freeMessageLeft = subscriptionStatus?["freeMessageLeft"] as? Int ?? 0
                    }
                    let userDefaults = UserDefaults(suiteName: appGroupName)
                    userDefaults?.set(self.freeMessageLeft, forKey: "freeMessageLeft")
                    UserDefaults.standard.set(self.subscriptionStatus, forKey: "isSubscribed")
                    UserDefaults.standard.set(self.expiresDate, forKey: "expiresDate")
                    UserDefaults.standard.set(self.hasUsedTrial, forKey: "hasUsedTrial")
                    UserDefaults.standard.set(self.isTrialPeriod, forKey: "isTrialPeriod")
                } catch {
                    print("JSON decoding error: \(error)")
                }
            } else if let error = error {
                print("Error fetching subscription status: \(error)")
            }
        }.resume()
    }

    func fetchReceipt() -> String {
        guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL,
              FileManager.default.fileExists(atPath: appStoreReceiptURL.path) else {
            return ""
        }

        do {
            let receiptData = try Data(contentsOf: appStoreReceiptURL, options: .alwaysMapped)
            let receiptString = receiptData.base64EncodedString(options: [])
            return receiptString
        } catch {
            print("Couldn't read receipt data with error: " + error.localizedDescription)
            return ""
        }
    }
    
}

struct ProductInfo {
    let title: String
    let description: String
    let price: String
}

extension SKProduct {
    func localizedPrice() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = self.priceLocale
        return formatter.string(from: self.price) ?? ""
    }

    func freeTrialPeriod() -> String? {
        for discount in self.discounts {
            if discount.paymentMode == .freeTrial {
                let periodUnit: String
                switch discount.subscriptionPeriod.unit {
                case .day:
                    periodUnit = "day(s)"
                case .week:
                    periodUnit = "week(s)"
                case .month:
                    periodUnit = "month(s)"
                case .year:
                    periodUnit = "year(s)"
                @unknown default:
                    periodUnit = "unknown unit"
                }
                let freeTrialInfo = "Free trial for \(discount.subscriptionPeriod.numberOfUnits) \(periodUnit)"
                print("Free Trial Info: \(freeTrialInfo)") // 打印免费试用期信息
                return freeTrialInfo
            }
        }
        return nil
    }
}



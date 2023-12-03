//
//  StoreVM.swift
//  Subscriptions
//
//  Created by Nailya Ravilevna on 01.12.23.
//

import Foundation
import StoreKit

//alias
typealias RenewalInfo = StoreKit.Product.SubscriptionInfo.RenewalInfo // provides information about the next subscription renewal period.
typealias RenewalState = StoreKit.Product.SubscriptionInfo.RenewalState // the renewal states of auto-renewable subscriptions.


class StoreVM: ObservableObject {
    @Published private(set) var subscriptions: [Product] = []
    @Published private(set) var purchasedSubscriptions: [Product] = []
    @Published private(set) var subscriptionGroupStatus: RenewalState?
    @Published var showLifetimeSubscriptionAlert = false
    @Published var isLifetimeSubscription = false
    
    private let productIds: [String] = ["subscription.yearly", "subscription.weekly", "subscription.lifetime"]
    
    var updateListenerTask : Task<Void, Error>? = nil

    init() {
        
        //start a transaction lister as close to app launch as possible so you don't miss a transaction
        updateListenerTask = listenForTransactions()
        
        Task {
            await requestProducts()
            
            await updateCustomerProductStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    func unlockLifetimeSubscriptionFeatures() {
        isLifetimeSubscription = true
        
        //trigger UI update
        DispatchQueue.main.async {
            self.showLifetimeSubscriptionAlert = true
        }
    }
    
    func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            //Iterate through any transactions that don't come from a direct call to `purchase()`.
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    // deliver products to the user
                    await self.updateCustomerProductStatus()
                    
                    await transaction.finish()
                } catch {
                    print("transaction failed verification")
                }
            }
        }
    }
    
    
    
    // Request the products
    @MainActor
    func requestProducts() async {
        do {
            // request from the app store using the product ids (hardcoded)
            subscriptions = try await Product.products(for: productIds)
            print("Fetched products: \(subscriptions)")
        } catch {
            print("Failed product request from app store server: \(error)")
        }
    }
    
    // purchase the product
    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            //Check whether the transaction is verified. If it isn't,
            //this function rethrows the verification error.
            let transaction = try checkVerified(verification)
            
            //The transaction is verified. Deliver content to the user.
            await updateCustomerProductStatus()
            
            //Always finish a transaction.
            await transaction.finish()

            return transaction
        case .userCancelled, .pending:
            return nil
        default:
            return nil
        }
    }
    
    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        //Check whether the JWS passes StoreKit verification.
        switch result {
        case .unverified:
            //StoreKit parses the JWS, but it fails verification.
            throw StoreError.failedVerification
        case .verified(let safe):
            //The result is verified. Return the unwrapped value.
            return safe
        }
    }
    //method to restore purchases
    func restorePurchases() async {
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                //deliver content, update user's subscription status
                await updateCustomerProductStatus()
                await transaction.finish()
                
            } catch {
                print("restore failed: \(error)")
            }
        }
    }
    
    func validatePurchaseWithServer(transaction: Transaction) async {
        guard let url = URL(string: "https://testserver.com/api/validatePurchase")else {return}
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let purchaseData = PurchaseData(productId: transaction.productID, transactionId: "\(transaction.id)")
        request.httpBody = try? JSONEncoder().encode(purchaseData)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            handleServerResponse(data)
        } catch {
            print("Error sending purchase data to server: \(error)")
        }
    }
    
    func handleServerResponse(_ data: Data) {
        
    }
    
    @MainActor
    func updateCustomerProductStatus() async {
        for await result in Transaction.currentEntitlements {
            do {
                //Check whether the transaction is verified. If it isn’t, catch `failedVerification` error.
                let transaction = try checkVerified(result)
                
                switch transaction.productType {
                case .autoRenewable:
                        if let subscription = subscriptions.first(where: {$0.id == transaction.productID}) {
                            purchasedSubscriptions.append(subscription)
                            await validatePurchaseWithServer(transaction: transaction)
                        }
                case .nonConsumable:
                    if transaction.productID == "subscription.lifetime" {
                        // mark the lifetime subscription as purchased
                        UserDefaults.standard.set(true, forKey: "isLifetimeSubscribed")
                        //unlock features or content (optional)
                        unlockLifetimeSubscriptionFeatures()
                        //also optional- notify the user
                        DispatchQueue.main.async {
                            DispatchQueue.main.async {
                                self.showLifetimeSubscriptionAlert = true
                            }
                        }
                    }
                    
                    default:
                        break
                }
                //Always finish a transaction.
                await transaction.finish()
            } catch {
                print("failed updating products")
            }
        }
    }
    struct PurchaseData: Codable {
        let productId: String
        let transactionId: String
    }

}


public enum StoreError: Error {
    case failedVerification
}


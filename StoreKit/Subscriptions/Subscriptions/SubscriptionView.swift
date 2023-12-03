//
//  SubscriptionView.swift
//  Subscriptions
//
//  Created by Nailya Ravilevna on 01.12.23.
//


import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @EnvironmentObject var storeVM: StoreVM
    @State var isPurchased = false

    var body: some View {
        Group {
            Section("Subscribe to use, or try for free for 7 days") {
                ForEach(storeVM.subscriptions) { product in
                    Button(action: {
                        Task {
                            await buy(product: product)
                        }
                    }) {
                        
                        VStack {
                            HStack {
                                Text(product.displayPrice)
                                Text(product.displayName)
                            }
                            Text(product.description)
                        }.padding()
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(15.0)
                }
            }
            
        }.onAppear {
            print("Available subscriptions: \(storeVM.subscriptions)")
        }
    }
    
    func buy(product: Product) async {
        do {
            if try await storeVM.purchase(product) != nil {
                isPurchased = true
            }
        } catch {
            print("purchase failed")
        }
    }
}

struct SubscriptionView_Previews: PreviewProvider {
    static var previews: some View {
        SubscriptionView().environmentObject( StoreVM())
    }
}

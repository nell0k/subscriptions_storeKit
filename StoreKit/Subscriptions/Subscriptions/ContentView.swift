//
//  ContentView.swift
//  Subscriptions
//
//  Created by Nailya Ravilevna on 27.11.23.
//
import SwiftUI
import StoreKit

struct ContentView: View {
    @StateObject var storeVM = StoreVM()
    var body: some View {
        VStack {
            
            /*if let subscriptionGroupStatus = storeVM.subscriptionGroupStatus {
             if subscriptionGroupStatus == .expired || subscriptionGroupStatus == .revoked {
             Text("Welcome back, give the subscription another try.")
             Button("Restore Purchases") {
             Task {
             await storeVM.restorePurchases()
             }
             }}}*/
            if storeVM.purchasedSubscriptions.isEmpty {
                SubscriptionView()
                
            } else {
                //show lifetime subscription status
                if storeVM.isLifetimeSubscription {
                    Text("Lifetime Subscription Active!")
                        .font(.title)
                        .foregroundColor(.green)
                } else {
                    
                    //show regular subscription status
                    Text("Subscriptions")
                }
            }
            
            //restore purchases button
            Button("Restore Purchases") {
                Task {
                    await storeVM.restorePurchases()
                }
            }
        }
        .onAppear {
            Task {
                await storeVM.requestProducts()
            }
        }
        .padding()
        .environmentObject(storeVM)
        .alert(isPresented: $storeVM.showLifetimeSubscriptionAlert) {
            Alert(title: Text("Purchase Successful!"),
                  message: Text("You've successfully subscribed for a lifetime."),
                  dismissButton: .default(Text("OK")))
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environmentObject(StoreVM())
    }
}

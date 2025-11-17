import SwiftUI
import UIKit

struct ReferralView: View {
    @ObservedObject private var pm = PointsManager.shared
    
    var body: some View {
        ZStack {
            gradientBackground
            VStack(spacing: 30) {
                if !pm.hasWallet {
                    Text("Verify wallet first!").font(.largeTitle).bold().foregroundStyle(.white)
                    NavigationLink("Go to Wallet", destination: WalletView())
                        .buttonStyle(.borderedProminent).tint(.orange)
                } else if pm.referralCode.isEmpty {
                    Text("Loading your code...")
                } else {
                    Text("Your Referral Code").font(.largeTitle).bold().foregroundStyle(.orange)
                    Text(pm.referralCode).font(.system(size: 36)).bold().padding().background(.ultraThinMaterial).cornerRadius(16)
                    Button("Share Code") {
                        let activity = UIActivityViewController(activityItems: ["Join BTCZ with my code \(pm.referralCode) and get +5 BTCZ!"], applicationActivities: nil)
                        UIApplication.shared.windows.first?.rootViewController?.present(activity, animated: true)
                    }
                    .buttonStyle(.borderedProminent).tint(.orange)
                }
                Spacer()
            }.padding()
        }
        .navigationTitle("Referral")
    }
    
    private var gradientBackground: some View {
        LinearGradient(colors: [.blue.opacity(0.9), .black, .orange.opacity(0.6)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }
}

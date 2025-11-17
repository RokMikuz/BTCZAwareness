// ReferralView.swift – 100 % CELOTNA – Z LEPŠIM INFO SHEETOM (manjši, gradient, lepši tekst)
import SwiftUI

struct ReferralView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var backPressed = false
    
    // UPORABLJAMO PointsManager ZA CODE IN STATISTIKO
    @ObservedObject private var pointsManager = PointsManager.shared
    
    @State private var invitedCount = 0
    @State private var earnedBTCZ = 0
    @State private var isLoading = true
    @State private var showCopied = false
    @State private var showHowToSheet = false  // INFO SHEET
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.indigo.opacity(0.9), .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // HEADER Z BACK GUMBOM + BTCZ LOGO + INFO GUMBEK
                HStack {
                    Spacer()
                    
                    // BTCZ LOGO S PULSE
                    Image("btcz_logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .shadow(color: .yellow.opacity(0.7), radius: 10)
                        .symbolEffect(.pulse)
                    
                    Spacer()
                    
                    // INFO GUMBEK – kako uporabiti code
                    Button {
                        showHowToSheet = true
                    } label: {
                        Image(systemName: "info.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.cyan)
                            .padding()
                    }
                }
                .padding(.top, 10)
                
                // NASLOV
                Text("Invite Friends & Earn BTCZ")
                    .font(.largeTitle.bold())
                    .foregroundStyle(
                        LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
                    )
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                if isLoading {
                    ProgressView("Loading your stats...")
                        .scaleEffect(1.5)
                        .foregroundStyle(.white)
                } else {
                    // REFERRAL CODE – MANJŠI, PRILAGODLJIV FONT
                    VStack(spacing: 20) {
                        Text("Your Referral Code")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.8))
                        
                        HStack {
                            Text(pointsManager.referralCode.isEmpty ? "No code yet" : pointsManager.referralCode)
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(.yellow)
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                                .padding()
                            
                            Button {
                                let code = pointsManager.referralCode
                                guard !code.isEmpty else { return }
                                UIPasteboard.general.string = code
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    showCopied = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation {
                                        showCopied = false
                                    }
                                }
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.title)
                                    .foregroundStyle(.white)
                                    .padding(12)
                                    .background(.purple.opacity(0.8))
                                    .clipShape(Circle())
                                    .scaleEffect(showCopied ? 1.2 : 1.0)
                                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: showCopied)
                            }
                            .disabled(pointsManager.referralCode.isEmpty)
                        }
                        .background(.black.opacity(0.6))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(.yellow.opacity(0.8), lineWidth: 3)
                        )
                        .shadow(color: .yellow.opacity(0.6), radius: 15)
                        .padding(.horizontal, 40)
                        
                        if showCopied {
                            Text("Copied!")
                                .font(.headline)
                                .foregroundStyle(.green)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    
                    // STATISTIKA
                    VStack(spacing: 30) {
                        HStack(spacing: 50) {
                            VStack {
                                Text("\(invitedCount)")
                                    .font(.system(size: 70, weight: .black))
                                    .foregroundStyle(.cyan)
                                Text("Friends Invited")
                                    .font(.title3)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            
                            VStack {
                                Text("\(earnedBTCZ)")
                                    .font(.system(size: 70, weight: .black))
                                    .foregroundStyle(.green)
                                Text("BTCZ Earned")
                                    .font(.title3)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                        .padding()
                        .background(.black.opacity(0.5))
                        .cornerRadius(20)
                        .padding(.horizontal, 30)
                    }
                    
                    // SHARE GUMB
                    Button("Share Your Code") {
                        shareReferral()
                    }
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(colors: [.pink, .purple], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(20)
                    .shadow(color: .pink.opacity(0.6), radius: 15)
                    .padding(.horizontal, 40)
                    
                    Spacer()
                }
            }
            .onAppear {
                loadReferralStats()
                // Ensure we have the latest referral code from server
                ApiService.getPointsWithRestore { _, code in
                    DispatchQueue.main.async {
                        if let code = code, !code.isEmpty {
                            PointsManager.shared.referralCode = code
                        }
                    }
                }
            }
            .sheet(isPresented: $showHowToSheet) {
                howToUseReferralSheet
            }
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        backPressed = true
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                            backPressed = false
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title2.bold())
                            .foregroundStyle(.orange)
                            .scaleEffect(backPressed ? 0.92 : 1.0)
                            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: backPressed)
                    }
                }
            }
        }
    }
    
    private func loadReferralStats() {
        isLoading = true
        
        ApiService.getReferralStats { stats in
            DispatchQueue.main.async {
                if let stats = stats,
                   let success = stats["success"] as? Bool, success {
                    self.invitedCount = stats["invited_count"] as? Int ?? 0
                    self.earnedBTCZ = stats["earned_btcz"] as? Int ?? 0
                } else {
                    self.invitedCount = 0
                    self.earnedBTCZ = 0
                }
                self.isLoading = false
            }
        }
    }
    
    private func shareReferral() {
        let code = pointsManager.referralCode
        let shareText: String
        if code.isEmpty {
            shareText = "Join me on BTCZ Awareness app and earn real BTCZ!\nDownload: https://getbtcz.com/app"
        } else {
            shareText = "Join me on BTCZ Awareness app and earn real BTCZ!\nMy referral code: \(code)\nDownload: https://getbtcz.com/app"
        }

        // Build activity items
        var items: [Any] = [shareText]

        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)

        // Prefer to exclude actions that don't make sense for text-only sharing
        activityVC.excludedActivityTypes = [
            .addToReadingList,
            .assignToContact,
            .openInIBooks,
            .markupAsPDF,
            .print,
            .saveToCameraRoll
        ]

        // iPad-safe popover configuration
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }),
           let rootVC = window.rootViewController {

            // Find top-most presenter
            let presenterVC: UIViewController = {
                var top = rootVC
                while let presented = top.presentedViewController { top = presented }
                return top
            }()

            if let pop = activityVC.popoverPresentationController {
                pop.sourceView = presenterVC.view
                pop.sourceRect = CGRect(x: presenterVC.view.bounds.midX, y: presenterVC.view.bounds.midY, width: 0, height: 0)
                pop.permittedArrowDirections = []
            }

            presenterVC.present(activityVC, animated: true)
        }
    }
    
    // LEPŠI INFO SHEET – manjši od ekrana, gradient, lepši tekst
    private var howToUseReferralSheet: some View {
        VStack(alignment: .leading, spacing: 25) {
            Text("How to use Referral Code")
                .font(.title.bold())
                .foregroundStyle(
                    LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
                )
            
            VStack(alignment: .leading, spacing: 15) {
                Text("1. Share your unique code with friends")
                Text("2. Friend downloads the app")
                Text("3. Friend connects their wallet")
                Text("4. Friend enters your code during wallet connection")
                Text("5. Both of you earn BTCZ bonus!")
            }
            .font(.body)
            .foregroundStyle(.white)
            
            Text("You earn BTCZ for every successful referral!")
                .font(.title3.bold())
                .foregroundStyle(.green)
                .padding(.top, 10)
            
            Button("Close") {
                showHowToSheet = false
            }
            .font(.headline.bold())
            .foregroundStyle(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(16)
            .padding(.top, 20)
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [.indigo.opacity(0.95), .black.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.orange.opacity(0.6), lineWidth: 2)
            )
            .shadow(color: .purple.opacity(0.6), radius: 20)
        )
        .padding(40)  // manjši od ekrana
        .presentationBackground(.clear)
    }
}

#Preview {
    ReferralView()
}

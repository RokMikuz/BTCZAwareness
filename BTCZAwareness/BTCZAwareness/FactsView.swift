// FactsView.swift – 100 % CELOTNA – Z BACK GUMBOM + ATRAKTIVNI DIZAJN + ANIMACIJA NAGRADE
import SwiftUI
import UIKit

struct FactsView: View {
    @Environment(\.dismiss) private var dismiss  // za back gumb
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var facts: [String] = []
    @State private var isLoading = true
    @State private var currentFact: String = "Tap to reveal a Fun Fact!"
    @State private var funFactShareReward = 25
    @State private var sharesToday = 0
    @State private var lastShareDate: Date? = UserDefaults.standard.object(forKey: "lastFunFactShareDate") as? Date
    
    @State private var showRewardAnimation = false
    @State private var rewardScale: CGFloat = 1.0
    @State private var rewardOpacity: Double = 0.0
    
    @State private var showServerError = false
    @State private var serverErrorMessage = "Server is currently unavailable. Please try again later."
    
    @State private var shareHashtags = "#BTCZ #BitcoinZ #PrivacyCoin"
    
    @State private var backPressed = false
    
    private let maxSharesPerDay = 5
    
    var canShare: Bool {
        if let lastDate = lastShareDate {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let lastDay = calendar.startOfDay(for: lastDate)
            if calendar.isDate(today, inSameDayAs: lastDay) {
                return sharesToday < maxSharesPerDay
            }
        }
        return true
    }
    
    var remainingShares: Int {
        maxSharesPerDay - sharesToday
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                
                VStack(spacing: 28) {
                    Spacer()
                    
                    // FUN FACT CARD – ATRAKTIVNA (neo/3D look)
                    ZStack {
                        RoundedRectangle(cornerRadius: 32)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.06), Color.black.opacity(0.18)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 32)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.3), Color.white.opacity(0.06)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 30)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 2)
                                    .blur(radius: 1)
                                    .padding(2)
                            )
                            .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 10)
                            .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 2)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 200)
                            .frame(maxHeight: 450)
                            .padding(.horizontal, 30)
                        
                        ScrollView {
                            VStack(spacing: 20) {
                                // lightbulb icon with neo/3D style circle background
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.white.opacity(0.06), Color.black.opacity(0.15)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 90, height: 90)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 45)
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [Color.white.opacity(0.3), Color.white.opacity(0.06)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 1.5
                                                )
                                        )
                                        .overlay(
                                            Capsule()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                                                        startPoint: .top,
                                                        endPoint: .bottom
                                                    )
                                                )
                                                .frame(width: 74, height: 16)
                                                .rotationEffect(.degrees(-25))
                                                .offset(x: -8, y: -16)
                                                .blendMode(.screen)
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(Color.yellow.opacity(0.9), lineWidth: 2)
                                                .shadow(color: Color.yellow.opacity(0.5), radius: 10)
                                        )
                                    
                                    Image(systemName: "lightbulb.fill")
                                        .font(.system(size: 44))
                                        .foregroundStyle(.yellow)
                                        .shadow(color: Color.yellow.opacity(0.3), radius: 6, x: 0, y: 0)
                                }
                                
                                Text(currentFact)
                                    .font(.title2.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(8)
                                    .padding(.horizontal, 40)
                                    .lineLimit(nil)
                                    .minimumScaleFactor(0.6)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Text("Reward for sharing: \(funFactShareReward) BTCZ")
                                    .font(.headline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                                    .foregroundStyle(.green)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        }
                    }
                    
                    // STATUS SHARE
                    Text(canShare ? "You can share \(remainingShares) more time(s) today" : "Daily share limit reached (5)")
                        .font(.title3)
                        .foregroundStyle(canShare ? .green : .red.opacity(0.85))
                        .padding(.top, 4)
                    
                    // GUMB ZA RANDOM FACT
                    Button {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.7)) {
                            getRandomFact()
                        }
                    } label: {
                        Text("Reveal New Fun Fact")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(24)
                            .shadow(color: .orange.opacity(0.8), radius: 15)
                    }
                    .padding(.horizontal, 40)
                    
                    // SHARE GUMBI neo style
                    HStack(spacing: 60) {
                        Button {
                            shareOnX(text: currentFact, hashtags: shareHashtags)
                        } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    // Background circle layers
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.white.opacity(0.06), Color.black.opacity(0.15)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 70, height: 70)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 35)
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [Color.white.opacity(0.3), Color.white.opacity(0.06)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 1.5
                                                )
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 33)
                                                .stroke(Color.white.opacity(0.08), lineWidth: 2)
                                                .blur(radius: 1)
                                                .padding(2)
                                        )
                                        .overlay(
                                            Capsule()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                                                        startPoint: .top,
                                                        endPoint: .bottom
                                                    )
                                                )
                                                .frame(width: 54, height: 12)
                                                .rotationEffect(.degrees(-25))
                                                .offset(x: -6, y: -11)
                                                .blendMode(.screen)
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white.opacity(0.9), lineWidth: 2)
                                        )
                                    
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundStyle(.white)
                                        .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 0)
                                }
                                Text("Share on X")
                                    .font(.caption)
                                    .foregroundStyle(.white)
                            }
                        }
                        .disabled(!canShare)
                        .opacity(canShare ? 1.0 : 0.5)
                        
                        Button {
                            shareOnFacebook(text: currentFact, hashtags: shareHashtags)
                        } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.white.opacity(0.06), Color.black.opacity(0.15)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 70, height: 70)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 35)
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [Color.white.opacity(0.3), Color.white.opacity(0.06)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 1.5
                                                )
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 33)
                                                .stroke(Color.white.opacity(0.08), lineWidth: 2)
                                                .blur(radius: 1)
                                                .padding(2)
                                        )
                                        .overlay(
                                            Capsule()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                                                        startPoint: .top,
                                                        endPoint: .bottom
                                                    )
                                                )
                                                .frame(width: 54, height: 12)
                                                .rotationEffect(.degrees(-25))
                                                .offset(x: -6, y: -11)
                                                .blendMode(.screen)
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(Color.blue.opacity(0.9), lineWidth: 2)
                                        )
                                    
                                    Image(systemName: "f.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundStyle(.white)
                                        .shadow(color: Color.blue.opacity(0.6), radius: 6, x: 0, y: 0)
                                }
                                Text("Share on FB")
                                    .font(.caption)
                                    .foregroundStyle(.white)
                            }
                        }
                        .disabled(!canShare)
                        .opacity(canShare ? 1.0 : 0.5)
                    }
                    .padding(.top, 20)
                    
                    Spacer()
                }
                
                // ANIMACIJA NAGRADE
                if showRewardAnimation {
                    VStack {
                        Text("+\(funFactShareReward) BTCZ")
                            .font(.system(size: 50, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
                            )
                            .shadow(color: .yellow.opacity(0.8), radius: 20)
                            .scaleEffect(rewardScale)
                            .opacity(rewardOpacity)
                        
                        Image(systemName: "bitcoinsign.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.yellow)
                            .symbolEffect(.bounce, options: .repeating)
                    }
                    .onAppear {
                        if reduceMotion {
                            rewardScale = 1.0
                            rewardOpacity = 1.0
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                showRewardAnimation = false
                                rewardScale = 1.0
                                rewardOpacity = 0.0
                            }
                        } else {
                            withAnimation(.easeOut(duration: 1.0)) {
                                rewardScale = 1.5
                                rewardOpacity = 1.0
                            }
                            withAnimation(.easeIn(duration: 1.0).delay(1.0)) {
                                rewardOpacity = 0.0
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                showRewardAnimation = false
                                rewardScale = 1.0
                                rewardOpacity = 0.0
                            }
                        }
                    }
                }
            }
            .navigationTitle("Fun Facts")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        backPressed = true
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                            // animate then dismiss
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            dismiss()
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            backPressed = false
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title2.bold())
                            .foregroundStyle(.orange)
                            .scaleEffect(backPressed ? 0.96 : 1.0)
                            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: backPressed)
                    }
                }
            }
            .onAppear {
                loadFacts()
                
                ApiService.onServerError = { message in
                    self.serverErrorMessage = message ?? "Server is currently unavailable. Please try again later."
                    self.showServerError = true
                }
                
                ApiService.getConfig { config in
                    DispatchQueue.main.async {
                        if let hashtags = config["share_hashtags"] as? String, !hashtags.isEmpty {
                            self.shareHashtags = hashtags
                        }
                        if let reward = config["funfact_share_reward"] as? Int {
                            self.funFactShareReward = reward
                        }
                    }
                }
                
                loadShareCount()
            }
            .refreshable {
                loadFacts()
            }
            .alert("Server Error", isPresented: $showServerError) {
                Button("OK") { }
            } message: {
                Text(serverErrorMessage)
            }
        }
    }
    
    private func loadFacts() {
        isLoading = true
        ApiService.fetchFunFacts { fetchedFacts in
            DispatchQueue.main.async {
                self.facts = fetchedFacts
                self.isLoading = false
                
                if !fetchedFacts.isEmpty {
                    getRandomFact()
                }
            }
        }
    }
    
    private func getRandomFact() {
        guard !facts.isEmpty else { return }
        
        let randomFact = facts.randomElement() ?? "BTCZ is the best privacy coin!"
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.6)) {
            currentFact = randomFact
        }
    }
    
    private func loadShareCount() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastDate = lastShareDate {
            let lastDay = calendar.startOfDay(for: lastDate)
            if calendar.isDate(today, inSameDayAs: lastDay) {
                sharesToday = UserDefaults.standard.integer(forKey: "funFactSharesToday")
            } else {
                sharesToday = 0
                UserDefaults.standard.set(0, forKey: "funFactSharesToday")
                UserDefaults.standard.set(Date(), forKey: "lastFunFactShareDate")
            }
        } else {
            sharesToday = 0
        }
    }
    
    private func incrementShareCount() {
        sharesToday += 1
        UserDefaults.standard.set(sharesToday, forKey: "funFactSharesToday")
        UserDefaults.standard.set(Date(), forKey: "lastFunFactShareDate")
        
        PointsManager.shared.refreshFromServer()
        
        // Animacija nagrade
        showRewardAnimation = true
    }
    
    // NATIVE SHARE ZA FACEBOOK
    private func shareOnFacebook(text: String, hashtags: String) {
        guard canShare else { return }
        
        let shareText = "\(text)\n\(hashtags)"
        
        let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        
        activityVC.completionWithItemsHandler = { activityType, completed, returnedItems, error in
            if completed {
                incrementShareCount()
            }
        }
        
        let fbAppInstalled = UIApplication.shared.canOpenURL(URL(string: "fb://")!)
        _ = fbAppInstalled // currently informational; UIActivityViewController will handle destinations
        
        activityVC.excludedActivityTypes = [
            .addToReadingList,
            .assignToContact,
            .openInIBooks,
            .markupAsPDF,
            .print,
            .saveToCameraRoll
        ]
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    
    // NATIVE SHARE ZA X
    private func shareOnX(text: String, hashtags: String) {
        guard canShare else { return }
        
        let xAppInstalled = UIApplication.shared.canOpenURL(URL(string: "twitter://")!)
        _ = xAppInstalled
        
        let shareText = "\(text)\n\(hashtags)"
        let encodedText = shareText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let xAppURL = URL(string: "twitter://post?message=\(encodedText)")!
        let xWebURL = URL(string: "https://twitter.com/intent/tweet?text=\(encodedText)")!
        
        if UIApplication.shared.canOpenURL(xAppURL) {
            UIApplication.shared.open(xAppURL)
        } else {
            UIApplication.shared.open(xWebURL)
        }
    }
}

#Preview {
    FactsView()
}

// HomeView.swift – 100 % DELUJE! (s čudovitim daily swipe-om)
import SwiftUI
import UIKit

struct HomeView: View {
    @ObservedObject private var pointsManager = PointsManager.shared
    
    // DAILY LOGIN SWIPE
    @State private var dailyReward = 10
    @State private var timeRemaining = "24:00:00"
    @State private var dailyLoginClaimed = false
    @State private var swipeOffset: CGFloat = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                gradientBackground
                
                ScrollView {
                    VStack(spacing: 30) {
                        // MARK: - Balance
                        VStack(spacing: 12) {
                            Text("My BTCZ Balance")
                                .font(.title2)
                                .foregroundStyle(.white.opacity(0.9))
                            
                            Text("\(pointsManager.currentPoints) BTCZ")
                                .font(.system(size: 60, weight: .bold))
                                .foregroundStyle(.orange)
                                .shadow(color: .orange.opacity(0.5), radius: 10)
                        }
                        .padding(.top, 40)
                        
                        // MARK: - DAILY LOGIN SWIPE (nižje in lepše)
                        VStack(spacing: 16) {
                            Text("Daily Login Reward")
                                .font(.title2)
                                .foregroundStyle(.white.opacity(0.9))
                            
                            ZStack {
                                Capsule()
                                    .fill(Color.orange.opacity(0.2))
                                    .frame(height: 80)
                                
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Swipe to claim")
                                            .font(.headline)
                                            .foregroundStyle(.white.opacity(0.8))
                                        Text("+\(dailyReward) BTCZ")
                                            .font(.title2.bold())
                                            .foregroundStyle(.orange)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.right")
                                        .font(.title)
                                        .foregroundStyle(.orange)
                                }
                                .padding(.horizontal, 30)
                                
                                HStack {
                                    Capsule()
                                        .fill(Color.orange)
                                        .frame(width: 80, height: 80)
                                        .offset(x: swipeOffset)
                                        .gesture(
                                            DragGesture()
                                                .onChanged { value in
                                                    let maxWidth = UIScreen.main.bounds.width - 180
                                                    if value.translation.width > 0 && value.translation.width < maxWidth {
                                                        swipeOffset = value.translation.width
                                                    }
                                                }
                                                .onEnded { value in
                                                    let maxWidth = UIScreen.main.bounds.width - 180
                                                    if value.translation.width > maxWidth * 0.7 {
                                                        withAnimation(.spring()) {
                                                            swipeOffset = maxWidth
                                                        }
                                                        claimDailyLogin()
                                                    } else {
                                                        withAnimation(.spring()) {
                                                            swipeOffset = 0
                                                        }
                                                    }
                                                }
                                        )
                                        .overlay(
                                            Image(systemName: "hand.point.right.fill")
                                                .font(.system(size: 36))
                                                .foregroundStyle(.white)
                                        )
                                    Spacer()
                                }
                            }
                            .frame(height: 80)
                            .padding(.horizontal)
                            
                            if dailyLoginClaimed {
                                Text("Next reward in \(timeRemaining)")
                                    .font(.title3)
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(.bottom, 20)
                        
                        // MARK: - Grid z gumbi
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                            NavigationLink(destination: SimpleQuestionsView()) { gridButton(icon: "questionmark.circle.fill", title: "Quiz", color: .purple) }
                            NavigationLink(destination: TasksView()) { gridButton(icon: "list.bullet.circle.fill", title: "Tasks", color: .green) }
                            NavigationLink(destination: WalletView()) { gridButton(icon: "wallet.pass.fill", title: "Wallet", color: .orange) }
                            NavigationLink(destination: ClaimView()) { gridButton(icon: "dollarsign.circle.fill", title: "Claim", color: .blue) }
                            NavigationLink(destination: LeaderboardView()) { gridButton(icon: "trophy.fill", title: "Leaderboard", color: .yellow) }
                            NavigationLink(destination: ReferralView()) { gridButton(icon: "person.2.fill", title: "Referral", color: .cyan) }
                            NavigationLink(destination: FactsView()) { gridButton(icon: "lightbulb.fill", title: "Fun Facts", color: .pink) }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                loadDailyStatus()
                startTimer()
                pointsManager.syncWithServer()
            }
        }
    }
    
    // MARK: - Daily login funkcije
    private func loadDailyStatus() {
        let lastClaim = UserDefaults.standard.object(forKey: "lastDailyClaim") as? Date ?? Date.distantPast
        let today = Calendar.current.startOfDay(for: Date())
        let last = Calendar.current.startOfDay(for: lastClaim)
        
        dailyLoginClaimed = today <= last
        
        ApiService.fetchSettings { settings in
            DispatchQueue.main.async {
                self.dailyReward = settings.dailyReward
            }
        }
    }
    
    private func startTimer() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            let lastClaim = UserDefaults.standard.object(forKey: "lastDailyClaim") as? Date ?? Date.distantPast
            let nextAvailable = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: lastClaim))!
            let remaining = Int(nextAvailable.timeIntervalSinceNow)
            
            if remaining > 0 {
                let h = remaining / 3600
                let m = (remaining % 3600) / 60
                let s = remaining % 60
                timeRemaining = String(format: "%02d:%02d:%02d", h, m, s)
            } else {
                timeRemaining = "Available now!"
                dailyLoginClaimed = false
            }
        }
    }
    
    private func claimDailyLogin() {
        ApiService.completeTask(taskId: "101") { success in
            DispatchQueue.main.async {
                if success {
                    dailyLoginClaimed = true
                    UserDefaults.standard.set(Date(), forKey: "lastDailyClaim")
                    PointsManager.shared.syncWithServer()
                }
                withAnimation { swipeOffset = 0 }
            }
        }
    }
    
    // MARK: - Grid Button
    private func gridButton(icon: String, title: String, color: Color) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundStyle(color)
            Text(title)
                .font(.title3)
                .bold()
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(24)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(color.opacity(0.6), lineWidth: 3))
        .shadow(color: color.opacity(0.4), radius: 15)
    }
    
    // MARK: - Gradient Background
    private var gradientBackground: some View {
        LinearGradient(colors: [.blue.opacity(0.9), .black, .orange.opacity(0.6)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}

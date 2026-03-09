// HomeView.swift – 100 % CELOTNA – INFO SHEET Z VEČ VRSTICAMI (tekst ne gre čez ekran)
import SwiftUI
import Combine

#if DEBUG
@inline(__always) func DLog(_ message: @autoclosure () -> String) {
    print(message())
}
#else
@inline(__always) func DLog(_ message: @autoclosure () -> String) { }
#endif

struct HomeView: View {
    @ObservedObject private var pointsManager = PointsManager.shared
    @StateObject private var dailyLoginStatus = DailyLoginStatus()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var dailyReward = 10
    @State private var swipeOffset: CGFloat = 0
    @State private var quizAvailable = true
    
    @State private var showSparkles = false
    @State private var scaleAnimation = 1.0
    @State private var logoRotation: Double = 0
    @State private var showClaimPulse = false
    @State private var claimScale: CGFloat = 1.0
    
    @State private var showEndSpark = false
    
    // NAGRADE
    @State private var discordReward = 0
    @State private var telegramReward = 0
    @State private var rewardedVideoReward = 0
    
    // LINKI
    @State private var discordLink = "https://discord.gg/GfkzBHe"
    @State private var telegramLink = "https://t.me/btczofficialgroup"
    
    // STATUS CLAIM
    @State private var discordClaimed = false
    @State private var telegramClaimed = false
    
    // SHEETS
    @State private var showDiscordVerifySheet = false
    @State private var discordIDInput = ""
    @State private var showTelegramVerifySheet = false
    @State private var showRewardVideoAlert = false
    @State private var rewardVideoAlertTitle = ""
    @State private var rewardVideoAlertMessage = ""
    @State private var isAdAttemptInProgress = false
    @State private var adTryAgainInSeconds: Int = 0
    @State private var showInfoSheet = false

    @State private var showOnboarding: Bool = !UserDefaults.standard.bool(forKey: "onboardingCompleted")
    
    // PRESENTER
    @State private var presenter: UIViewController? = nil
    
    // SERVER ERROR
    @State private var showServerError = false
    @State private var serverErrorMessage = "Server is currently unavailable. Please try again later."
    
    // ANIMACIJA GUMBOV
    @State private var showGridButtons = false
    @State private var countdownTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    @StateObject private var rewardedManager = RewardedVideoManager.shared
    @State private var adPollTimer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    
    @State private var canWatchRewarded: Bool = true
    @State private var remainingRewardedViews: Int = 0
    @State private var maxRewardedViews: Int = 0
    @State private var rewardedStatusMessage: String? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundView(reduceMotion: reduceMotion)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        Spacer().frame(height: 80)  // prostor za header
                        
                        // BALANCE SEKCIJA
                        balanceSection
                        
                        // SOCIAL GUMBI
                        socialButtonsSection
                        
                        // DAILY LOGIN
                        dailySwipeSection
                        
                        // GRID
                        mainGridSection
                        
                        // REWARDED VIDEO GUMB
                        rewardedVideoButton
                            .padding(.top, 20)
                        
                        Spacer().frame(height: 100)
                    }
                }
                
                // HEADER – "i" LEVO ZGORAJ, BTCZ LOGO DESNO
                VStack {
                    HStack {
                        // LEVO: INFO "i" GUMBEK
                        Button {
                            showInfoSheet = true
                        } label: {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.cyan)
                                .padding(.leading, 20)
                        }
                        
                        Spacer()
                        
                        // DESNO: BTCZ LOGO
                        Button {
                            if let url = URL(string: "https://getbtcz.com") {
                                UIApplication.shared.open(url)
                            }
                            if !reduceMotion {
                                withAnimation(.easeInOut(duration: 0.06)) { logoRotation = 6 }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                                    withAnimation(.easeInOut(duration: 0.08)) { logoRotation = -5 }
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                                    withAnimation(.easeInOut(duration: 0.08)) { logoRotation = 3 }
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                                    withAnimation(.easeInOut(duration: 0.12)) { logoRotation = 0 }
                                }
                            }
                        } label: {
                            Image("btcz_logo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 64, height: 64)
                                .shadow(color: .yellow.opacity(0.9), radius: 14)
                                .rotationEffect(.degrees(logoRotation))
                        }
                        .padding(.trailing, 20)
                    }
                    .padding(.top, 50)
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                DLog("[HOME][APPEAR] HomeView appeared. Preparing presenter and refreshing state…")
                presenter = UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .first?.windows
                    .first { $0.isKeyWindow }?
                    .rootViewController
                DLog("[HOME][APPEAR] Presenter set? \(self.presenter != nil)")
                
                refreshEverything()
                
                DLog("[HOME][ADS] Requesting initial rewarded ad load…")
                // Ensure rewarded ad is loaded ASAP
                RewardedVideoManager.shared.loadAd()
                
                ApiService.onServerError = { message in
                    self.serverErrorMessage = message
                    self.showServerError = true
                }
                DLog("[HOME][SERVER] onServerError handler attached.")
                
                showGridButtons = true
                showSparkles = false // minimal periodic emphasis flag, no effect, just for API parity

                NotificationCenter.default.addObserver(forName: Notification.Name("OnboardingCompletedNotification"), object: nil, queue: .main) { _ in
                    self.showOnboarding = false
                }
                
                NotificationCenter.default.addObserver(forName: Notification.Name("OnboardingResetRequested"), object: nil, queue: .main) { _ in
                    // Clear local wallet and force-show onboarding after account deletion
                    UserDefaults.standard.removeObject(forKey: "savedBTCZAddress")
                    UserDefaults.standard.set(false, forKey: "onboardingCompleted")
                    self.showOnboarding = true
                }
                DLog("[HOME][OBSERVE] Onboarding observers attached.")
                
                ApiService.getRewardedVideoStatus { canWatch, remaining, max, msg in
                    self.canWatchRewarded = canWatch
                    self.remainingRewardedViews = remaining
                    self.maxRewardedViews = max
                    self.rewardedStatusMessage = msg
                    DLog("[HOME][ADS][STATUS] canWatch=\(canWatch), remaining=\(remaining), max=\(max), msg=\(msg ?? "nil")")
                }
                
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                DLog("[HOME][APP] willEnterForeground -> refreshEverything() and fetch status")
                refreshEverything()
                DLog("[APP] Will enter foreground -> refreshEverything()")
                ApiService.getRewardedVideoStatus { canWatch, remaining, max, msg in
                    self.canWatchRewarded = canWatch
                    self.remainingRewardedViews = remaining
                    self.maxRewardedViews = max
                    self.rewardedStatusMessage = msg
                }
            }
            .onReceive(countdownTimer) { _ in
                // Update countdown only when daily is claimed (we show "Next in ...")
                if dailyLoginStatus.claimed {
                    dailyLoginStatus.refresh()
                }
            }
            .onReceive(adPollTimer) { _ in
                DLog("[HOME][ADS][POLL] isAdReady=\(rewardedManager.isAdReady), isAdAttemptInProgress=\(isAdAttemptInProgress), adTryAgainInSeconds=\(adTryAgainInSeconds)")
                if !rewardedManager.isAdReady && !isAdAttemptInProgress && adTryAgainInSeconds == 0 {
                    RewardedVideoManager.shared.loadAd()
                }
            }
            .sheet(isPresented: $showDiscordVerifySheet) { discordVerifySheet }
            .sheet(isPresented: $showTelegramVerifySheet) { telegramVerifySheet }
            .sheet(isPresented: $showRewardVideoAlert) { rewardVideoAlertSheet }
            .sheet(isPresented: $showInfoSheet) { infoSheet }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView()
            }
            .alert("Server Error", isPresented: $showServerError) {
                Button("OK") { }
            } message: {
                Text(serverErrorMessage)
            }
        }
    }
    
    // BALANCE SEKCIJA
    private var balanceSection: some View {
        VStack(spacing: 12) {
            Text("My BTCZ Balance")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [.white.opacity(0.95), .white.opacity(0.75)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 2)
                .padding(.bottom, 2)
            
            Text("\(pointsManager.currentPoints)")
                .font(.system(size: 60, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [.orange, .yellow, .orange], startPoint: .leading, endPoint: .trailing)
                )
                .shadow(color: .orange.opacity(0.8), radius: 12)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .scaleEffect(scaleAnimation)
                .onChange(of: pointsManager.currentPoints) { _ in
                    guard !reduceMotion else { return }
                    withAnimation(.easeInOut(duration: 0.12)) { scaleAnimation = 1.04 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                        withAnimation(.easeOut(duration: 0.12)) { scaleAnimation = 1.0 }
                    }
                }
            
            Text("BTCZ")
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                .foregroundStyle(.orange)
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
                .clipShape(Capsule())
        }
    }
    
    // SOCIAL GUMBI
    private var socialButtonsSection: some View {
        HStack(spacing: 40) {
            // DISCORD
            Button {
                if let url = URL(string: discordLink), !discordLink.isEmpty {
                    UIApplication.shared.open(url)
                }
                if !discordClaimed {
                    showDiscordVerifySheet = true
                }
            } label: {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.06), Color.black.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)
                            .shadow(color: Color.black.opacity(0.35), radius: 14, x: 0, y: 8)
                            .shadow(color: Color.black.opacity(0.25), radius: 5, x: 0, y: 2)
                            .overlay(
                                Circle().stroke(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.3), Color.white.opacity(0.06)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ), lineWidth: 1.5
                                )
                            )
                            .overlay(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.28), Color.clear],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 52, height: 12)
                                    .rotationEffect(.degrees(-25))
                                    .offset(x: -6, y: -14)
                                    .blendMode(.screen)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.purple.opacity(0.9), lineWidth: 2)
                                    .shadow(color: Color.purple.opacity(0.5), radius: 8)
                            )
                        Image(systemName: "message.fill")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(.purple)
                            .shadow(color: Color.purple.opacity(0.5), radius: 6, x: 0, y: 2)
                    }
                    VStack(spacing: 2) {
                        Text("Discord")
                            .font(.caption)
                            .bold()
                            .foregroundStyle(.purple)
                        if !discordClaimed {
                            Text("+\(discordReward) BTCZ")
                                .font(.caption2)
                                .foregroundStyle(.purple.opacity(0.9))
                        }
                    }
                }
            }
            
            // REFRESH
            Button {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                    refreshEverything()
                }
                PointsManager.shared.syncWithServer { }
                ApiService.fetchIAPConfig(forceRefresh: true) { _ in
                    // warmed IAP config cache
                }
                DLog("[REFRESH] Manual refresh triggered")
            } label: {
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
                        .shadow(color: Color.black.opacity(0.35), radius: 16, x: 0, y: 10)
                        .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 2)
                        .overlay(
                            Circle().stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.3), Color.white.opacity(0.06)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ), lineWidth: 1.5
                            )
                        )
                        .overlay(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.28), Color.clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 60, height: 14)
                                .rotationEffect(.degrees(-25))
                                .offset(x: -8, y: -16)
                                .blendMode(.screen)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.orange.opacity(0.9), lineWidth: 2)
                                .shadow(color: Color.orange.opacity(0.6), radius: 10)
                        )
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.orange)
                        .shadow(color: Color.orange.opacity(0.5), radius: 6, x: 0, y: 2)
                }
            }
            
            // TELEGRAM
            Button {
                if let url = URL(string: telegramLink), !telegramLink.isEmpty {
                    UIApplication.shared.open(url)
                }
                if !telegramClaimed {
                    showTelegramVerifySheet = true
                }
            } label: {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.06), Color.black.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)
                            .shadow(color: Color.black.opacity(0.35), radius: 14, x: 0, y: 8)
                            .shadow(color: Color.black.opacity(0.25), radius: 5, x: 0, y: 2)
                            .overlay(
                                Circle().stroke(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.3), Color.white.opacity(0.06)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ), lineWidth: 1.5
                                )
                            )
                            .overlay(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.28), Color.clear],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 52, height: 12)
                                    .rotationEffect(.degrees(-25))
                                    .offset(x: -6, y: -14)
                                    .blendMode(.screen)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.blue.opacity(0.9), lineWidth: 2)
                                    .shadow(color: Color.blue.opacity(0.5), radius: 8)
                            )
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(.blue)
                            .shadow(color: Color.blue.opacity(0.5), radius: 6, x: 0, y: 2)
                    }
                    VStack(spacing: 2) {
                        Text("Telegram")
                            .font(.caption)
                            .bold()
                            .foregroundStyle(.blue)
                        if !telegramClaimed {
                            Text("+\(telegramReward) BTCZ")
                                .font(.caption2)
                                .foregroundStyle(.blue.opacity(0.9))
                        }
                    }
                }
            }
        }
    }
    
    // DAILY SWIPE
    private var dailySwipeSection: some View {
        VStack(spacing: 15) {
            Text("Daily Login Reward")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [.white.opacity(0.95), .white.opacity(0.75)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
            
            if dailyLoginStatus.claimed {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 70))
                        .foregroundStyle(.green)
                    Text("Claimed Today!")
                        .font(.title3.bold())
                        .foregroundStyle(.green)
                    Text("Next in \(dailyLoginStatus.timeRemaining)")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            else {
                ZStack {
                    // Original swipe control
                    ZStack(alignment: .leading) {
                        // 3D/Neo track
                        RoundedRectangle(cornerRadius: 40)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.06), Color.black.opacity(0.18)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                // Bevel edge
                                RoundedRectangle(cornerRadius: 40)
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
                                // Inner glow to mimic inset surface
                                RoundedRectangle(cornerRadius: 38)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 2)
                                    .blur(radius: 1)
                                    .padding(2)
                            )
                            .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 10)
                            .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 2)
                            .frame(height: 80)

                        // Progress fill
                        GeometryReader { proxy in
                            let totalWidth = proxy.size.width
                            let clamped = max(0, min(swipeOffset, totalWidth - 100)) // 100 ~ handle width + margins
                            ZStack(alignment: .leading) {
                                // Soft progress glow
                                RoundedRectangle(cornerRadius: 40)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.orange.opacity(0.22), Color.orange.opacity(0.08)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(0, clamped + 50), height: 80)
                                    .overlay(
                                        // Light sweep
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.12), Color.white.opacity(0.0)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                        .frame(width: max(0, clamped * 0.6))
                                        .blendMode(.screen)
                                    )
                            }
                        }

                        // Target chevron indicator on the right with neon aura
                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(Color.orange.opacity(0.12))
                                    .frame(width: 32, height: 32)
                                    .blur(radius: 0.5)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(Color.orange.opacity(0.75))
                                    .shadow(color: Color.orange.opacity(0.5), radius: 6, x: 0, y: 0)
                            }
                            .padding(.trailing, 24)
                        }
                        .frame(height: 80)

                        // Content (handle + texts) on top
                        HStack {
                            // Handle with 3D dome, specular and color ring
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.orange.opacity(0.95), Color.orange.opacity(0.75)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                    // Lift shadows
                                    .shadow(color: Color.black.opacity(0.35), radius: 16, x: 0, y: 10)
                                    .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 2)
                                    // Specular swipe
                                    .overlay(
                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color.white.opacity(0.35), Color.clear],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 64, height: 16)
                                            .rotationEffect(.degrees(-25))
                                            .offset(x: -8, y: -18)
                                            .blendMode(.screen)
                                    )
                                    // Edge ring
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.25), lineWidth: 2)
                                    )
                                    // Color ring glow
                                    .overlay(
                                        Circle()
                                            .stroke(Color.orange.opacity(0.9), lineWidth: 2)
                                            .shadow(color: Color.orange.opacity(0.6), radius: 10)
                                    )

                                Image("btcz_logo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 44, height: 44)
                                    .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
                            }
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
                                            withAnimation(.easeOut(duration: 0.2)) {
                                                swipeOffset = maxWidth
                                            }
                                            claimDailyLogin()
                                        } else {
                                            withAnimation(.easeOut(duration: 0.2)) {
                                                swipeOffset = 0
                                            }
                                        }
                                    }
                            )

                            Spacer(minLength: 16)

                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Text("Swipe to claim")
                                        .font(.headline)
                                        .foregroundStyle(.white.opacity(0.9))
                                    Image(systemName: "arrow.right")
                                        .font(.subheadline)
                                        .foregroundStyle(.orange)
                                }
                                Text("+\(dailyReward) BTCZ")
                                    .font(.title3.bold())
                                    .foregroundStyle(.orange)
                                    .shadow(color: .orange.opacity(0.4), radius: 6)
                            }
                            .padding(.leading, 20)

                            Spacer()
                        }
                        .frame(height: 80)
                        .padding(.horizontal, 10)
                    }
                    .frame(height: 80)
                    .padding(.horizontal, 30)
                    .overlay(
                        GeometryReader { geo in
                            ZStack {
                                if showEndSpark {
                                    // Spark core
                                    Circle()
                                        .fill(Color.orange)
                                        .frame(width: 10, height: 10)
                                        .shadow(color: Color.orange.opacity(0.8), radius: 8)
                                    // Spark rays
                                    ForEach(0..<6, id: \.self) { i in
                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color.orange, Color.clear],
                                                    startPoint: .center,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(width: 24, height: 3)
                                            .rotationEffect(.degrees(Double(i) * 60))
                                            .offset(x: 16)
                                            .opacity(0.9)
                                    }
                                    // Outer glow
                                    Circle()
                                        .stroke(Color.orange.opacity(0.7), lineWidth: 2)
                                        .frame(width: 36, height: 36)
                                        .blur(radius: 0.5)
                                }
                            }
                            .frame(width: geo.size.width, height: geo.size.height)
                            .position(x: geo.size.width - 44, y: geo.size.height / 2)
                        }
                    )
                    .scaleEffect(claimScale)
                    .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.65, blendDuration: 0.0), value: claimScale)

                    // Pulse overlay for success feedback
                    if showClaimPulse {
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.25))
                                .frame(width: 140, height: 140)
                                .scaleEffect(showClaimPulse ? 1.0 : 0.6)
                                .opacity(showClaimPulse ? 0.0 : 1.0)
                                .blur(radius: 0.5)
                        }
                        .transition(.opacity)
                    }
                }
            }
        }
        .padding(.vertical, 20)
    }
    
    // GRID – MANJŠI GUMBI
    private var mainGridSection: some View {
        VStack(spacing: 20) {
            // PRVA VRSTA
            HStack(spacing: 20) {
                NavigationLink("Quiz", destination: SimpleQuestionsView())
                    .disabled(!quizAvailable)
                    .buttonStyle(SmallGridButtonStyle(icon: "questionmark.circle.fill", title: "Quiz", color: .purple, disabled: !quizAvailable))
                    .opacity(showGridButtons ? 1 : 0)
                    .offset(y: showGridButtons ? 0 : 6)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: showGridButtons)
                
                NavigationLink("Tasks", destination: TasksView())
                    .buttonStyle(SmallGridButtonStyle(icon: "list.bullet.circle.fill", title: "Tasks", color: .green, disabled: false))
                    .opacity(showGridButtons ? 1 : 0)
                    .offset(y: showGridButtons ? 0 : 6)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: showGridButtons)
                
                NavigationLink("Wallet", destination: WalletView())
                    .buttonStyle(SmallGridButtonStyle(icon: "wallet.pass.fill", title: "Wallet", color: .orange, disabled: false))
                    .opacity(showGridButtons ? 1 : 0)
                    .offset(y: showGridButtons ? 0 : 6)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: showGridButtons)
            }
            
            // DRUGA VRSTA
            HStack(spacing: 20) {
                NavigationLink("Claim", destination: ClaimView())
                    .buttonStyle(SmallGridButtonStyle(icon: "dollarsign.circle.fill", title: "Claim", color: .blue, disabled: false))
                    .opacity(showGridButtons ? 1 : 0)
                    .offset(y: showGridButtons ? 0 : 6)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: showGridButtons)
                
                NavigationLink("Leaderboard", destination: LeaderboardView())
                    .buttonStyle(SmallGridButtonStyle(icon: "trophy.fill", title: "Leaderboard", color: .yellow, disabled: false))
                    .opacity(showGridButtons ? 1 : 0)
                    .offset(y: showGridButtons ? 0 : 6)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: showGridButtons)
                
                NavigationLink("Fun Facts", destination: FactsView())
                    .buttonStyle(SmallGridButtonStyle(icon: "lightbulb.fill", title: "Fun Facts", color: .pink, disabled: false))
                    .opacity(showGridButtons ? 1 : 0)
                    .offset(y: showGridButtons ? 0 : 6)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: showGridButtons)
                
                NavigationLink("Games", destination: GamesView())
                    .buttonStyle(SmallGridButtonStyle(icon: "gamecontroller.fill", title: "Games", color: .pink, disabled: false))
                    .opacity(showGridButtons ? 1 : 0)
                    .offset(y: showGridButtons ? 0 : 6)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: showGridButtons)
            }
            
            // TRETJA VRSTA – REFERRALS + PROFILE
            HStack(spacing: 20) {
                NavigationLink("Referrals", destination: ReferralView())
                    .buttonStyle(SmallGridButtonStyle(icon: "gift.fill", title: "Referrals", color: .pink, disabled: false))
                    .opacity(showGridButtons ? 1 : 0)
                    .offset(y: showGridButtons ? 0 : 6)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: showGridButtons)
                
                NavigationLink("Profile", destination: ProfileView())
                    .buttonStyle(SmallGridButtonStyle(icon: "person.circle.fill", title: "Profile", color: .cyan, disabled: false))
                    .opacity(showGridButtons ? 1 : 0)
                    .offset(y: showGridButtons ? 0 : 6)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: showGridButtons)
                
                NavigationLink("BTCZ Credits", destination: PurchaseCreditsView())
                    .buttonStyle(SmallGridButtonStyle(icon: "creditcard.fill", title: "BTCZ Credits", color: .orange, disabled: false))
                    .opacity(showGridButtons ? 1 : 0)
                    .offset(y: showGridButtons ? 0 : 6)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: showGridButtons)
            }
        }
        .padding(.horizontal, 20)
    }
    
    // REWARDED VIDEO GUMB
    private var rewardedVideoButton: some View {
        VStack(spacing: 6) {
            Button {
                DLog("[HOME][ADS][TAP] Watch video tapped. isAdReady=\(rewardedManager.isAdReady), isAdAttemptInProgress=\(isAdAttemptInProgress)")
                guard rewardedManager.isAdReady else { return }
                guard !isAdAttemptInProgress else { return }
                isAdAttemptInProgress = true
                DLog("[HOME][ADS][STATE] isAdAttemptInProgress set to true.")

                if let vc = presenter {
                    RewardedVideoManager.shared.showAd(from: vc) { success, error in
                        DispatchQueue.main.async {
                            DLog("[HOME][ADS][COMPLETE] showAd completion. success=\(success), error=\(error?.localizedDescription ?? "nil")")
                            self.isAdAttemptInProgress = false
                            if success {
                                DLog("[HOME][ADS][SUCCESS] Reward success. Triggering status refresh and reload.")
                                // Success path is handled inside RewardedVideoManager (server call + points refresh)
                                self.rewardVideoAlertTitle = "Success!"
                                self.rewardVideoAlertMessage = "Reward added!"
                                self.showRewardVideoAlert = true
                                // Return to waiting state while next ad loads
                                RewardedVideoManager.shared.loadAd()
                                ApiService.getRewardedVideoStatus { canWatch, remaining, max, msg in
                                    self.canWatchRewarded = canWatch
                                    self.remainingRewardedViews = remaining
                                    self.maxRewardedViews = max
                                    self.rewardedStatusMessage = msg
                                }
                            } else {
                                let msg = error?.localizedDescription ?? "Ad is not available right now. Please try again in a few seconds."
                                DLog("[HOME][ADS][FAIL] Reward failed. error=\(msg)")
                                self.rewardVideoAlertTitle = "Video Unavailable"
                                self.rewardVideoAlertMessage = msg
                                self.showRewardVideoAlert = true
                            }
                            self.startAdRetryCooldown(seconds: 5)
                        }
                    }
                } else {
                    self.isAdAttemptInProgress = false
                    self.rewardVideoAlertTitle = "Error"
                    self.rewardVideoAlertMessage = "Unable to present video ad. Please try again later."
                    self.showRewardVideoAlert = true
                }
            } label: {
                if isAdAttemptInProgress {
                    Text("Loading video…")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.green.opacity(0.6))
                        .foregroundStyle(.white)
                        .cornerRadius(16)
                        .padding(.horizontal, 40)
                } else if adTryAgainInSeconds > 0 {
                    Text("Please wait \(adTryAgainInSeconds)s…")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.green.opacity(0.6))
                        .foregroundStyle(.white)
                        .cornerRadius(16)
                        .padding(.horizontal, 40)
                } else if !canWatchRewarded {
                    Text(rewardedStatusMessage ?? "Daily limit reached")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.green.opacity(0.6))
                        .foregroundStyle(.white)
                        .cornerRadius(16)
                        .padding(.horizontal, 40)
                } else if !rewardedManager.isAdReady && rewardedVideoReward > 0 {
                    Text("+\(rewardedVideoReward) BTCZ video coming soon…")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.green.opacity(0.6))
                        .foregroundStyle(.white)
                        .cornerRadius(16)
                        .padding(.horizontal, 40)
                } else if !rewardedManager.isAdReady {
                    Text("Waiting for video…")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.green.opacity(0.6))
                        .foregroundStyle(.white)
                        .cornerRadius(16)
                        .padding(.horizontal, 40)
                } else {
                    Text("Watch video for +\(rewardedVideoReward) BTCZ")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.green)
                        .foregroundStyle(.white)
                        .cornerRadius(16)
                        .padding(.horizontal, 40)
                }
            }
            .disabled(isAdAttemptInProgress || adTryAgainInSeconds > 0 || !rewardedManager.isAdReady || !canWatchRewarded)

            // Subtitle showing descriptive text with current/max for today
            if maxRewardedViews > 0 {
                let current = max(0, maxRewardedViews - remainingRewardedViews)
                Text("Todays limit of videos: \(current)/\(maxRewardedViews)")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.top, 0)
    }
    
    // INFO SHEET – POLN TEKST V VEČ VRSTICAH
    // INFO SHEET – BREZ GUMBA ZA PRIVACY POLICY (ker link ne deluje)
    private var infoSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                Text("Welcome to BTCZ Awareness")
                    .font(.title.bold())
                    .foregroundStyle(
                        LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
                    )
                
                Text("This app helps spread awareness about BitcoinZ (BTCZ) – a true community privacy coin with zk-SNARKs technology and 21 billion fair supply.")
                    .font(.body)
                    .foregroundStyle(.white)
                    .lineSpacing(6)
                
                Text("How to earn BTCZ:")
                    .font(.title2.bold())
                    .foregroundStyle(.yellow)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("• Complete daily login and tasks")
                    Text("• Play fun mini-games (Clicker, Memory Match, Slots)")
                    Text("• Watch rewarded videos")
                    Text("• Invite friends with your referral code")
                    Text("• Join Discord & Telegram for extra rewards")
                    Text("• All earned BTCZ is real and withdrawable to your wallet!")
                }
                .font(.body)
                .foregroundStyle(.white.opacity(0.9))
                .lineSpacing(6)
                
                Text("Privacy Policy")
                    .font(.title3.bold())
                    .foregroundStyle(.cyan)
                    .padding(.top, 10)
                
                Text("We respect your privacy. We only store your device ID and wallet address (when connected). No personal data is collected.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineSpacing(6)
                
                // Added Privacy Policy and Terms & Conditions Buttons
                Button {
                    if let url = URL(string: "https://btczkviz.btcz.rocks/static/privacy.html") { UIApplication.shared.open(url) }
                } label: {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                        Text("Privacy Policy")
                    }
                }
                .font(.headline.bold())
                .foregroundStyle(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(colors: [.blue, .indigo], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(16)
                
                Button {
                    if let url = URL(string: "https://btczkviz.btcz.rocks/static/terms.html") { UIApplication.shared.open(url) }
                } label: {
                    HStack {
                        Image(systemName: "doc.text.fill")
                        Text("Terms & Conditions")
                    }
                }
                .font(.headline.bold())
                .foregroundStyle(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(16)
                
                Button("Close") {
                    showInfoSheet = false
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
        }
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
        .padding(40)
        .presentationBackground(.clear)
    }
    
    // DISCORD VERIFY SHEET
    private var discordVerifySheet: some View {
        VStack(spacing: 20) {
            Text("Verify Discord Join")
                .font(.title2.bold())
            Text("Enter your Discord ID to verify your join.")
            TextField("Discord ID", text: $discordIDInput)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
            Button("Verify") {
                ApiService.verifyDiscordJoin(discordID: discordIDInput) { success, message in
                    DispatchQueue.main.async {
                        if success {
                            discordClaimed = true
                            ApiService.addPoints(amount: discordReward) { ok, _, newPoints in
                                if ok, let np = newPoints { PointsManager.shared.currentPoints = np } else { pointsManager.syncWithServer() }
                            }
                        }
                    }
                }
                showDiscordVerifySheet = false
            }
            .buttonStyle(.borderedProminent)
            Button("Cancel", role: .cancel) { showDiscordVerifySheet = false }
        }
        .padding()
    }
    
    // TELEGRAM VERIFY SHEET
    private var telegramVerifySheet: some View {
        VStack(spacing: 20) {
            Text("Verify Telegram Join")
                .font(.title2.bold())
            Text("Have you joined the Telegram group?")
            Button("Verify") {
                ApiService.claimTelegramReward { success, message in
                    DispatchQueue.main.async {
                        if success {
                            telegramClaimed = true
                            ApiService.addPoints(amount: telegramReward) { ok, _, newPoints in
                                if ok, let np = newPoints { PointsManager.shared.currentPoints = np } else { pointsManager.syncWithServer() }
                            }
                        }
                    }
                }
                showTelegramVerifySheet = false
            }
            .buttonStyle(.borderedProminent)
            Button("Cancel", role: .cancel) { showTelegramVerifySheet = false }
        }
        .padding()
    }
    
    // REWARDED VIDEO ALERT SHEET
    private var rewardVideoAlertSheet: some View {
        VStack(spacing: 20) {
            Text(rewardVideoAlertTitle)
                .font(.title2.bold())
            Text(rewardVideoAlertMessage)
            Button("OK") { showRewardVideoAlert = false }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    // SMALL GRID BUTTON STYLE
    private struct SmallGridButtonStyle: ButtonStyle {
        let icon: String
        let title: String
        let color: Color
        let disabled: Bool
        
        func makeBody(configuration: Configuration) -> some View {
            let pressScale: CGFloat = configuration.isPressed ? 0.96 : 1.0
            let outerShadowOpacity: Double = disabled ? 0.0 : 0.35
            let innerGlowOpacity: Double = disabled ? 0.08 : 0.16
            let specularOpacity: Double = disabled ? 0.15 : 0.28
            let ringOpacity: Double = disabled ? 0.15 : 0.35

            return VStack(spacing: 8) {
                ZStack {
                    // Base dome circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.06),
                                    Color.black.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 70, height: 70)
                        // Outer soft shadow for lift
                        .shadow(color: Color.black.opacity(outerShadowOpacity), radius: 16, x: 0, y: 10)
                        // Crisper contact shadow for depth
                        .shadow(color: Color.black.opacity(outerShadowOpacity * 0.8), radius: 6, x: 0, y: 2)
                        // Subtle ring highlight (glass edge)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white.opacity(ringOpacity), Color.white.opacity(0.05)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        // Inner glow to push icon forward
                        .overlay(
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [Color.white.opacity(innerGlowOpacity), Color.clear],
                                        center: .center,
                                        startRadius: 2,
                                        endRadius: 36
                                    )
                                )
                                .padding(10)
                        )
                        // Specular highlight swipe
                        .overlay(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(specularOpacity), Color.white.opacity(0)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 60, height: 14)
                                .rotationEffect(.degrees(-25))
                                .offset(x: -8, y: -16)
                                .blendMode(.screen)
                        )
                        // Color ring glow
                        .overlay(
                            Circle()
                                .stroke(color.opacity(disabled ? 0.5 : 0.9), lineWidth: 2)
                                .shadow(color: color.opacity(disabled ? 0.0 : 0.45), radius: 10)
                        )

                    // Icon with slight emboss
                    ZStack {
                        // Soft outer glow of icon color
                        Image(systemName: icon)
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(color.opacity(disabled ? 0.6 : 0.95))
                            .shadow(color: color.opacity(disabled ? 0.0 : 0.5), radius: 6, x: 0, y: 2)

                        // Subtle inner shadow via overlay
                        Image(systemName: icon)
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(Color.black.opacity(0.18))
                            .offset(x: 0, y: 1)
                            .blendMode(.multiply)
                            .mask(
                                LinearGradient(
                                    colors: [Color.black, Color.clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                }
                .scaleEffect(pressScale)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)

                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(disabled ? .gray : .white)
                    .multilineTextAlignment(.center)
                    .shadow(color: Color.black.opacity(disabled ? 0.0 : 0.35), radius: 3, x: 0, y: 1)
            }
            .opacity(disabled ? 0.7 : 1.0)
        }
    }
    
    // REFRESH EVERYTHING
    private func refreshEverything() {
        DispatchQueue.global(qos: .background).async {
            pointsManager.syncWithServer {
            }
            
            ApiService.fetchSettings { reward in
                DispatchQueue.main.async {
                    self.dailyReward = reward
                    DLog("[DAILY][SETTINGS] fetched dailyReward=\(reward)")
                }
            }
            
            ApiService.isQuizCompleted { done in
                DispatchQueue.main.async {
                    self.quizAvailable = !done
                    NotificationCenter.default.post(name: Notification.Name("QuizStatusChangedNotification"), object: nil, userInfo: ["quizCompletedToday": done])
                }
            }
            
            DispatchQueue.main.async {
                self.dailyLoginStatus.refresh()
            }
            
            ApiService.getConfig { config in
                DLog("[CONFIG] raw=\(config)")
                DispatchQueue.main.async {
                    DLog("[CONFIG][PARSE] starting parse for social rewards…")
                    // Discord reward (prefer String -> Int first)
                    if let rewardStr = config["discord_reward"] as? String, let rewardInt = Int(rewardStr.trimmingCharacters(in: .whitespacesAndNewlines)) {
                        self.discordReward = rewardInt
                        DLog("[CONFIG][PARSE] discordReward(String) set to \(self.discordReward)")
                    } else if let reward = config["discord_reward"] as? Int {
                        self.discordReward = reward
                        DLog("[CONFIG][PARSE] discordReward(Int) set to \(self.discordReward)")
                    } else if let rewardD = config["discord_reward"] as? Double {
                        self.discordReward = Int(rewardD)
                        DLog("[CONFIG][PARSE] discordReward(Double) set to \(self.discordReward)")
                    } else if let num = config["discord_reward"] as? NSNumber {
                        self.discordReward = num.intValue
                        DLog("[CONFIG][PARSE] discordReward(NSNumber) set to \(self.discordReward)")
                    } else if let rewardStr = config["discordReward"] as? String, let rewardInt = Int(rewardStr.trimmingCharacters(in: .whitespacesAndNewlines)) {
                        self.discordReward = rewardInt
                        DLog("[CONFIG][PARSE] discordReward(String camelCase) set to \(self.discordReward)")
                    } else if let reward = config["discordReward"] as? Int {
                        self.discordReward = reward
                        DLog("[CONFIG][PARSE] discordReward(Int camelCase) set to \(self.discordReward)")
                    } else if let rewardD = config["discordReward"] as? Double {
                        self.discordReward = Int(rewardD)
                        DLog("[CONFIG][PARSE] discordReward(Double camelCase) set to \(self.discordReward)")
                    } else if let num = config["discordReward"] as? NSNumber {
                        self.discordReward = num.intValue
                        DLog("[CONFIG][PARSE] discordReward(NSNumber camelCase) set to \(self.discordReward)")
                    } else {
                        DLog("[CONFIG][PARSE] discordReward missing or invalid, keeping=\(self.discordReward)")
                    }
                    
                    if let link = config["discord_invite_link"] as? String {
                        self.discordLink = link
                        DLog("[CONFIG][PARSE] discordLink set to \(self.discordLink)")
                    }
                    
                    // Telegram reward (prefer String -> Int first)
                    if let rewardStr = config["telegram_reward"] as? String, let rewardInt = Int(rewardStr.trimmingCharacters(in: .whitespacesAndNewlines)) {
                        self.telegramReward = rewardInt
                        DLog("[CONFIG][PARSE] telegramReward(String) set to \(self.telegramReward)")
                    } else if let reward = config["telegram_reward"] as? Int {
                        self.telegramReward = reward
                        DLog("[CONFIG][PARSE] telegramReward(Int) set to \(self.telegramReward)")
                    } else if let rewardD = config["telegram_reward"] as? Double {
                        self.telegramReward = Int(rewardD)
                        DLog("[CONFIG][PARSE] telegramReward(Double) set to \(self.telegramReward)")
                    } else if let num = config["telegram_reward"] as? NSNumber {
                        self.telegramReward = num.intValue
                        DLog("[CONFIG][PARSE] telegramReward(NSNumber) set to \(self.telegramReward)")
                    } else if let rewardStr = config["telegramReward"] as? String, let rewardInt = Int(rewardStr.trimmingCharacters(in: .whitespacesAndNewlines)) {
                        self.telegramReward = rewardInt
                        DLog("[CONFIG][PARSE] telegramReward(String camelCase) set to \(self.telegramReward)")
                    } else if let reward = config["telegramReward"] as? Int {
                        self.telegramReward = reward
                        DLog("[CONFIG][PARSE] telegramReward(Int camelCase) set to \(self.telegramReward)")
                    } else if let rewardD = config["telegramReward"] as? Double {
                        self.telegramReward = Int(rewardD)
                        DLog("[CONFIG][PARSE] telegramReward(Double camelCase) set to \(self.telegramReward)")
                    } else if let num = config["telegramReward"] as? NSNumber {
                        self.telegramReward = num.intValue
                        DLog("[CONFIG][PARSE] telegramReward(NSNumber camelCase) set to \(self.telegramReward)")
                    } else {
                        DLog("[CONFIG][PARSE][WARN] telegram reward key not found or invalid. Keys=\(config.keys)")
                    }
                    if let link = config["telegram_invite_link"] as? String {
                        self.telegramLink = link
                        DLog("[CONFIG][PARSE] telegramLink set to \(self.telegramLink)")
                    }
                    
                    if let reward = config["rewarded_video_reward"] as? Int {
                        DLog("[CONFIG] rewarded_video_reward (Int)=\(reward)")
                        self.rewardedVideoReward = reward
                    } else if let rewardStr = config["rewarded_video_reward"] as? String, let rewardInt = Int(rewardStr) {
                        DLog("[CONFIG] rewarded_video_reward (String)->Int=\(rewardInt)")
                        self.rewardedVideoReward = rewardInt
                    } else {
                        DLog("[CONFIG] rewarded_video_reward missing or invalid, keeping=\(self.rewardedVideoReward)")
                    }
                    
                    DLog("[CONFIG][SUMMARY] discordReward=\(self.discordReward), telegramReward=\(self.telegramReward), rewardedVideoReward=\(self.rewardedVideoReward)")
                }
            }
        }
    }
    
    // CLAIM DAILY LOGIN
    private func claimDailyLogin() {
        DLog("[DAILY][CLAIM] user initiated claimDailyLogin() with dailyReward=\(dailyReward), currentPoints=\(PointsManager.shared.currentPoints)")
        ApiService.completeTask(taskId: "101") { success in
            DispatchQueue.main.async {
                DLog("[DAILY][CLAIM] completeTask(101) returned success=\(success)")
                if success {
                    UserDefaults.standard.set(Date(), forKey: "lastDailyClaim")
                    dailyLoginStatus.refresh()
                    DLog("[DAILY][CLAIM] after refresh: claimed=\(dailyLoginStatus.claimed), next=\(String(describing: Mirror(reflecting: dailyLoginStatus).descendant("nextAvailableAt") as? Date)), points(before sync)=\(PointsManager.shared.currentPoints)")
                    if !reduceMotion {
                        // Brief scale bounce
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.6)) {
                            claimScale = 1.06
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.7)) {
                                claimScale = 1.0
                            }
                        }
                        // Pulse effect
                        showClaimPulse = true
                        withAnimation(.easeOut(duration: 0.5)) {
                            // fade out pulse overlay
                            showClaimPulse = false
                        }
                        // Optional light haptic feedback
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                        
                        // Mini spark at the end
                        withAnimation(.easeOut(duration: 0.25)) {
                            showEndSpark = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            withAnimation(.easeOut(duration: 0.25)) {
                                showEndSpark = false
                            }
                        }
                    }
                    DLog("[DAILY][CLAIM] syncing points with server…")
                    pointsManager.syncWithServer()
                    DLog("[DAILY][CLAIM] syncWithServer requested. currentPoints(now)=\(PointsManager.shared.currentPoints)")
                    NotificationCenter.default.post(name: Notification.Name("DailyLoginClaimedNotification"), object: nil)
                }
                swipeOffset = 0
            }
        }
    }
    
    private func startAdRetryCooldown(seconds: Int) {
        DLog("[HOME][ADS][COOLDOWN] Starting cooldown for \(seconds)s")
        adTryAgainInSeconds = seconds
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            DLog("[HOME][ADS][COOLDOWN] remaining=\(adTryAgainInSeconds)")
            if adTryAgainInSeconds > 0 {
                adTryAgainInSeconds -= 1
            } else {
                timer.invalidate()
            }
        }
    }
}

private struct BackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme
    let reduceMotion: Bool
    @State private var animSeed = UUID()

    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [Color.black, Color.indigo.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Aurora bands
            auroraBand(angle: -22, yOffset: -120, color: .purple)
            auroraBand(angle: -8, yOffset: 20, color: .pink)
            auroraBand(angle: 16, yOffset: 180, color: .blue)

            // Subtle glass layers for depth
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 40)
                    .fill(.ultraThinMaterial)
                    .frame(width: 220 + CGFloat(i) * 40, height: 90 + CGFloat(i) * 20)
                    .rotationEffect(.degrees(Double(-10 + i * 7)))
                    .offset(x: CGFloat(-140 + i * 120), y: CGFloat(-220 + i * 160))
                    .opacity(0.10)
                    .blur(radius: 1.5)
                    .modifier(DriftAnimation(enabled: !reduceMotion, speed: 10 + Double(i) * 4, amplitude: 10 + CGFloat(i) * 6))
            }

            // Particles
            ForEach(0..<10, id: \.self) { i in
                Circle()
                    .fill(
                        RadialGradient(colors: [Color.orange.opacity(0.22), .clear], center: .center, startRadius: 0, endRadius: 44)
                    )
                    .frame(width: 90, height: 90)
                    .opacity(0.5)
                    .modifier(ParticleDrift(index: i, enabled: !reduceMotion))
            }
        }
        .onAppear { animSeed = UUID() }
    }

    // MARK: - Aurora helper
    @ViewBuilder
    private func auroraBand(angle: Double, yOffset: CGFloat, color: Color) -> some View {
        LinearGradient(
            colors: [color.opacity(0.18), .clear],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(height: 260)
        .rotationEffect(.degrees(angle))
        .offset(x: 0, y: yOffset)
        .blendMode(.screen)
        .modifier(SlowOscillation(enabled: !reduceMotion, duration: 12, xAmp: 60, yAmp: 16))
    }
}

// MARK: - Animation modifiers
private struct SlowOscillation: ViewModifier {
    let enabled: Bool
    let duration: Double
    let xAmp: CGFloat
    let yAmp: CGFloat
    @State private var t: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: enabled ? CGFloat(sin(Double(t))) * xAmp : 0, y: enabled ? CGFloat(cos(Double(t * 0.8))) * yAmp : 0)
            .onAppear {
                guard enabled else { return }
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: true)) {
                    t = .pi * 2
                }
            }
    }
}

private struct DriftAnimation: ViewModifier {
    let enabled: Bool
    let speed: Double
    let amplitude: CGFloat
    @State private var t: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: enabled ? CGFloat(sin(Double(t))) * amplitude : 0, y: enabled ? CGFloat(cos(Double(t * 0.7))) * amplitude : 0)
            .onAppear {
                guard enabled else { return }
                withAnimation(.linear(duration: speed).repeatForever(autoreverses: true)) {
                    t = .pi * 2
                }
            }
    }
}

private struct ParticleDrift: ViewModifier {
    let index: Int
    let enabled: Bool
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: xPos, y: yPos)
            .scaleEffect(scale)
            .onAppear {
                guard enabled else { return }
                withAnimation(.easeInOut(duration: 8 + Double(index) * 0.6).repeatForever(autoreverses: true)) {
                    phase = .pi * 2
                }
            }
    }

    private var xPos: CGFloat {
        let base = CGFloat(-180 + (index * 36))
        return base + (enabled ? CGFloat(sin(Double(phase + CGFloat(index)))) * 24 : 0)
    }
    private var yPos: CGFloat {
        let base = CGFloat(-360 + (index * 72) % 480)
        return base + (enabled ? CGFloat(cos(Double(phase * 0.9 + CGFloat(index)))) * 20 : 0)
    }
    private var scale: CGFloat {
        enabled ? 0.85 + CGFloat((index % 3)) * 0.06 : 0.9
    }
}

#Preview {
    HomeView()
}


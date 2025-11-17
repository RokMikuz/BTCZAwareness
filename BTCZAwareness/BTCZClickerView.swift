// BTCZClickerView.swift – 100 % CELOTNA – Z ATRAKTIVNIM BTCZ LOGOM + ANIMACIJAMI + SINHRONIZACIJA
import SwiftUI
import Combine

struct BTCZClickerView: View {
    @Environment(\.dismiss) private var dismiss
    
    // LOKALNI BALANCE MED IGRANJEM
    @State private var localBalance: Int = 0
    @State private var clickPower: Int = 1
    @State private var autoMinerRate: Int = UserDefaults.standard.integer(forKey: "autoMinerRate") ?? 0
    @State private var showRewardAnimation = false
    @State private var rewardText = ""
    @State private var sparklePositions: [CGPoint] = []
    
    // INACTIVITY HINT (simple)
    @State private var showSimpleHint: Bool = false
    @State private var lastInteraction: Date = Date()
    
    // DAILY CONTROL & CAPS
    @State private var lastPlayDate: Date? = UserDefaults.standard.object(forKey: "clickerLastPlayDate") as? Date
    @State private var dailyEarned: Int = UserDefaults.standard.integer(forKey: "clickerDailyEarned")
    private let dailyCap: Int = 500
    @State private var clickCountInSession: Int = 0
    @State private var lastBoostDate: Date? = UserDefaults.standard.object(forKey: "clickerLastBoostDate") as? Date
    private let boostCooldownSeconds: Int = 120

    // AUTOMINER CAP
    private let autoMinerCap: Int = 3
    
    // 2 MIN OMEJITVA – TIMESTAMP
    private let maxPlayTimeSeconds = 120
    @State private var sessionStartTime: Date? = UserDefaults.standard.object(forKey: "clickerSessionStart") as? Date
    @State private var isTimeUp = false
    
    // New state variable for back button press animation
    @State private var backPressed = false
    @State private var pendingSyncWorkItem: DispatchWorkItem? = nil
    @State private var didSyncGameOver: Bool = false
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var remainingTimeString: String {
        guard let start = sessionStartTime else { return "2:00" }
        let elapsed = Int(Date().timeIntervalSince(start))
        let remaining = max(0, maxPlayTimeSeconds - elapsed)
        let minutes = remaining / 60
        let seconds = remaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // DINAMIČNA VELIKOST FONTA ZA BALANCE
    private var balanceFontSize: CGFloat {
        if localBalance < 1000 {
            return 50
        } else if localBalance < 10000 {
            return 45
        } else if localBalance < 100000 {
            return 40
        } else {
            return 35
        }
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.indigo.opacity(0.9), .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 40) {
                        // ČASOVNIK
                        if isTimeUp {
                            Text("Daily play limit reached!\nCome back tomorrow")
                                .font(.title2)
                                .foregroundStyle(.red.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding()
                        } else {
                            Text("Time left today: \(remainingTimeString)")
                                .font(.title2.bold())
                                .foregroundStyle(.orange)
                                .padding()
                        }
                        
                        // BALANCE
                        Text("\(localBalance) BTCZ")
                            .font(.system(size: balanceFontSize, weight: .bold))
                            .foregroundStyle(.green)
                            .shadow(color: .green.opacity(0.8), radius: 10)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        
                        // TAP BUTTON – BTCZ LOGO + ANIMACIJE
                        Button {
                            guard !isTimeUp else { return }
                            
                            lastInteraction = Date()
                            showSimpleHint = false
                            
                            if sessionStartTime == nil {
                                sessionStartTime = Date()
                                UserDefaults.standard.set(sessionStartTime, forKey: "clickerSessionStart")
                                UserDefaults.standard.set(Date(), forKey: "clickerLastPlayDate")
                                lastPlayDate = Date()
                            }
                            
                            // Gambling reward logic
                            clickCountInSession += 1
                            let roll = Double.random(in: 0...1)
                            var gain = 0
                            if roll < 0.70 {
                                gain = clickPower
                            } else if roll < 0.95 {
                                gain = 0
                            } else {
                                gain = clickPower * 3
                            }
                            
                            if clickCountInSession > 150 {
                                gain = Int(Double(gain) * 0.5)
                            }
                            
                            let remainingCap = max(0, dailyCap - dailyEarned)
                            if remainingCap <= 0 {
                                isTimeUp = true
                                rewardText = "+0"
                                showRewardAnimation = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { showRewardAnimation = false }
                                syncOnGameOverOnce()
                                return
                            }
                            if gain > remainingCap { gain = remainingCap }
                            
                            localBalance += gain
                            rewardText = "+\(gain)"
                            showRewardAnimation = true
                            
                            addSparkles()
                            
                            dailyEarned += gain
                            UserDefaults.standard.set(dailyEarned, forKey: "clickerDailyEarned")

                            if gain > 0 {
                                ApiService.addPoints(amount: gain) { ok, _, newPoints in
                                    if ok, let np = newPoints { PointsManager.shared.currentPoints = np }
                                }
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                showRewardAnimation = false
                            }
                            
                            if dailyEarned >= dailyCap {
                                isTimeUp = true
                                syncOnGameOverOnce()
                            }
                        } label: {
                            ZStack {
                                Image("btcz_logo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 200, height: 200)
                                    .shadow(color: .yellow.opacity(0.8), radius: 20)
                                    .scaleEffect(showRewardAnimation ? 1.15 : 1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showRewardAnimation)
                                    .frame(maxWidth: .infinity) // keep centered horizontally
                                    .contentShape(Rectangle())
                                    .overlay(
                                        Group {
                                            if showRewardAnimation {
                                                Text(rewardText)
                                                    .font(.system(size: 50, weight: .bold))
                                                    .foregroundStyle(.yellow)
                                                    .shadow(color: .black, radius: 5)
                                                    .offset(y: -120)
                                                    .opacity(showRewardAnimation ? 1.0 : 0.0)
                                                    .scaleEffect(showRewardAnimation ? 1.5 : 1.0)
                                                    .animation(.easeOut(duration: 1.0), value: showRewardAnimation)
                                                    .multilineTextAlignment(.center)
                                                    .fixedSize()
                                            }
                                            if showSimpleHint && !isTimeUp {
                                                Text("Tap here to mine")
                                                    .font(.caption.bold())
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 6)
                                                    .background(.thinMaterial)
                                                    .cornerRadius(12)
                                                    .foregroundStyle(.yellow)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .stroke(Color.yellow.opacity(0.6), lineWidth: 1)
                                                    )
                                                    .offset(y: 120)
                                                    .transition(.opacity)
                                                    .multilineTextAlignment(.center)
                                                    .fixedSize()
                                            }
                                        }
                                    )
                            }
                            .frame(maxWidth: .infinity)
                            .frame(width: 220, height: 220)
                        }
                        .frame(maxWidth: .infinity)
                        .disabled(isTimeUp)
                        
                        // SPARKLE ANIMACIJA
                        ZStack {
                            ForEach(sparklePositions, id: \.self) { position in
                                Image(systemName: "sparkles")
                                    .font(.system(size: 30))
                                    .foregroundStyle(.yellow)
                                    .position(position)
                                    .opacity(0.8)
                                    .scaleEffect(0)
                                    .animation(
                                        .easeOut(duration: 1.0)
                                        .delay(0.2),
                                        value: UUID()
                                    )
                            }
                        }
                        .padding(.bottom, 120) // space for fixed shop
                        
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 20)
                }
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .safeAreaInset(edge: .bottom) {
                // Fixed bottom shop
                VStack(spacing: 20) {
                    ShopItem(
                        title: "Double Click Power",
                        cost: 400,
                        action: {
                            if localBalance >= 400 && !isTimeUp {
                                localBalance -= 400
                                ApiService.addPoints(amount: -400) { _, _, _ in }
                                clickPower *= 2
                            }
                        },
                        disabled: localBalance < 400 || isTimeUp
                    )
                    
                    ShopItem(
                        title: "Auto Miner (+1/sec)",
                        cost: 600,
                        action: {
                            if localBalance >= 600 && !isTimeUp {
                                localBalance -= 600
                                ApiService.addPoints(amount: -600) { _, _, _ in }
                                autoMinerRate = min(autoMinerRate + 1, autoMinerCap)
                                UserDefaults.standard.set(autoMinerRate, forKey: "autoMinerRate")
                            }
                        },
                        disabled: localBalance < 600 || isTimeUp || autoMinerRate >= autoMinerCap
                    )
                    
                    ShopItem(
                        title: "Boost x2 (30s)",
                        cost: 200,
                        action: {
                            let now = Date()
                            let canUseBoost = (lastBoostDate == nil) || (now.timeIntervalSince(lastBoostDate!) >= Double(boostCooldownSeconds))
                            if localBalance >= 200 && !isTimeUp && canUseBoost {
                                localBalance -= 200
                                ApiService.addPoints(amount: -200) { _, _, _ in }
                                lastBoostDate = now
                                UserDefaults.standard.set(now, forKey: "clickerLastBoostDate")
                                let original = clickPower
                                clickPower *= 2
                                DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                                    clickPower = original
                                }
                            }
                        },
                        disabled: localBalance < 200 || isTimeUp || !((lastBoostDate == nil) || (Date().timeIntervalSince(lastBoostDate!) >= Double(boostCooldownSeconds)))
                    )
                }
                .padding(.horizontal, 40)
                .padding(.top, 10)
                .padding(.bottom, 16)
                .background(.ultraThinMaterial)
            }
            .navigationTitle("BTCZ Clicker")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        backPressed = true
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                            backPressed = false
                            print("[Clicker] Back pressed – leaving ClickerView to previous screen (likely HomeView)")
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
            .onReceive(timer) { _ in
                guard let start = sessionStartTime else { return }
                
                let elapsed = Int(Date().timeIntervalSince(start))
                if elapsed >= maxPlayTimeSeconds {
                    isTimeUp = true
                    UserDefaults.standard.removeObject(forKey: "clickerSessionStart")
                    syncOnGameOverOnce()
                }
                
                if autoMinerRate > 0 && !isTimeUp {
                    let remainingCap = max(0, dailyCap - dailyEarned)
                    if remainingCap <= 0 {
                        isTimeUp = true
                        syncOnGameOverOnce()
                    } else {
                        let gain = min(autoMinerRate, remainingCap)
                        localBalance += gain
                        dailyEarned += gain
                        UserDefaults.standard.set(dailyEarned, forKey: "clickerDailyEarned")

                        if gain > 0 {
                            ApiService.addPoints(amount: gain) { ok, _, newPoints in
                                if ok, let np = newPoints { PointsManager.shared.currentPoints = np }
                            }
                        }
                        
                        if dailyEarned >= dailyCap {
                            isTimeUp = true
                            syncOnGameOverOnce()
                        }
                    }
                }
                
                let idle = Date().timeIntervalSince(lastInteraction)
                if idle > 5 && !isTimeUp {
                    showSimpleHint = true
                } else if idle <= 5 {
                    showSimpleHint = false
                }
            }
            .onAppear {
                lastInteraction = Date()
                
                PointsManager.shared.syncWithServer {
                    DispatchQueue.main.async {
                        self.localBalance = PointsManager.shared.currentPoints
                    }
                }
                
                if let start = sessionStartTime {
                    let elapsed = Int(Date().timeIntervalSince(start))
                    if elapsed >= maxPlayTimeSeconds {
                        isTimeUp = true
                        UserDefaults.standard.removeObject(forKey: "clickerSessionStart")
                    }
                }
                
                // One session per day enforcement + daily reset
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                if let last = lastPlayDate {
                    let lastDay = calendar.startOfDay(for: last)
                    if calendar.isDate(today, inSameDayAs: lastDay) {
                        // already played today
                        if sessionStartTime == nil { isTimeUp = true }
                    } else {
                        // new day: reset daily earned and session flags
                        dailyEarned = 0
                        UserDefaults.standard.set(0, forKey: "clickerDailyEarned")
                        isTimeUp = false
                        sessionStartTime = nil
                        UserDefaults.standard.removeObject(forKey: "clickerSessionStart")
                    }
                } else {
                    // first ever play, ensure counters are reset
                    dailyEarned = 0
                    UserDefaults.standard.set(0, forKey: "clickerDailyEarned")
                }
            }
            .onDisappear {
                syncAndDismiss()
            }
        }
    }
    
    private func addSparkles() {
        let center = CGPoint(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2 - 100)
        for _ in 0..<15 {
            let angle = Double.random(in: 0..<2 * .pi)
            let distance = Double.random(in: 80...180)
            let x = center.x + distance * cos(angle)
            let y = center.y + distance * sin(angle)
            sparklePositions.append(CGPoint(x: x, y: y))
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            sparklePositions = []
        }
    }
    
    private func syncAndDismiss() {
        print("[Clicker] syncAndDismiss called with balance=\(localBalance)")
        PointsManager.shared.syncWithServer()
        dismiss()
    }
    
    private func syncOnGameOverOnce() {
        print("[Clicker] syncOnGameOverOnce called; didSyncGameOver=\(didSyncGameOver)")
        guard !didSyncGameOver else { return }
        didSyncGameOver = true
        PointsManager.shared.syncWithServer()
    }
}

// SHOP ITEM
struct ShopItem: View {
    let title: String
    let cost: Int
    let action: () -> Void
    let disabled: Bool
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .allowsTightening(true)
                    .truncationMode(.tail)
                
                Spacer()
                
                Text("\(cost) BTCZ")
                    .font(.headline)
                    .foregroundStyle(.yellow)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding()
            .background(.black.opacity(0.6))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.orange.opacity(0.8), lineWidth: 2)
            )
        }
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1.0)
    }
}

#Preview {
    BTCZClickerView()
}


// MemoryMatchView.swift – 100 % CELOTNA – Z ZAKLEPANJEM PO ZADNJEM NIVOJU + ODKEPANJE ZA 50 BTCZ + KRAJŠI ČASI
import SwiftUI
import Combine

struct MemoryMatchView: View {
    @Environment(\.dismiss) private var dismiss
    
    // NIVOJI – KRAJŠI ČASI
    let levels = [
        Level(columns: 4, rows: 4, pairs: 8, timeLimit: 180),   // 3 min
        Level(columns: 4, rows: 5, pairs: 10, timeLimit: 240),  // 4 min
        Level(columns: 5, rows: 5, pairs: 12, timeLimit: 300),  // 5 min
        Level(columns: 5, rows: 6, pairs: 15, timeLimit: 360)   // 6 min – zadnji
    ]
    
    @State private var currentLevelIndex = 0
    @State private var cards: [MemoryCard] = []
    @State private var selectedCards: [Int] = []
    @State private var matchedPairs = 0
    @State private var moves = 0
    @State private var showWinAnimation = false
    @State private var showAllLevelsCompleted = false

    @State private var backPressed = false
    
    // NAGRADA
    private let rewardPerLevel = 10
    // Unlock via rewarded video once per day
    private let maxUnlocksPerDay = 1
    
    // OMEJITVE
    @State private var unlocksToday = 0
    @State private var lastUnlockDate: Date? = UserDefaults.standard.object(forKey: "memoryMatchLastUnlock") as? Date
    
    // ČASOVNA OMEJITVA
    @State private var sessionStartTime: Date? = nil
    @State private var isTimeUp = false
    @State private var remainingTime = 180
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var currentLevel: Level {
        levels[currentLevelIndex]
    }
    
    var remainingTimeString: String {
        let minutes = remainingTime / 60
        let seconds = remainingTime % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var canUnlock: Bool {
        unlocksToday < maxUnlocksPerDay
    }
    
    var isLastLevelCompleted: Bool {
        currentLevelIndex == levels.count - 1 && matchedPairs == currentLevel.pairs
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.indigo.opacity(0.9), .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // ČASOVNIK
                if isTimeUp {
                    VStack(spacing: 20) {
                        Text("Time's up!")
                            .font(.title)
                            .foregroundStyle(.red.opacity(0.8))
                        
                        if canUnlock {
                            Button("Watch Ad to Unlock (\(unlocksToday)/\(maxUnlocksPerDay))") {
                                unlockGame()
                            }
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                            .padding()
                            .background(.purple.opacity(0.8))
                            .cornerRadius(16)
                            .padding(.horizontal, 40)
                        } else {
                            Text("No more unlocks today")
                                .font(.title2)
                                .foregroundStyle(.red.opacity(0.8))
                        }
                    }
                } else {
                    Text("Time left: \(remainingTimeString)")
                        .font(.title2.bold())
                        .foregroundStyle(.orange)
                }
                
                // STATUS
                HStack {
                    Text("Moves: \(moves)")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Text("Pairs: \(matchedPairs)/\(currentLevel.pairs)")
                        .font(.title2.bold())
                        .foregroundStyle(.green)
                }
                .padding(.horizontal)
                
                // GRID KARTIC
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 15), count: currentLevel.columns), spacing: 15) {
                    ForEach(cards.indices, id: \.self) { index in
                        MemoryCardView(
                            card: cards[index],
                            isFlipped: selectedCards.contains(index) || cards[index].isMatched,
                            onTap: {
                                cardTapped(index)
                            }
                        )
                        .disabled(isTimeUp || isLastLevelCompleted)
                    }
                }
                .padding(.horizontal, 20)
                
                // STATUS PO ZADNJEM NIVOJU
                if isLastLevelCompleted {
                    VStack(spacing: 20) {
                        Text("All levels completed today! 🎉")
                            .font(.title)
                            .foregroundStyle(.yellow)
                            .shadow(color: .yellow.opacity(0.8), radius: 20)
                        
                        Text("Come back tomorrow for new challenges")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.8))
                        
                        if canUnlock {
                            Button("Watch Ad to Unlock (\(unlocksToday)/\(maxUnlocksPerDay))") {
                                unlockGame()
                            }
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                            .padding()
                            .background(.purple.opacity(0.8))
                            .cornerRadius(16)
                            .padding(.horizontal, 40)
                        }
                    }
                }
                
                Spacer()
            }
            
            // WIN ANIMACIJA ZA NIVO
            if showWinAnimation {
                VStack {
                    Text("Level \(currentLevelIndex + 1) Completed!")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.yellow)
                        .shadow(color: .yellow.opacity(0.8), radius: 20)
                    
                    Text("+\(rewardPerLevel) BTCZ")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundStyle(.green)
                        .shadow(color: .green.opacity(0.8), radius: 20)
                        .scaleEffect(showWinAnimation ? 1.5 : 1.0)
                        .animation(.easeOut(duration: 1.0), value: showWinAnimation)
                }
                .transition(.scale)
            }
        }
        .onAppear {
            setupGame()
            checkUnlocksToday()
        }
        .onReceive(timer) { _ in
            updateTimer()
        }
        .navigationTitle("Memory Match - Level \(currentLevelIndex + 1)")
        .navigationBarTitleDisplayMode(.inline)
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
    
    private func setupGame() {
        var newCards: [MemoryCard] = []
        let emojis = ["🪙", "💰", "💎", "🔑", "🎰", "🚀", "🌟", "🔥", "⭐", "💎", "🔔", "🎲", "🃏", "🎯", "🏆"]
        
        for i in 0..<currentLevel.pairs {
            let emoji = emojis[i % emojis.count]
            newCards.append(MemoryCard(emoji: emoji))
            newCards.append(MemoryCard(emoji: emoji))
        }
        
        cards = newCards.shuffled()
        matchedPairs = 0
        moves = 0
        selectedCards = []
        
        sessionStartTime = Date()
        remainingTime = currentLevel.timeLimit
        isTimeUp = false
    }
    
    private func cardTapped(_ index: Int) {
        guard selectedCards.count < 2 && !selectedCards.contains(index) && !cards[index].isMatched && !isTimeUp else { return }
        
        selectedCards.append(index)
        moves += 1
        
        if selectedCards.count == 2 {
            let first = selectedCards[0]
            let second = selectedCards[1]
            
            if cards[first].emoji == cards[second].emoji {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    cards[first].isMatched = true
                    cards[second].isMatched = true
                    matchedPairs += 1
                    selectedCards = []
                    
                    if matchedPairs == currentLevel.pairs {
                        winLevel()
                    }
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    selectedCards = []
                }
            }
        }
    }
    
    private func winLevel() {
        showWinAnimation = true
        
        PointsManager.shared.currentPoints += rewardPerLevel
        PointsManager.shared.saveToServer()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showWinAnimation = false
            
            if currentLevelIndex < levels.count - 1 {
                currentLevelIndex += 1
                setupGame()
            }
            // Zadnji nivo – zakleni za dan (razen če odklene)
        }
    }
    
    private func unlockGame() {
        guard canUnlock else { return }
        // Present rewarded ad to unlock another run
        if let presenter = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController {
            RewardedVideoManager.shared.showAd(from: presenter) { success, error in
                DispatchQueue.main.async {
                    if success {
                        // Count daily unlock
                        unlocksToday += 1
                        UserDefaults.standard.set(unlocksToday, forKey: "memoryMatchUnlocksToday")
                        UserDefaults.standard.set(Date(), forKey: "memoryMatchLastUnlock")
                        // Reset timer and game state to allow another cycle
                        isTimeUp = false
                        sessionStartTime = Date()
                        remainingTime = currentLevel.timeLimit
                        setupGame()
                    } else {
                        print("[MemoryMatch] Rewarded ad unlock failed: \(error?.localizedDescription ?? "unknown error")")
                    }
                }
            }
        } else {
            print("[MemoryMatch] Unable to find presenter for rewarded ad")
        }
    }
    
    private func updateTimer() {
        guard let start = sessionStartTime else { return }
        
        let elapsed = Int(Date().timeIntervalSince(start))
        remainingTime = max(0, currentLevel.timeLimit - elapsed)
        
        if remainingTime <= 0 {
            isTimeUp = true
        }
    }
    
    private func checkUnlocksToday() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastDate = lastUnlockDate {
            let lastDay = calendar.startOfDay(for: lastDate)
            if calendar.isDate(today, inSameDayAs: lastDay) {
                unlocksToday = UserDefaults.standard.integer(forKey: "memoryMatchUnlocksToday")
            } else {
                unlocksToday = 0
                UserDefaults.standard.set(0, forKey: "memoryMatchUnlocksToday")
            }
        } else {
            unlocksToday = 0
        }
    }
}

// LEVEL CONFIG
struct Level {
    let columns: Int
    let rows: Int
    let pairs: Int
    let timeLimit: Int  // v sekundah
}

// MEMORY CARD MODEL
struct MemoryCard: Identifiable {
    let id = UUID()
    let emoji: String
    var isMatched = false
}

// MEMORY CARD VIEW – FLIP + SCALE ANIMACIJA
struct MemoryCardView: View {
    let card: MemoryCard
    let isFlipped: Bool
    let onTap: () -> Void
    
    var body: some View {
        ZStack {
            if isFlipped {
                Text(card.emoji)
                    .font(.system(size: 50))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.yellow.opacity(0.9))
                    .cornerRadius(12)
                    .shadow(radius: 8)
                    .scaleEffect(isFlipped ? 1.1 : 1.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isFlipped)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.orange.opacity(0.8), lineWidth: 3)
                    )
                    .shadow(radius: 10)
                
                Image(systemName: "questionmark")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.orange)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .rotation3DEffect(
            .degrees(isFlipped ? 180 : 0),
            axis: (x: 0, y: 1, z: 0)
        )
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isFlipped)
        .onTapGesture {
            onTap()
        }
    }
}

#Preview {
    MemoryMatchView()
}

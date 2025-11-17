// SimpleQuestionsView.swift – 100 % DELUJE!
import SwiftUI

struct SimpleQuestionsView: View {
    @State private var currentQuestion = 0
    @State private var score = 0
    @State private var showResult = false
    @State private var showPenalty = false
    @State private var showConfirmation = false
    @State private var quizCompleted = UserDefaults.standard.bool(forKey: "mainQuizCompleted")
    @State private var cooldownActive = false
    @State private var shuffledQuestions: [Question] = []
    @State private var isSubmitting = false
    
    private let cooldownKey = "quizCooldownTimestamp"
    private let hasWallet = !(UserDefaults.standard.string(forKey: "savedBTCZAddress")?.isEmpty ?? true)
    
    private let rawQuestions = [
        Question(text: "What is the maximum supply of BTCZ?", options: ["21 million", "21 billion", "Unlimited"], correctAnswer: "21 billion"),
        Question(text: "Which algorithm does BTCZ use?", options: ["SHA-256", "Equihash", "Scrypt"], correctAnswer: "Equihash"),
        Question(text: "BTCZ is a fork of which coin?", options: ["Bitcoin", "Zcash", "Monero"], correctAnswer: "Zcash"),
        Question(text: "What enables privacy in BTCZ?", options: ["Ring signatures", "zk-SNARKs", "Mimblewimble"], correctAnswer: "zk-SNARKs"),
        Question(text: "When was BTCZ launched?", options: ["2015", "2016", "2017", "2018", "2019"], correctAnswer: "2017"),
        Question(text: "Does BTCZ have premine or ICO?", options: ["Yes", "No – 100% fair launch", "Partial"], correctAnswer: "No – 100% fair launch"),
        Question(text: "Can you mine BTCZ with GPU?", options: ["No", "Yes", "Only ASIC"], correctAnswer: "Yes"),
        Question(text: "Does BTCZ support shielded transactions?", options: ["No", "Yes", "Partial"], correctAnswer: "Yes"),
        Question(text: "Who manages BTCZ?", options: ["Company", "Community", "Foundation", "Elon"], correctAnswer: "Community"),
        Question(text: "Official BTCZ website?", options: ["btcz.io", "getbtcz.com", "bitcoinz.site"], correctAnswer: "getbtcz.com")
    ]
    
    var body: some View {
        ZStack {
            gradientBackground
           
            if !hasWallet {
                walletRequiredView
            } else if quizCompleted {
                completedView
            } else if cooldownActive {
                cooldownView
            } else if showPenalty {
                penaltyView
            } else if showResult {
                successView
            } else {
                quizView
            }
        }
        .navigationTitle("Main Quiz")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            checkCooldown()
            if shuffledQuestions.isEmpty && hasWallet {
                shuffledQuestions = rawQuestions.shuffled()
            }
        }
        .alert("Reward Claimed!", isPresented: $showConfirmation) {
            Button("OK") { }
        } message: {
            Text("You earned +\(score) BTCZ!")
        }
    }
    
    private var walletRequiredView: some View {
        VStack(spacing: 40) {
            Image(systemName: "wallet.pass")
                .font(.system(size: 120))
                .foregroundStyle(.orange)
           
            Text("Verify Your BTCZ Wallet First!")
                .font(.largeTitle)
                .bold()
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
           
            NavigationLink(destination: WalletView()) {
                Text("Verify Wallet & Get 100 BTCZ")
                    .font(.title2)
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.orange)
                    .foregroundStyle(.white)
                    .cornerRadius(20)
            }
            .padding(.horizontal, 50)
        }
        .padding()
    }
    
    private var quizView: some View {
        guard currentQuestion < shuffledQuestions.count else { return AnyView(successView) }
        let q = currentShuffledQuestion
        
        return AnyView(
            VStack(spacing: 40) {
                ProgressView(value: Double(currentQuestion + 1), total: Double(shuffledQuestions.count))
                    .tint(.orange)
                    .padding(.horizontal, 30)
                
                Text(q.text)
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(spacing: 16) {
                    ForEach(q.options.indices, id: \.self) { i in
                        Button {
                            if i == q.correctIndex {
                                score += 10
                                nextQuestion()
                            } else {
                                score = 0
                                showPenalty = true
                                setCooldown()
                            }
                        } label: {
                            Text(q.options[i])
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white.opacity(0.15))
                                .foregroundStyle(.white)
                                .cornerRadius(16)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.orange.opacity(0.4), lineWidth: 1))
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
        )
    }
    
    private var currentShuffledQuestion: Question {
        let q = shuffledQuestions[currentQuestion]
        let shuffled = q.options.shuffled()
        let correctIndex = shuffled.firstIndex(of: q.correctAnswer) ?? 0
        return Question(text: q.text, options: shuffled, correctAnswer: q.correctAnswer, correctIndex: correctIndex)
    }
    
    private var successView: some View {
        VStack(spacing: 30) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 100))
                .foregroundStyle(.yellow)
            
            Text("Quiz Completed Successfully!")
                .font(.largeTitle)
                .bold()
                .foregroundStyle(.white)
            
            Text("You earned +\(score) BTCZ!")
                .font(.title)
                .bold()
                .foregroundStyle(.green)
            
            if !quizCompleted {
                Button("Claim Reward") {
                    isSubmitting = true
                    
                    ApiService.completeTask(taskId: "102") { success in
                        DispatchQueue.main.async {
                            isSubmitting = false
                            if success {
                                PointsManager.shared.syncWithServer()
                                UserDefaults.standard.set(true, forKey: "mainQuizCompleted")
                                quizCompleted = true
                                showConfirmation = true
                                
                                // VRNI NA HOME
                                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                   let window = windowScene.windows.first {
                                    window.rootViewController = UIHostingController(rootView: HomeView())
                                    window.makeKeyAndVisible()
                                }
                            }
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.orange)
                .disabled(isSubmitting)
            } else {
                Text("Reward already claimed!")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding()
    }
    
    private var penaltyView: some View {
        VStack(spacing: 30) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 100))
                .foregroundStyle(.red)
            Text("Wrong Answer!")
                .font(.largeTitle)
                .bold()
                .foregroundStyle(.white)
            Text("All points lost.\nStudy and try again in 10 minutes.")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
            Button("Study BTCZ") {
                if let url = URL(string: "https://getbtcz.com") { UIApplication.shared.open(url) }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.blue)
        }
        .padding()
    }
    
    private var completedView: some View {
        VStack(spacing: 30) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 100))
                .foregroundStyle(.green)
            Text("Quiz Already Completed!")
                .font(.largeTitle)
                .bold()
                .foregroundStyle(.white)
            Text("Reward already claimed")
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding()
    }
    
    private var cooldownView: some View {
        VStack(spacing: 30) {
            Image(systemName: "clock.fill")
                .font(.system(size: 100))
                .foregroundStyle(.orange)
            Text("Cooldown Active")
                .font(.largeTitle)
                .bold()
                .foregroundStyle(.white)
            Text("Come back in 10 minutes to try again.")
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding()
    }
    
    private func nextQuestion() {
        if currentQuestion < shuffledQuestions.count - 1 {
            currentQuestion += 1
        } else {
            showResult = true
        }
    }
    
    private func setCooldown() {
        let timestamp = Date().timeIntervalSince1970 + 600
        UserDefaults.standard.set(timestamp, forKey: cooldownKey)
        cooldownActive = true
    }
    
    private func checkCooldown() {
        let timestamp = UserDefaults.standard.double(forKey: cooldownKey)
        cooldownActive = timestamp > Date().timeIntervalSince1970
    }
    
    private var gradientBackground: some View {
        LinearGradient(colors: [.blue.opacity(0.9), .black, .orange.opacity(0.6)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }
}

struct Question {
    let text: String
    let options: [String]
    let correctAnswer: String
    var correctIndex = 0
}

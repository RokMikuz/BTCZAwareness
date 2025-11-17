// SimpleQuestionsView.swift – 100 % CELOTNA – POPOLNO DELOVANJE – ENKRAT NA DAN!
import SwiftUI

struct SimpleQuestionsView: View {
    @State private var questions: [QuizQuestion] = []
    @State private var currentQuestion = 0
    @State private var showResult = false
    @State private var showPenalty = false
    @State private var isSubmitting = false
    @State private var quizLocked = true
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss
    @State private var backPressed = false
    
    var body: some View {
        ZStack {
            // OZADJE
            LinearGradient(
                colors: [.blue.opacity(0.9), .black, .orange.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // STANJA
            if isLoading {
                ProgressView("Loading quiz...")
                    .scaleEffect(1.5)
                    .foregroundStyle(.white)
            }
            else if quizLocked {
                lockedView
            }
            else if questions.isEmpty {
                VStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.yellow)
                    Text("No questions available")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            else if showResult {
                successView
            }
            else if showPenalty {
                penaltyView
            }
            else {
                quizView
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                BannerAdView(adUnitId: "ca-app-pub-5181471839265609/5152049399")
                    .frame(maxWidth: 600)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
        .navigationTitle("Main Quiz")
        .navigationBarTitleDisplayMode(.large)
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
        .foregroundStyle(.white)
        .onAppear {
            checkIfQuizIsAvailable()
        }
    }
    
    // PREVERI, ČE JE KVIZ NA VOLJO – 100 % PO SERVERJU!
    private func checkIfQuizIsAvailable() {
        isLoading = true
        
        ApiService.isQuizCompleted { done in
            DispatchQueue.main.async {
                self.quizLocked = done
                
                if done {
                    // Kviz že opravljen danes
                    self.isLoading = false
                } else {
                    // Kviz je na voljo – naloži vprašanja
                    ApiService.fetchQuizQuestions { fetched in
                        DispatchQueue.main.async {
                            if !fetched.isEmpty {
                                self.questions = fetched.shuffled()
                            }
                            self.isLoading = false
                        }
                    }
                }
            }
        }
    }
    
    // GLAVNI ZASLON S VPRAŠANJI
    private var quizView: some View {
        let q = questions[currentQuestion]
        
        return VStack(spacing: 40) {
            // Progress bar
            ProgressView(value: Double(currentQuestion + 1), total: Double(questions.count))
                .tint(.orange)
                .padding(.horizontal, 30)
            
            // Vprašanje
            Text(q.text)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal)
            
            // Odgovori
            VStack(spacing: 16) {
                ForEach(q.options.indices, id: \.self) { i in
                    Button {
                        if q.options[i] == q.correctAnswer {
                            nextQuestion()
                        } else {
                            showPenalty = true
                            true
                        }
                    } label: {
                        Text(q.options[i])
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.15))
                            .foregroundStyle(.white)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(.orange.opacity(0.4), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
    
    // USPEŠNO KONČANO
    private var successView: some View {
        VStack(spacing: 40) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 120))
                .foregroundStyle(.yellow)
                .symbolEffect(.bounce)
            
            Text("Congratulations!")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            
            Text("You have earned BTCZ!")
                .font(.title2)
                .foregroundStyle(.green)
            
            Button("Claim Reward") {
                isSubmitting = true
                ApiService.completeTask(taskId: "102") { success in
                    DispatchQueue.main.async {
                        isSubmitting = false
                        if success {
                            ApiService.getConfig { cfg in
                                let reward = (cfg["quiz_reward"] as? Int) ?? 100
                                ApiService.addPoints(amount: reward) { ok, _, newPoints in
                                    if ok, let np = newPoints { PointsManager.shared.currentPoints = np } else { PointsManager.shared.syncWithServer() }
                                    // Nazaj na Home
                                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                       let window = windowScene.windows.first {
                                        window.rootViewController = UIHostingController(rootView: HomeView())
                                        window.makeKeyAndVisible()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(isSubmitting)
        }
        .padding()
    }
    
    // NAPAČEN ODGOVOR
    private var penaltyView: some View {
        VStack(spacing: 30) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 100))
                .foregroundStyle(.red)
            Text("Wrong Answer!")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            Text("Try again when quiz is unlocked.")
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // KVIZ ZAKLENJEN
    private var lockedView: some View {
        VStack(spacing: 30) {
            Image(systemName: "lock.fill")
                .font(.system(size: 100))
                .foregroundStyle(.gray)
            Text("Quiz Locked")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            Text("You have already completed the quiz today.\nCome back tomorrow!")
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // NASLEDNJE VPRAŠANJE
    private func nextQuestion() {
        if currentQuestion < questions.count - 1 {
            currentQuestion += 1
        } else {
            showResult = true
        }
    }
}

#Preview {
    SimpleQuestionsView()
}

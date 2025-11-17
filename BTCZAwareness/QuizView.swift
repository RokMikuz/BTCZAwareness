//
//  QuizView.swift
//  BTCZAwareness
//
//  Created by Rok on 17. 11. 25.
//

// QuizView.swift
import SwiftUI

struct QuizView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var questions: [QuizQuestion] = []
    @State private var currentIndex: Int = 0
    @State private var shuffledOptions: [String] = []
    @State private var selectedOption: String? = nil
    @State private var showFeedback: Bool = false
    @State private var quizFinished: Bool = false
    @State private var isLoading: Bool = true

    @State private var quizCompletedToday: Bool = false
    @State private var showCompletionAlert: Bool = false
    @State private var completionMessage: String = ""
    @State private var quizReward: Int? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [.indigo.opacity(0.9), .black, .purple.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                if isLoading {
                    ProgressView("Nalagam kviz…")
                        .font(.headline)
                        .tint(.white)
                } else if quizFinished {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)
                        Text("Kviz zaključen!")
                            .font(.title.bold())
                            .foregroundStyle(.white)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.2)))
                } else if quizCompletedToday {
                    VStack(spacing: 16) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.white.opacity(0.7))
                        Text("Kviz že opravljen danes!")
                            .font(.title.bold())
                            .foregroundStyle(.white.opacity(0.9))
                        Text("Poskusi ponovno jutri ali preveri druge vsebine.")
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.2)))
                    .padding(.horizontal, 24)
                } else {
                    let q = questions[currentIndex]
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Vprašanje \(currentIndex + 1)/\(questions.count)")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.9))
                        Text(q.text)
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(spacing: 14) {
                            ForEach(shuffledOptions, id: \.self) { option in
                                AnswerButton(
                                    title: option,
                                    state: buttonState(for: option),
                                    action: { select(option) }
                                )
                                .disabled(showFeedback)
                            }
                        }
                        .padding(.top, 8)

                        if showFeedback {
                            Button(action: next) {
                                Text(currentIndex == questions.count - 1 ? "Zaključi" : "Naprej")
                                    .font(.headline)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(.green)
                                    .foregroundStyle(.white)
                                    .cornerRadius(16)
                                    .shadow(color: .green.opacity(0.6), radius: 12)
                            }
                            .transition(.opacity)
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .fill(LinearGradient(colors: [Color.white.opacity(0.06), Color.black.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .overlay(RoundedRectangle(cornerRadius: 22).stroke(LinearGradient(colors: [Color.white.opacity(0.3), Color.white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.08), lineWidth: 2).blur(radius: 1).padding(2))
                            .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 10)
                            .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 2)
                    )
                    .padding(.horizontal, 24)
                }

                Spacer()
            }
            .navigationTitle("Kviz")
            .onAppear {
                fetchQuestions()
                checkQuizStatus()
                fetchRewardIfNeeded()
            }
            .alert(completionMessage, isPresented: $showCompletionAlert) {
                Button("V redu", role: .cancel) { }
            }
        }
    }

    private func fetchQuestions() {
        isLoading = true
        ApiService.fetchQuizQuestions { fetched in
            DispatchQueue.main.async {
                self.questions = fetched
                self.currentIndex = 0
                self.quizFinished = fetched.isEmpty
                self.isLoading = false
                self.prepareQuestion()
            }
        }
    }

    private func prepareQuestion() {
        guard currentIndex < questions.count else { quizFinished = true; return }
        let q = questions[currentIndex]
        var options = q.options.shuffled()
        if options.count > 1 {
            var attempts = 0
            while options.first == q.correctAnswer && attempts < 3 {
                options.shuffle()
                attempts += 1
            }
        }
        shuffledOptions = options
        selectedOption = nil
        showFeedback = false
    }

    private func select(_ option: String) {
        guard !showFeedback else { return }
        selectedOption = option
        if reduceMotion {
            showFeedback = true
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                showFeedback = true
            }
        }
    }

    private func next() {
        if currentIndex + 1 < questions.count {
            currentIndex += 1
            prepareQuestion()
        } else {
            completeQuiz()
        }
    }

    private func completeQuiz() {
        ApiService.completeTask(taskId: "102") { success in
            DispatchQueue.main.async {
                if success {
                    self.completionMessage = "+\(quizReward ?? 100) BTCZ"
                    self.showCompletionAlert = true
                    PointsManager.shared.syncWithServer()
                    self.quizFinished = true
                    self.quizCompletedToday = true
                } else {
                    self.completionMessage = "Kviz ni bil uspešno zaključen"
                    self.showCompletionAlert = true
                }
            }
        }
    }

    private func buttonState(for option: String) -> AnswerButton.State {
        guard showFeedback, let selected = selectedOption else { return .normal }
        let isCorrect = option == questions[currentIndex].correctAnswer
        if isCorrect { return .correct }
        if option == selected { return .wrong }
        return .normal
    }

    private func checkQuizStatus() {
        ApiService.isQuizCompleted { done in
            DispatchQueue.main.async {
                self.quizCompletedToday = done
            }
        }
    }

    private func fetchRewardIfNeeded() {
        ApiService.fetchQuizReward { reward in
            DispatchQueue.main.async {
                self.quizReward = reward
            }
        }
    }
}

private struct AnswerButton: View {
    enum State { case normal, correct, wrong }
    let title: String
    let state: State
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.headline)
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding()
            .background(neoBackground)
            .overlay(neoStroke)
            .overlay(innerGlow)
            .overlay(specular)
            .overlay(colorRing)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.35), radius: 16, x: 0, y: 10)
            .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 2)
        }
    }

    private var iconName: String {
        switch state {
        case .normal: return "circle"
        case .correct: return "checkmark.circle.fill"
        case .wrong: return "xmark.circle.fill"
        }
    }

    private var iconColor: Color {
        switch state {
        case .normal: return .white.opacity(0.8)
        case .correct: return .green
        case .wrong: return .red
        }
    }

    private var neoBackground: some View {
        LinearGradient(
            colors: [Color.white.opacity(0.06), Color.black.opacity(0.18)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var neoStroke: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(
                LinearGradient(
                    colors: [Color.white.opacity(0.3), Color.white.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.5
            )
    }

    private var innerGlow: some View {
        RoundedRectangle(cornerRadius: 14)
            .stroke(Color.white.opacity(0.08), lineWidth: 2)
            .blur(radius: 1)
            .padding(2)
    }

    private var specular: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.28), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: 14)
            .padding(.horizontal, 40)
            .rotationEffect(.degrees(-25))
            .offset(x: -8, y: -16)
            .blendMode(.screen)
    }

    private var colorRing: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(ringColor.opacity(0.9), lineWidth: 2)
            .shadow(color: ringColor.opacity(0.45), radius: 10)
    }

    private var ringColor: Color {
        switch state {
        case .normal: return .white.opacity(0.2)
        case .correct: return .green
        case .wrong: return .red
        }
    }
}

#Preview { QuizView() }

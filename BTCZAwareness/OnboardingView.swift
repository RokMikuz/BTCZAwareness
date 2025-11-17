import SwiftUI

struct OnboardingView: View {
    enum Step { case welcome, createKey, confirmKey, restore }

    @State private var step: Step = .welcome
    @State private var generatedKey: String = OnboardingView.generateKey()
    @State private var confirmPart1: String = ""
    @State private var confirmPart2: String = ""
    @State private var confirmPart3: String = ""

    @State private var restorePart1: String = ""
    @State private var restorePart2: String = ""
    @State private var restorePart3: String = ""

    @State private var message: String? = nil
    @State private var isBusy = false

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 24) {
                Spacer().frame(height: 40)

                Image("btcz_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 90, height: 90)
                    .shadow(color: .yellow.opacity(0.8), radius: 16)
                    .modifier(Oscillate(rotation: 4, scaleDelta: 0.02))

                Group {
                    switch step {
                    case .welcome:
                        card(title: "Welcome to BTCZ Awareness") {
                            VStack(spacing: 16) {
                                Text("Choose how you want to start")
                                    .foregroundStyle(.white.opacity(0.9))

                                Button {
                                    withAnimation { step = .restore }
                                } label: {
                                    HStack {
                                        Image(systemName: "arrow.counterclockwise.circle.fill")
                                        Text("Restore Account")
                                    }
                                    .font(.headline)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(.orange.opacity(0.9))
                                    .foregroundStyle(.black)
                                    .cornerRadius(16)
                                    .modifier(PulseGlow(color: .orange))
                                }

                                Button {
                                    generatedKey = OnboardingView.generateKey()
                                    withAnimation { step = .createKey }
                                } label: {
                                    HStack {
                                        Image(systemName: "sparkles")
                                        Text("Create New Account")
                                    }
                                    .font(.headline)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(.green.opacity(0.9))
                                    .foregroundStyle(.white)
                                    .cornerRadius(16)
                                    .modifier(PulseGlow(color: .green))
                                }
                            }
                        }

                    case .createKey:
                        card(title: "Your New Key") {
                            VStack(spacing: 14) {
                                Text("Write this key down and keep it safe.")
                                    .foregroundStyle(.white.opacity(0.8))
                                Text(generatedKey)
                                    .font(.system(size: 36, weight: .black, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(colors: [.orange, .yellow, .orange], startPoint: .leading, endPoint: .trailing)
                                    )
                                    .shadow(color: .orange.opacity(0.6), radius: 12)
                                    .padding(.vertical, 8)
                                Button {
                                    UIPasteboard.general.string = generatedKey
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc.fill")
                                        .padding(.horizontal, 16).padding(.vertical, 10)
                                        .background(.ultraThinMaterial)
                                        .cornerRadius(12)
                                }
                                Divider().background(.white.opacity(0.2))
                                Text("Confirm your key by re-entering it")
                                    .foregroundStyle(.white.opacity(0.85))
                                tripletFields(p1: $confirmPart1, p2: $confirmPart2, p3: $confirmPart3)
                                if let msg = message { Text(msg).font(.footnote).foregroundStyle(.secondary) }
                                Button {
                                    confirmKey()
                                } label: {
                                    if isBusy { ProgressView().tint(.white) } else { Text("Confirm & Continue").bold() }
                                }
                                .disabled(isBusy)
                                Button("Back") { withAnimation { step = .welcome } }
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }

                    case .confirmKey:
                        EmptyView() // not used; confirmation handled inside createKey card

                    case .restore:
                        card(title: "Restore Account") {
                            VStack(spacing: 14) {
                                Text("Enter your 9-character restore key")
                                    .foregroundStyle(.white.opacity(0.85))
                                tripletFields(p1: $restorePart1, p2: $restorePart2, p3: $restorePart3)
                                if let msg = message { Text(msg).font(.footnote).foregroundStyle(.secondary) }
                                Button {
                                    restore()
                                } label: {
                                    if isBusy { ProgressView().tint(.white) } else { Text("Restore").bold() }
                                }
                                .buttonStyle(.borderedProminent)
                                Button("Back") { withAnimation { step = .welcome } }
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                    }
                }
                .animation(.easeInOut, value: step)

                Spacer()
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .onAppear { withAnimation(.easeOut(duration: 0.4)) {} }
            .padding()
        }
    }

    private func card<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.title.bold())
                .foregroundStyle(
                    LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
                )
            content()
        }
        .padding(24)
        .frame(maxWidth: 600)
        .background(.ultraThinMaterial)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .purple.opacity(0.35), radius: 18)
    }

    private func tripletFields(p1: Binding<String>, p2: Binding<String>, p3: Binding<String>) -> some View {
        HStack(spacing: 12) {
            TextField("XXX", text: p1)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled(true)
                .multilineTextAlignment(.center)
                .keyboardType(.asciiCapable)
                .frame(width: 80)
                .textFieldStyle(.roundedBorder)
            Text("-")
                .foregroundStyle(.secondary)
            TextField("XXX", text: p2)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled(true)
                .multilineTextAlignment(.center)
                .keyboardType(.asciiCapable)
                .frame(width: 80)
                .textFieldStyle(.roundedBorder)
            Text("-")
                .foregroundStyle(.secondary)
            TextField("XXX", text: p3)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled(true)
                .multilineTextAlignment(.center)
                .keyboardType(.asciiCapable)
                .frame(width: 80)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func confirmKey() {
        let p1 = confirmPart1.trimmingCharacters(in: .whitespacesAndNewlines)
        let p2 = confirmPart2.trimmingCharacters(in: .whitespacesAndNewlines)
        let p3 = confirmPart3.trimmingCharacters(in: .whitespacesAndNewlines)
        guard p1.count == 3, p2.count == 3, p3.count == 3 else {
            message = "Please enter all three 3-character parts."
            return
        }
        let entered = "\(p1)-\(p2)-\(p3)"
        if entered.caseInsensitiveCompare(generatedKey) == .orderedSame {
            registerWithRestore()
        } else {
            message = "Keys do not match. Please try again."
        }
    }

    private func restore() {
        let p1 = restorePart1.trimmingCharacters(in: .whitespacesAndNewlines)
        let p2 = restorePart2.trimmingCharacters(in: .whitespacesAndNewlines)
        let p3 = restorePart3.trimmingCharacters(in: .whitespacesAndNewlines)
        guard p1.count == 3, p2.count == 3, p3.count == 3 else {
            message = "Please enter all three 3-character parts."
            return
        }
        let code = "\(p1)-\(p2)-\(p3)"
        print("[RESTORE][ACCOUNT] POST /api/restore-account")
        print("[RESTORE][ACCOUNT] request: { device_id: \(ApiService.deviceID), restore_code: \(code) }")
        isBusy = true
        message = "Restoring..."
        ApiService.restoreAccount(restoreCode: code) { success, msg in
            DispatchQueue.main.async {
                print("[RESTORE][ACCOUNT] response: success=\(success) message=\(msg ?? "nil")")
                isBusy = false
                message = msg
                if success {
                    // Backend returns updated account; sync and finish
                    PointsManager.shared.syncWithServer()
                    completeOnboarding()
                }
            }
        }
    }

    private func registerWithRestore() {
        print("[RESTORE][REGISTER] POST /api/register-with-restore")
        print("[RESTORE][REGISTER] request: { device_id: \(ApiService.deviceID), restore_code: \(generatedKey) }")
        isBusy = true
        message = "Creating account..."
        ApiService.registerWithRestore(restoreCode: generatedKey) { success, msg in
            DispatchQueue.main.async {
                print("[RESTORE][REGISTER] response: success=\(success) message=\(msg)")
                isBusy = false
                message = msg
                if success {
                    // Optionally ingest points/referral code if needed via another fetch
                    completeOnboarding()
                }
            }
        }
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "onboardingCompleted")
        PointsManager.shared.syncWithServer()
        NotificationCenter.default.post(name: Notification.Name("OnboardingCompletedNotification"), object: nil)
    }

    static func generateKey() -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789") // no confusing chars
        func triad() -> String { String((0..<3).map { _ in chars.randomElement()! }) }
        return "\(triad())-\(triad())-\(triad())"
    }
}


private struct Oscillate: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let rotation: Double
    let scaleDelta: CGFloat
    @State private var t: CGFloat = 0
    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(reduceMotion ? 0 : CGFloat(sin(Double(t))) * rotation))
            .scaleEffect(reduceMotion ? 1.0 : 1.0 + CGFloat(sin(Double(t * 0.9))) * scaleDelta)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) {
                    t = .pi * 2
                }
            }
    }
}

private struct PulseGlow: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let color: Color
    @State private var glow: CGFloat = 0
    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(reduceMotion ? 0.0 : 0.45), radius: reduceMotion ? 0 : 10 + glow * 6)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                    glow = 1
                }
            }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}

import SwiftUI

struct PvPGamesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var backPressed = false
    @State private var pvpPulse = false
    @State private var shimmerOffset: CGFloat = -40
    
    @State private var myBalance: Int = 0
    @State private var winReward: Int = 0
    @State private var showInsufficientAlert = false
    @State private var navigateToPvP = false
    @State private var navigateToTetris = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.indigo.opacity(0.95), .black, .purple.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 30) {
                // Top bar with Solo Play button
                HStack {
                    Button {
                        // Go to HomeView (Main Menu)
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let window = windowScene.windows.first {
                            window.rootViewController = UIHostingController(rootView: HomeView())
                            window.makeKeyAndVisible()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "house.fill")
                                .font(.title3.bold())
                            Text("Main Menu")
                                .font(.headline)
                                .bold()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .foregroundStyle(.cyan)
                        .cornerRadius(12)
                    }

                    Button {
                        backPressed = true
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                            backPressed = false
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.title3.bold())
                            Text("Solo Play")
                                .font(.headline)
                                .bold()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .foregroundStyle(.orange)
                        .cornerRadius(12)
                        .scaleEffect(backPressed ? 0.96 : 1.0)
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: backPressed)
                    }

                    Spacer()
                }
                .padding(.top, 16)
                .padding(.horizontal, 20)
                .onAppear {
                    // Fetch config (win_reward) and user balance
                    ApiService.getConfig { config in
                        // Assuming config is a dictionary-like response
                        if let tetrisReward = config["tetris_pvp_win_reward"] as? Int {
                            self.winReward = tetrisReward
                        } else if let tetrisRewardStr = config["tetris_pvp_win_reward"] as? String, let v = Int(tetrisRewardStr) {
                            self.winReward = v
                        } else {
                            self.winReward = (config["win_reward"] as? Int) ?? self.winReward
                        }
                    }
                    ApiService.getWalletBalance { balance in
                        self.myBalance = balance
                    }
                }

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 30) {
                        // Hero header
                        VStack(spacing: 12) {
                            Text("Multiplayer Arena")
                                .font(.system(size: 34, weight: .black, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing)
                                )
                                .shadow(color: .purple.opacity(0.4), radius: 10, x: 0, y: 6)

                            HStack(spacing: 8) {
                                Image(systemName: "bolt.fill")
                                    .foregroundStyle(.yellow)
                                Text("Live 1v1 matches")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.white.opacity(0.85))
                                Text("Quick match < 5s")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.ultraThinMaterial)
                                    .foregroundStyle(.cyan)
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.top, 6)

                        // Memory Match PvP card
                        Button {
                            if myBalance >= winReward {
                                navigateToPvP = true
                            } else {
                                showInsufficientAlert = true
                            }
                        } label: {
                            ZStack {
                                // Glow ring
                                RoundedRectangle(cornerRadius: 28)
                                    .stroke(
                                        LinearGradient(colors: [.teal.opacity(0.9), .blue.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                        lineWidth: 3
                                    )
                                    .blur(radius: 2)
                                    .opacity(pvpPulse ? 0.9 : 0.5)

                                // Shimmer sweep
                                RoundedRectangle(cornerRadius: 28)
                                    .fill(
                                        LinearGradient(colors: [.white.opacity(0.0), .white.opacity(0.12), .white.opacity(0.0)], startPoint: .leading, endPoint: .trailing)
                                    )
                                    .rotationEffect(.degrees(12))
                                    .offset(x: shimmerOffset)
                                    .blendMode(.screen)
                                    .allowsHitTesting(false)

                                GamePreviewCard(
                                    title: "Memory Match PvP",
                                    subtitle: "1v1 head-to-head",
                                    icon: "person.2.fill",
                                    color: .teal
                                )
                                .padding(2)
                            }
                        }
                        .buttonStyle(.plain)
                        .scaleEffect(pvpPulse ? 1.02 : 1.0)
                        .rotation3DEffect(.degrees(pvpPulse ? 0.4 : 0.0), axis: (x: 0, y: 1, z: 0))
                        .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: pvpPulse)
                        .onAppear {
                            pvpPulse = true
                            withAnimation(.linear(duration: 2.8).repeatForever(autoreverses: false)) {
                                shimmerOffset = 40
                            }
                        }

                        NavigationLink("", destination: MemoryMatchPvPView(), isActive: $navigateToPvP)
                            .hidden()

                        // PvP Slots (coming soon)
                        ZStack {
                            GamePreviewCard(
                                title: "PvP Slots",
                                subtitle: "Coming soon",
                                icon: "die.face.5.fill",
                                color: .purple
                            )

                            // Diagonal ribbon
                            ZStack {
                                Capsule()
                                    .fill(Color.black.opacity(0.6))
                                    .frame(height: 36)
                                    .overlay(
                                        Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1)
                                    )
                                    .rotationEffect(.degrees(-20))
                                Text("COMING SOON")
                                    .font(.caption.bold())
                                    .tracking(2)
                                    .foregroundStyle(.white)
                                    .rotationEffect(.degrees(-20))
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .offset(x: -12, y: 22)
                        }
                        .opacity(0.7)
                        .allowsHitTesting(false)

                        // PvP Tetris card (coming soon)
                        ZStack {
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(
                                    LinearGradient(colors: [.orange.opacity(0.9), .red.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                    lineWidth: 3
                                )
                                .blur(radius: 2)
                                .opacity(pvpPulse ? 0.9 : 0.5)

                            RoundedRectangle(cornerRadius: 28)
                                .fill(
                                    LinearGradient(colors: [.white.opacity(0.0), .white.opacity(0.12), .white.opacity(0.0)], startPoint: .leading, endPoint: .trailing)
                                )
                                .rotationEffect(.degrees(12))
                                .offset(x: shimmerOffset)
                                .blendMode(.screen)
                                .allowsHitTesting(false)

                            GamePreviewCard(
                                title: "PvP Tetris",
                                subtitle: "Coming soon",
                                icon: "square.stack.3d.up.fill",
                                color: .orange
                            )
                            .padding(2)

                            // Diagonal ribbon
                            ZStack {
                                Capsule()
                                    .fill(Color.black.opacity(0.6))
                                    .frame(height: 36)
                                    .overlay(
                                        Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1)
                                    )
                                    .rotationEffect(.degrees(-20))
                                Text("COMING SOON")
                                    .font(.caption.bold())
                                    .tracking(2)
                                    .foregroundStyle(.white)
                                    .rotationEffect(.degrees(-20))
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .offset(x: -12, y: 22)
                        }
                        .scaleEffect(pvpPulse ? 1.02 : 1.0)
                        .rotation3DEffect(.degrees(pvpPulse ? 0.4 : 0.0), axis: (x: 0, y: 1, z: 0))
                        .allowsHitTesting(false)
                        .opacity(0.7)
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 10)
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationTitle("Multiplayer")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .alert("Insufficient BTCZ", isPresented: $showInsufficientAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You need at least \(winReward) BTCZ to play.")
        }
    }
}

#Preview {
    NavigationStack {
        PvPGamesView()
    }
}


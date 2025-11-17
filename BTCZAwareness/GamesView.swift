// GamesView.swift – POPRAVLJENA – Z NOVIM GUMBOM ZA BTCZ TETRIS
import SwiftUI

struct GamesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var backPressed = false
    @State private var pulse = false
    
    var body: some View {
        
            ZStack {
                LinearGradient(
                    colors: [.indigo.opacity(0.95), .black, .purple.opacity(0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 30) {
                            
                            // BTCZ Clicker
                            NavigationLink(destination: BTCZClickerView()) {
                                GamePreviewCard(
                                    title: "BTCZ Clicker",
                                    subtitle: "Tap to mine BTCZ!",
                                    icon: "hand.tap.fill",
                                    color: .green
                                )
                            }
                            .buttonStyle(.plain)
                            
                            // Memory Match
                            NavigationLink(destination: MemoryMatchView()) {
                                GamePreviewCard(
                                    title: "Memory Match",
                                    subtitle: "Find matching pairs",
                                    icon: "square.grid.3x3.fill",
                                    color: .blue
                                )
                            }
                            .buttonStyle(.plain)
                            
                            // Multiplayer quick access button at top (Memory Match PvP)
                            NavigationLink(destination: PvPGamesView()) {
                                ZStack {
                                    // Pulsing glow background
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.clear)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(LinearGradient(colors: [.pink.opacity(0.25), .purple.opacity(0.25)], startPoint: .leading, endPoint: .trailing))
                                                .blur(radius: 20)
                                                .opacity(pulse ? 1.0 : 0.2)
                                        )
                                        .allowsHitTesting(false)
                                    
                                    // Original content
                                    HStack(spacing: 10) {
                                        Image(systemName: "person.2.fill")
                                            .font(.title2.bold())
                                        Text("Multiplayer (PvP)")
                                            .font(.headline)
                                            .bold()
                                    }
                                    .foregroundStyle(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        LinearGradient(colors: [.pink, .purple], startPoint: .leading, endPoint: .trailing)
                                    )
                                    .cornerRadius(16)
                                    .shadow(color: .pink.opacity(0.5), radius: 18, x: 0, y: 6)
                                }
                                .scaleEffect(pulse ? 1.03 : 1.0)
                                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: pulse)
                                .onAppear { pulse = true }
                            }
                            .buttonStyle(.plain)
                            
                            // BTCZ Slots
                            NavigationLink(destination: BTCZSlotsView()) {
                                GamePreviewCard(
                                    title: "BTCZ Slots",
                                    subtitle: "Spin & Win BTCZ!",
                                    icon: "dice.fill",
                                    color: .purple
                                )
                            }
                            .buttonStyle(.plain)
                            
                            // BTCZ Tetris – NOVO!
                            NavigationLink(destination: BTCZTetrisView()) {
                                GamePreviewCard(
                                    title: "BTCZ Tetris",
                                    subtitle: "Clear lines for BTCZ",
                                    icon: "square.stack.3d.up.fill",
                                    color: .orange
                                )
                            }
                            .buttonStyle(.plain)
                            
                            // Endless Runner – Coming Soon
                            GamePreviewCard(
                                title: "Endless Runner",
                                subtitle: "Coming Soon!",
                                icon: "figure.run",
                                color: .red
                            )
                            .opacity(0.6)
                        }
                        .padding(.horizontal, 30)
                        .padding(.top, 10)
                        .padding(.bottom, 30)
                    }
                    .scrollBounceBehavior(.basedOnSize, axes: .vertical)
                }
            }
            .navigationTitle("Game menu")
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
}

// LEPŠA KARTICA ZA PREDOGLED IGRE
struct GamePreviewCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    
    @State private var shimmerPhase: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundStyle(color)
                .frame(width: 100, height: 100)
                .background(Circle().fill(.black.opacity(0.4)))
                .overlay(Circle().stroke(color.opacity(0.8), lineWidth: 4))
                .shadow(color: color.opacity(0.6), radius: 15)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .allowsTightening(true)
                    .truncationMode(.tail)
                
                Text(subtitle)
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.8))
                
                Text("Play & Earn BTCZ")
                    .font(.headline)
                    .foregroundStyle(color)
            }
            
            Spacer()
        }
        .padding(25)
        .background(
            ZStack {
                // Base card
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.35), .indigo.opacity(0.28)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        // Border with blended color
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(
                                LinearGradient(
                                    colors: [color.opacity(0.9), .purple.opacity(0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                    )
                    .shadow(color: color.opacity(0.45), radius: 16, x: 0, y: 8)
                    .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 16)

                // Subtle inner glow
                RoundedRectangle(cornerRadius: 28)
                    .stroke(color.opacity(0.25), lineWidth: 2)
                    .blur(radius: 4)
                    .opacity(0.6)

                // Shimmer highlight sweep
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.0),
                                .white.opacity(0.12),
                                .white.opacity(0.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .rotationEffect(.degrees(12))
                    .offset(x: shimmerPhase)
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            }
        )
        .onAppear {
            // Slow, subtle shimmer motion
            withAnimation(.linear(duration: 3.5).repeatForever(autoreverses: false)) {
                shimmerPhase = 40
            }
        }
    }
}

#Preview {
    GamesView()
}


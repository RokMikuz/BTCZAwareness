// LeaderboardView.swift – 100 % CELOTNA – "Anonymous" ZA UPORABNIKE BREZ DENARNICE – VSE DELUJE!
import SwiftUI

struct LeaderboardView: View {
    @State private var rankings: [UserRank] = []
    @State private var isLoading = true
    @State private var backPressed = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                // EPIC GRADIENT BACKGROUND
                LinearGradient(
                    colors: [.purple.opacity(0.9), .black, .indigo.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                if isLoading {
                    ProgressView("Loading rankings...")
                        .scaleEffect(1.5)
                        .foregroundStyle(.white)
                } else if rankings.isEmpty {
                    Text("No rankings yet")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.7))
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            Spacer().frame(height: 20)
                            
                            // TOP 3 – MEDALJE + ANIMACIJE
                            HStack(spacing: 20) {
                                if rankings.count >= 2 { podiumPlace(rank: rankings[1], place: 2) }
                                if rankings.count >= 1 { podiumPlace(rank: rankings[0], place: 1) }
                                if rankings.count >= 3 { podiumPlace(rank: rankings[2], place: 3) }
                            }
                            .padding(.horizontal)
                            
                            Spacer().frame(height: 30)
                            
                            // OSTALI – ELEGANTNA LISTA
                            ForEach(Array(rankings.dropFirst(3).enumerated()), id: \.element.id) { index, rank in
                                rankRow(rank: rank, position: index + 4)
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        backPressed = true
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            // brief press feedback
                        }
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
                loadLeaderboard()
            }
        }
    }
    
    // TOP 3 – ZLATA, SREBRNA, BRONASTA
    private func podiumPlace(rank: UserRank, place: Int) -> some View {
        let medalColor: Color
        let medalIcon: String
        let height: CGFloat
        
        switch place {
        case 1: medalColor = .yellow;  medalIcon = "crown.fill";   height = 180
        case 2: medalColor = .gray;    medalIcon = "medal.fill";   height = 140
        case 3: medalColor = .orange; medalIcon = "medal.fill";   height = 120
        default: medalColor = .clear;   medalIcon = "";            height = 0
        }
        
        return VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(medalColor.opacity(0.3))
                    .frame(width: height * 0.8, height: height * 0.8)
                    .blur(radius: 20)
                
                Image(systemName: medalIcon)
                    .font(.system(size: height * 0.35, weight: .bold))
                    .foregroundStyle(medalColor)
                
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: height * 0.6, height: height * 0.6)
                    .overlay(Circle().stroke(medalColor, lineWidth: 4))
            }
            
            Text("#\(place)")
                .font(.system(size: 32, weight: .black))
                .foregroundStyle(medalColor)
                .shadow(color: medalColor.opacity(0.8), radius: 10)
            
            Text(rank.anonymizedAddress == "brez" ? "Anonymous" : rank.anonymizedAddress)
                .font(.title3.bold())
                .foregroundStyle(.white)
            
            Text("\(rank.points) BTCZ")
                .font(.title2.bold())
                .foregroundStyle(medalColor)
                .shadow(color: medalColor.opacity(0.6), radius: 10)
        }
        .scaleEffect(place == 1 ? 1.1 : 1.0)
        .animation(.spring(response: 0.8, dampingFraction: 0.6), value: rankings)
    }
    
    // OSTALI – ELEGANTNI VRSTICI
    private func rankRow(rank: UserRank, position: Int) -> some View {
        HStack {
            Text("#\(position)")
                .font(.title2.bold())
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(rank.anonymizedAddress == "brez" ? "Anonymous" : rank.anonymizedAddress)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                Text("\(rank.points) BTCZ")
                    .font(.headline)
                    .foregroundStyle(.orange)
            }
            
            Spacer()
            
            Image(systemName: "flame.fill")
                .font(.title2)
                .foregroundStyle(.orange)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .purple.opacity(0.4), radius: 10)
        .padding(.horizontal, 10)
    }
    
    private func loadLeaderboard() {
        isLoading = true
        ApiService.fetchLeaderboard { fetched in
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                    self.rankings = fetched
                    self.isLoading = false
                }
            }
        }
    }
}

#Preview {
    LeaderboardView()
}

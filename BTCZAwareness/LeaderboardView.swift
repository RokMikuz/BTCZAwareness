import SwiftUI

struct LeaderboardView: View {
    @State private var leaderboard: [UserRank] = []
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            gradientBackground
            
            VStack {
                if isLoading {
                    ProgressView("Loading leaderboard...")
                        .scaleEffect(1.5)
                        .foregroundStyle(.white)
                } else if leaderboard.isEmpty {
                    Text("No rankings yet")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.8))
                } else {
                    List {
                        ForEach(leaderboard) { rank in
                            HStack {
                                Text("#\(rank.position)")
                                    .font(.title2)
                                    .frame(width: 50)
                                    .foregroundStyle(.orange)
                                Text(rank.anonymizedAddress)
                                    .foregroundStyle(.white)
                                Spacer()
                                Text("\(rank.points) BTCZ")
                                    .font(.title2)
                                    .bold()
                                    .foregroundStyle(.green)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                    .background(Color.clear)
                }
            }
        }
        .navigationTitle("Leaderboard")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadLeaderboard() }
    }
    
    private func loadLeaderboard() {
        isLoading = true
        ApiService.fetchLeaderboard { ranks in
            DispatchQueue.main.async {
                self.leaderboard = ranks
                self.isLoading = false
            }
        }
    }
    
    private var gradientBackground: some View {
        LinearGradient(colors: [.blue.opacity(0.9), .black, .orange.opacity(0.6)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }
}

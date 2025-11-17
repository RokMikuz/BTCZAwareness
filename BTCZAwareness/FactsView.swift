import SwiftUI

struct FactsView: View {
    @State private var facts: [String] = []
    @State private var currentFact = ""
    @State private var isLoading = false
    @State private var lastReward = 0
    
    var body: some View {
        ZStack {
            gradientBackground
            
            VStack(spacing: 30) {
                Text("BTCZ Fun Facts")
                    .font(.largeTitle)
                    .bold()
                    .foregroundStyle(.orange)
                
                if isLoading {
                    ProgressView("Loading...")
                        .scaleEffect(1.5)
                        .foregroundStyle(.white)
                } else if currentFact.isEmpty {
                    Text("Tap for a random BTCZ fact!")
                        .foregroundStyle(.white.opacity(0.8))
                        .italic()
                } else {
                    VStack(spacing: 20) {
                        Text(currentFact)
                            .font(.title2)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.orange.opacity(0.5), lineWidth: 1))
                        
                        if lastReward > 0 {
                            Text("You earned +\(lastReward) BTCZ!")
                                .font(.headline)
                                .foregroundStyle(.green)
                                .padding(10)
                                .background(.green.opacity(0.2))
                                .cornerRadius(12)
                        }
                        
                        HStack(spacing: 30) {
                            Button("Share on X") {
                                shareOnX()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                            .controlSize(.small)
                            
                            Button("Share on FB") {
                                shareOnFB()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                            .controlSize(.small)
                        }
                    }
                }
                
                Button("Random Fun Fact") {
                    loadFacts()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.orange)
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Fun Facts")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadFacts() }
        .refreshable { loadFacts() }
    }
    
    private func loadFacts() {
        isLoading = true
        ApiService.fetchFunFacts { fetchedFacts in
            DispatchQueue.main.async {
                self.facts = fetchedFacts
                self.currentFact = fetchedFacts.randomElement() ?? "BTCZ is awesome!"
                self.isLoading = false
            }
        }
    }
    
    private func shareOnX() {
        lastReward = Int.random(in: 2...7)
        ApiService.completeTask(taskId: "201") { success in // uporabi enega od taskov ali naredi novega
            DispatchQueue.main.async {
                if success {
                    PointsManager.shared.syncWithServer()
                }
            }
        }
        let url = URL(string: "https://twitter.com/intent/tweet?text=\(currentFact.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")%20%23BTCZ%20https://getbtcz.com")!
        UIApplication.shared.open(url)
    }
    
    private func shareOnFB() {
        lastReward = Int.random(in: 2...7)
        ApiService.completeTask(taskId: "201") { success in
            DispatchQueue.main.async {
                if success {
                    PointsManager.shared.syncWithServer()
                }
            }
        }
        let url = URL(string: "https://www.facebook.com/sharer/sharer.php?u=https://getbtcz.com&quote=\(currentFact.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!
        UIApplication.shared.open(url)
    }
    
    private var gradientBackground: some View {
        LinearGradient(colors: [.blue.opacity(0.9), .black, .orange.opacity(0.6)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }
}

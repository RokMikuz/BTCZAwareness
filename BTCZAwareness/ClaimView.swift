import SwiftUI

struct ClaimView: View {
    @State private var amount = ""
    @State private var isSubmitting = false
    @State private var message = ""
    
    private let savedAddress = UserDefaults.standard.string(forKey: "savedBTCZAddress") ?? ""
    
    var body: some View {
        ZStack {
            gradientBackground
                        VStack(spacing: 30) {
                Text("Claim BTCZ")
                    .font(.largeTitle)
                    .bold()
                    .foregroundStyle(.orange)
                    .padding(.top)
                
                // ADDRESS NAD OKNOM
                if savedAddress.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.orange)
                        
                        Text("No Wallet Verified!")
                        .font(.largeTitle)
                        .bold()
                        .foregroundStyle(.white)
                        
                        Text("Add your BTCZ wallet to claim rewards.")
                            .foregroundStyle(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        NavigationLink("Go to Wallet") {
                            WalletView()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(.orange)
                    }
                } else {
                    VStack(spacing: 15) {
                        Text("Your Wallet Address")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.9))
                        
                        Text(savedAddress)
                            .font(.monospaced(.body)())
                            .foregroundStyle(.white)
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                            .padding(.horizontal)
                        
                        Text("Available: \(PointsManager.shared.currentPoints) BTCZ")
                            .font(.title)
                            .bold()
                            .foregroundStyle(.green)
                        
                        TextField("Amount (min 50)", text: $amount)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal)
                        
                        Button("Submit Claim") {
                            submitClaim()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(.orange)
                        .disabled(isSubmitting || Int(amount) ?? 0 < 50)
                        
                        if isSubmitting { ProgressView("Submitting...") }
                        if !message.isEmpty {
                            Text(message)
                                .font(.title3)
                                .foregroundStyle(message.contains("success") ? .green : .red)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Claim")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { PointsManager.shared.syncWithServer() }
    }
    
    private func submitClaim() {
        guard let claimAmount = Int(amount), claimAmount >= 50 else { return }
        isSubmitting = true
        message = "Submitting claim..."

        // POPRAVLJENO – nova metoda iz ApiService
        ApiService.claim(amount: claimAmount) { success, msg, newPoints in
            DispatchQueue.main.async {
                isSubmitting = false
                message = success ? "Claim submitted successfully!" : (msg ?? "Failed")
                if success {
                    amount = ""
                    PointsManager.shared.currentPoints = newPoints  // posodobi lokalno
                    PointsManager.shared.syncWithServer()
                }
            }
        }
    }
    
    private var gradientBackground: some View {
        LinearGradient(colors: [.blue.opacity(0.9), .black, .orange.opacity(0.6)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }
}

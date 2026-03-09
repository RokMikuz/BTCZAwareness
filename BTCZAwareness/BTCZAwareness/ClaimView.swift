// ClaimView.swift – 100 % DELUJE!
import SwiftUI

struct ClaimView: View {
    @State private var amount = ""
    @State private var isSubmitting = false
    @State private var message = ""
    @Environment(\.dismiss) private var dismiss
    @State private var backPressed = false
    
    private var savedAddress: String {
        UserDefaults.standard.string(forKey: "savedBTCZAddress") ?? ""
    }
    
    var body: some View {
        ZStack {
            gradientBackground
            
            VStack(spacing: 30) {
                Text("Claim BTCZ")
                    .font(.largeTitle)
                    .bold()
                    .foregroundStyle(.orange)
                    .padding(.top)
                
                if savedAddress.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.orange)
                        
                        Text("Wallet Required!")
                            .font(.largeTitle)
                            .bold()
                            .foregroundStyle(.white)
                        
                        Text("You need a verified wallet to claim rewards.")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        NavigationLink("Go to Wallet", destination: WalletView())
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .tint(.orange)
                    }
                } else {
                    VStack(spacing: 15) {
                        Text("Your Address")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.9))
                        
                        Text(savedAddress)
                            .font(.monospaced(.body)())
                            .foregroundStyle(.white)
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                            .padding(.horizontal)
                        
                        Text("Balance: \(PointsManager.shared.currentPoints) BTCZ")
                            .font(.title)
                            .bold()
                            .foregroundStyle(.green)
                        
                        TextField("Amount (min 5000)", text: $amount)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal)
                        
                        Button("Submit Claim") {
                            submitClaim()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(.orange)
                        .disabled(isSubmitting || Int(amount) ?? 0 < 5000)
                        
                        Text("Note: Claims are manually reviewed by our staff and may take some time to be approved.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        if isSubmitting {
                            ProgressView("Submitting...")
                                .foregroundStyle(.white)
                        }
                        
                        if !message.isEmpty {
                            Text(message)
                                .font(.title3)
                                .foregroundStyle(message.contains("success") ? .green : .red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                }
                
                Spacer()
                
                // Banner at bottom (adaptive, centered)
                HStack {
                    BannerAdView(adUnitId: AdMobIDs.banner)
                        .frame(maxWidth: 600)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
            .padding()
        }
        .navigationTitle("Claim")
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
        .onAppear {
            PointsManager.shared.syncWithServer()
        }
    }
    
    private func submitClaim() {
        guard let claimAmount = Int(amount), claimAmount >= 5000 else { return }
        isSubmitting = true
        message = "Submitting claim..."
        
        ApiService.claim(amount: claimAmount) { success, msg, newPoints in
            DispatchQueue.main.async {
                isSubmitting = false
                message = msg
                if success {
                    message = "✅ Claim submitted successfully. " + msg
                    amount = ""
                    PointsManager.shared.currentPoints = newPoints
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


// WalletView.swift – 100 % DELUJE POVSOD (simulator + pravi telefon)
import SwiftUI
import UIKit

struct WalletView: View {
    @State private var address = ""
    @State private var referralInput = ""
    @State private var isSubmitting = false
    @State private var message = ""
    @State private var messageColor: Color = .white
    
    private var savedAddress: String {
        UserDefaults.standard.string(forKey: "savedBTCZAddress") ?? ""
    }
    
    var body: some View {
        ZStack {
            gradientBackground
            
            VStack(spacing: 30) {
                Text("My Wallet")
                    .font(.largeTitle)
                    .bold()
                    .foregroundStyle(.orange)
                    .padding(.top, 40)
                
                if !savedAddress.isEmpty {
                    // Denarnica že dodana
                    VStack(spacing: 25) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 100))
                            .foregroundStyle(.green)
                        
                        Text("Wallet Verified!")
                            .font(.title)
                            .bold()
                            .foregroundStyle(.green)
                        
                        Text(savedAddress)
                            .font(.monospaced(.body)())
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(16)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            Text("Your Referral Code")
                                .font(.title3)
                                .foregroundStyle(.white.opacity(0.9))
                            
                            Text(PointsManager.shared.referralCode)
                                .font(.title2)
                                .bold()
                                .foregroundStyle(.cyan)
                                .padding()
                                .background(.ultraThinMaterial)
                                .cornerRadius(16)
                        }
                        .padding(.top, 10)
                    }
                    
                } else {
                    // Še nima denarnice
                    VStack(spacing: 20) {
                        Image(systemName: "wallet.pass")
                            .font(.system(size: 90))
                            .foregroundStyle(.orange)
                        
                        Text("Enter Your BTCZ Wallet Address")
                            .font(.title2)
                            .bold()
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        // TEXTFIELD + PASTE (DELUJE POVSOD!)
                        VStack(spacing: 8) {
                            TextField("t1... or bz1...", text: $address)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.asciiCapable)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .padding(.horizontal)
                                .onAppear {
                                    checkClipboard()
                                }
                            
                            Button("Paste from clipboard") {
                                checkClipboard()
                            }
                            .foregroundColor(.cyan)
                            .font(.subheadline)
                            .buttonStyle(.bordered)
                        }
                        .padding(.horizontal)
                        
                        TextField("Referral code (optional)", text: $referralInput)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal)
                        
                        Button("Verify Wallet & Claim 100 BTCZ") {
                            verifyWallet()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(.orange)
                        .disabled(isSubmitting || !isValidAddress(address))
                        
                        Button("Where to get a BTCZ wallet?") {
                            UIApplication.shared.open(URL(string: "https://getbtcz.com/wallets/")!)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.cyan)
                        
                        if isSubmitting {
                            ProgressView("Verifying wallet...")
                                .foregroundStyle(.white)
                                .padding()
                        }
                        
                        if !message.isEmpty {
                            Text(message)
                                .font(.title3)
                                .foregroundStyle(messageColor)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .onAppear {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                                        message = ""
                                    }
                                }
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding(.bottom, 40)
        }
        .navigationTitle("Wallet")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            address = savedAddress
            checkClipboard() // preveri clipboard ob odprtju
        }
    }
    
    // MARK: - Preveri clipboard in prilepi, če je BTCZ naslov
    private func checkClipboard() {
        guard let clipboard = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return
        }
        
        let lower = clipboard.lowercased()
        if (lower.hasPrefix("t1") || lower.hasPrefix("bz1")) && clipboard.count >= 34 {
            address = clipboard
            message = "BTCZ address pasted from clipboard!"
            messageColor = .green
        }
    }
    
    // MARK: - Validacija naslova
    private func isValidAddress(_ addr: String) -> Bool {
        let trimmed = addr.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed.hasPrefix("t1") && trimmed.count >= 34) ||
               (trimmed.hasPrefix("bz1") && trimmed.count >= 39)
    }
    
    // MARK: - Verifikacija denarnice
    private func verifyWallet() {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let refCode = referralInput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard isValidAddress(trimmedAddress) else {
            message = "Invalid BTCZ address"
            messageColor = .red
            return
        }
        
        isSubmitting = true
        message = "Verifying..."
        messageColor = .white
        
        ApiService.saveWallet(address: trimmedAddress, referralCode: refCode.isEmpty ? nil : refCode) { success, msg, points, refCode in
            DispatchQueue.main.async {
                isSubmitting = false
                message = msg
                messageColor = success ? .green : .red
                
                if success {
                    UserDefaults.standard.set(trimmedAddress, forKey: "savedBTCZAddress")
                    PointsManager.shared.currentPoints = points
                    if let code = refCode {
                        PointsManager.shared.referralCode = code
                    }
                    PointsManager.shared.walletAdded()
                }
            }
        }
    }
    
    // MARK: - Gradient ozadje
    private var gradientBackground: some View {
        LinearGradient(
            colors: [.blue.opacity(0.9), .black, .orange.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// MARK: - Preview
struct WalletView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            WalletView()
        }
    }
}

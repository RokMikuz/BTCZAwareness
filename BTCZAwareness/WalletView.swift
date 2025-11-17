// WalletView.swift – 100 % CELOTNA – VRHUNSKO LEPA, ANIMIRANA – V ANGLEŠČINI!
import SwiftUI
import UIKit

struct WalletView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var backPressed = false

    @State private var address = ""
    @State private var referralInput = ""
    @State private var isSubmitting = false
    @State private var message = ""
    @State private var messageColor: Color = .white
    @State private var scale = 1.0 // za animacijo točk
    @State private var showVerifySpark = false

    private var savedAddress: String {
        UserDefaults.standard.string(forKey: "savedBTCZAddress") ?? ""
    }
    
    var body: some View {
        ZStack {
            // BOLJ ŽIVAHEN GRADIENT OZADJE
            LinearGradient(
                colors: [.purple.opacity(0.9), .black, .indigo.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                
                // NASLOV + IKONA
                VStack(spacing: 10) {
                    Text("My Wallet")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [.white.opacity(0.95), .white.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 2)
                }
                
                if !savedAddress.isEmpty {
                    // VERIFIED WALLET – ANIMIRANA
                    VStack(spacing: 30) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 100))
                            .foregroundStyle(.green)
                            .symbolEffect(.bounce, options: .repeating)
                        
                        Text("Wallet Verified!")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(colors: [.white.opacity(0.95), .white.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                        
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.green)
                            Text("Verified")
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1)
                        )
                        .clipShape(Capsule())
                        
                        Text(savedAddress)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(colors: [Color.white.opacity(0.08), Color.black.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .shadow(color: Color.black.opacity(0.35), radius: 14, x: 0, y: 8)
                                    .shadow(color: Color.black.opacity(0.25), radius: 5, x: 0, y: 2)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(
                                                LinearGradient(colors: [Color.white.opacity(0.28), Color.white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                                lineWidth: 1.5
                                            )
                                    )
                            )
                            .padding(.horizontal)
                        
                        // REFERRAL CODE SEKCIJA
                        VStack(spacing: 15) {
                            Text("Your Referral Code")
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(colors: [.white.opacity(0.95), .white.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 1)
                            
                            HStack {
                                Text(PointsManager.shared.referralCode)
                                    .font(.title2)
                                    .bold()
                                    .foregroundStyle(.cyan)
                                
                                Spacer()
                                
                                Button {
                                    UIPasteboard.general.string = PointsManager.shared.referralCode
                                    message = "Code copied!"
                                    messageColor = .green
                                } label: {
                                    Image(systemName: "doc.on.doc.fill")
                                        .font(.title2)
                                        .foregroundStyle(.cyan)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(LinearGradient(colors: [Color.white.opacity(0.08), Color.black.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 6)
                                    .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(LinearGradient(colors: [Color.white.opacity(0.28), Color.white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                                    )
                            )
                            
                            // SHARE GUMB – ANIMIRAN
                            Button {
                                shareReferralCode()
                            } label: {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Share Referral Code")
                                }
                                .font(.headline)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(LinearGradient(colors: [Color.cyan.opacity(0.9), Color.cyan.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .shadow(color: Color.cyan.opacity(0.45), radius: 10, x: 0, y: 6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                        )
                                )
                                .foregroundStyle(.black)
                                .cornerRadius(16)
                                .scaleEffect(scale)
                                .onAppear {
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                                        scale = 1.05
                                    }
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.3)) {
                                        scale = 1.0
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .overlay(
                        GeometryReader { geo in
                            ZStack {
                                if showVerifySpark {
                                    // Spark core
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 12, height: 12)
                                        .shadow(color: Color.green.opacity(0.8), radius: 10)
                                    // Spark rays
                                    ForEach(0..<7, id: \.self) { i in
                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color.green, Color.clear],
                                                    startPoint: .center,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(width: 28, height: 3)
                                            .rotationEffect(.degrees(Double(i) * (360.0/7.0)))
                                            .offset(x: 18)
                                            .opacity(0.95)
                                    }
                                    // Outer glow ring
                                    Circle()
                                        .stroke(Color.green.opacity(0.7), lineWidth: 2)
                                        .frame(width: 40, height: 40)
                                        .blur(radius: 0.5)
                                }
                            }
                            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                            .position(x: geo.size.width/2, y: 40) // near the checkmark icon
                        }
                    )
                } else {
                    // ENTER WALLET – ANIMIRAN
                    VStack(spacing: 30) {
                        Image(systemName: "wallet.pass")
                            .font(.system(size: 90))
                            .foregroundStyle(.orange)
                            .symbolEffect(.pulse, options: .repeating)
                        
                        Text("Enter Your BTCZ Wallet Address")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(colors: [.white.opacity(0.95), .white.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button {
                            if let url = URL(string: "https://getbtcz.com/wallets/") { UIApplication.shared.open(url) }
                        } label: {
                            HStack { Image(systemName: "link"); Text("Get a BTCZ Wallet") }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(.cyan)
                        
                        VStack(spacing: 15) {
                            TextField("add t1... address", text: $address)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.asciiCapable)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .padding(.horizontal)
                                .onAppear { checkClipboard() }
                            
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
                        
                        if isSubmitting {
                            ProgressView("Verifying...")
                                .foregroundStyle(.white)
                                .padding()
                        }
                        
                        if !message.isEmpty {
                            Text(message)
                                .font(.title3)
                                .foregroundStyle(messageColor)
                                .padding(.horizontal)
                                .onAppear {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                        message = ""
                                    }
                                }
                        }
                    }
                    .padding(.horizontal)
                }
                
            }
            .padding(.bottom, 80)
            .safeAreaInset(edge: .bottom) {
                HStack {
                    BannerAdView(adUnitId: AdMobIDs.banner)
                        .frame(maxWidth: 600)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .padding(.bottom, 8)
            }
        }
        .navigationTitle("Wallet")
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
            address = savedAddress
            checkClipboard()
            refreshWalletAddressFromServer()
            ApiService.getReferralStats { stats in
                DispatchQueue.main.async {
                    if let code = stats?["referral_code"] as? String, !code.isEmpty {
                        PointsManager.shared.referralCode = code
                    }
                }
            }
        }
    }
    
    private func checkClipboard() {
        guard let clipboard = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              (clipboard.lowercased().hasPrefix("t1") || clipboard.lowercased().hasPrefix("bz1")),
              clipboard.count >= 34 else { return }
        
        address = clipboard
        message = "Address pasted!"
        messageColor = .green
    }
    
    private func isValidAddress(_ addr: String) -> Bool {
        let trimmed = addr.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed.hasPrefix("t1") && trimmed.count >= 34) ||
               (trimmed.hasPrefix("bz1") && trimmed.count >= 39)
    }
    
    private func verifyWallet() {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let ref = referralInput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard isValidAddress(trimmed) else {
            message = "Invalid address"
            messageColor = .red
            return
        }
        
        isSubmitting = true
        message = "Verifying..."
        
        ApiService.saveWallet(address: trimmed, referralCode: ref.isEmpty ? nil : ref) { success, msg, points, code in
            DispatchQueue.main.async {
                isSubmitting = false
                message = msg
                messageColor = success ? .green : .red
                
                if success {
                    UserDefaults.standard.set(trimmed, forKey: "savedBTCZAddress")
                    if let code = code { PointsManager.shared.referralCode = code }
                    // Prefer server as source of truth for balance
                    PointsManager.shared.syncWithServer()
                    
                    withAnimation(.easeOut(duration: 0.25)) {
                        showVerifySpark = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        withAnimation(.easeOut(duration: 0.25)) {
                            showVerifySpark = false
                        }
                    }
                }
            }
        }
    }
    
    // SHARE REFERRAL CODE – ANIMIRAN
    private func shareReferralCode() {
        let code = PointsManager.shared.referralCode
        if code.isEmpty { return }
        
        let shareText = "Join BTCZ and get 50 BTCZ bonus! Use my referral code: \(code)\n\nhttps://btczkviz.btcz.rocks/register?ref=\(code)"
        
        let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true, completion: nil)
        }
    }
    
    private func refreshWalletAddressFromServer() {
        ApiService.getPoints { _ in
            let wa = UserDefaults.standard.string(forKey: "savedBTCZAddress") ?? ""
            if !wa.isEmpty {
                DispatchQueue.main.async {
                    self.address = wa
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


// BTCZAwarenessApp.swift – Z LEPEM SPLASH SCREENOM + ANIMIRANIM BTCZ LOGOM
import SwiftUI
import GoogleMobileAds
import UserMessagingPlatform

@main
struct BTCZAwarenessApp: App {
    // Stanje za splash screen
    @State private var showSplash = true
    
    init() {
        print("Začenjam inicializacijo app-a...")
        
        // 2) Registriraj uporabnika asinhrono
        DispatchQueue.global(qos: .background).async {
            ApiService.registerUserIfNeeded()
        }
        
        // 3) Prednaloži rewarded video po 30s (po inicializaciji oglasov)
        Task.detached(priority: .utility) {
            try? await Task.sleep(for: .seconds(30))
            await MainActor.run {
                RewardedVideoManager.shared.loadAd()
                print("Rewarded video prednaložen")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // GLAVNI CONTENT
                HomeView()
                    .opacity(showSplash ? 0 : 1)
                
                // SPLASH SCREEN
                if showSplash {
                    SplashScreenView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .onAppear {
                // Splash screen traja 3 sekunde
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        showSplash = false
                    }
                }
            }
            .task {
                await requestConsentAndStartAds()
            }
        }
    }
}

// ZAGONSKI EKRAN Z ANIMIRANIM BTCZ LOGOM
struct SplashScreenView: View {
    @State private var scale: CGFloat = 0.7
    @State private var opacity: Double = 0.0
    @State private var glowOpacity: Double = 0.0
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.indigo.opacity(0.95), .black, .purple.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // BTCZ LOGO Z ANIMACIJO
                Image("btcz_logo")  // tvoj logo v Assets
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .scaleEffect(scale)
                    .opacity(opacity)
                    .shadow(color: .yellow.opacity(glowOpacity), radius: 30)
                    .overlay(
                        Circle()
                            .stroke(LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 8)
                            .scaleEffect(glowOpacity > 0.5 ? 1.4 : 1.0)
                            .opacity(glowOpacity > 0.5 ? 0.8 : 0)
                    )
                
                Text("BTCZ Awareness")
                    .font(.largeTitle.bold())
                    .foregroundStyle(
                        LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
                    )
                    .opacity(opacity)
                
                Spacer()
                
                // LOADING DOTS
                HStack(spacing: 12) {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(.orange)
                            .frame(width: 14, height: 14)
                            .scaleEffect(opacity)
                            .opacity(opacity)
                            .animation(
                                Animation.easeInOut(duration: 0.6)
                                    .repeatForever()
                                    .delay(Double(i) * 0.2),
                                value: opacity
                            )
                    }
                }
                .padding(.bottom, 100)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2)) {
                scale = 1.0
                opacity = 1.0
            }
            
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowOpacity = 1.0
            }
        }
    }
}

extension BTCZAwarenessApp {
    private func rootViewController() -> UIViewController? {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .windows.first { $0.isKeyWindow }?.rootViewController
    }
    
    @MainActor
    fileprivate func requestConsentAndStartAds() async {
        let params = RequestParameters()
        params.isTaggedForUnderAgeOfConsent = false
        
        // Update consent info
        await withCheckedContinuation { continuation in
            ConsentInformation.shared.requestConsentInfoUpdate(with: params) { error in
                if let error = error { print("[UMP] requestConsentInfoUpdate error: \(error.localizedDescription)") }
                continuation.resume()
            }
        }
        
        let presenterVC = rootViewController()
        
        // Present form if required
        if let presenter = presenterVC {
            await withCheckedContinuation { continuation in
                ConsentForm.loadAndPresentIfRequired(from: presenter) { formError in
                    if let formError = formError { print("[UMP] form error: \(formError.localizedDescription)") }
                    continuation.resume()
                }
            }
        }
        
        // Start AdMob after consent flow
        MobileAds.shared.start { status in
            DispatchQueue.main.async { print("AdMob initialized! Status: \(status)") }
        }
    }
}

#Preview {
    SplashScreenView()
}

// LaunchScreenView.swift – ZAGONSKI EKRAN Z ANIMIRANIM BTCZ LOGOM
import SwiftUI

struct LaunchScreenView: View {
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.0
    @State private var glowOpacity: Double = 0.0
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.indigo.opacity(0.95), .black],
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
                    .frame(width: 200, height: 200)
                    .scaleEffect(scale)
                    .opacity(opacity)
                    .overlay(
                        Circle()
                            .stroke(LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 8)
                            .scaleEffect(glowOpacity > 0.5 ? 1.4 : 1.0)
                            .opacity(glowOpacity > 0.5 ? 0.8 : 0)
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: glowOpacity)
                    )
                
                Text("BTCZ Awareness")
                    .font(.largeTitle.bold())
                    .foregroundStyle(
                        LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
                    )
                    .opacity(opacity)
                
                Spacer()
                
                Text("Loading...")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.7))
                    .opacity(opacity)
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

#Preview {
    LaunchScreenView()
}

import SwiftUI

public struct AppBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public init() {}
    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color.indigo.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
            // Soft aurora bands
            auroraBand(angle: -22, yOffset: -120, color: .purple)
            auroraBand(angle: -8, yOffset: 20, color: .pink)
            auroraBand(angle: 16, yOffset: 180, color: .blue)
            // Subtle glass layers
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 40)
                    .fill(.ultraThinMaterial)
                    .frame(width: 220 + CGFloat(i) * 40, height: 90 + CGFloat(i) * 20)
                    .rotationEffect(.degrees(Double(-10 + i * 7)))
                    .offset(x: CGFloat(-140 + i * 120), y: CGFloat(-220 + i * 160))
                    .opacity(0.10)
                    .blur(radius: 1.5)
                    .modifier(DriftAnimation(enabled: !reduceMotion, speed: 10 + Double(i) * 4, amplitude: 10 + CGFloat(i) * 6))
            }
            // Particles
            ForEach(0..<10, id: \.self) { i in
                Circle()
                    .fill(
                        RadialGradient(colors: [Color.orange.opacity(0.22), .clear], center: .center, startRadius: 0, endRadius: 44)
                    )
                    .frame(width: 90, height: 90)
                    .opacity(0.5)
                    .modifier(ParticleDrift(index: i, enabled: !reduceMotion))
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func auroraBand(angle: Double, yOffset: CGFloat, color: Color) -> some View {
        LinearGradient(
            colors: [color.opacity(0.18), .clear],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(height: 260)
        .rotationEffect(.degrees(angle))
        .offset(x: 0, y: yOffset)
        .blendMode(.screen)
        .modifier(SlowOscillation(enabled: !reduceMotion, duration: 12, xAmp: 60, yAmp: 16))
    }
}

public struct AppBackgroundModifier: ViewModifier {
    public init() {}
    public func body(content: Content) -> some View {
        ZStack {
            AppBackground()
            content
        }
    }
}

public extension View {
    func appBackground() -> some View { self.modifier(AppBackgroundModifier()) }
}

// MARK: - Animation modifiers
fileprivate struct SlowOscillation: ViewModifier {
    let enabled: Bool
    let duration: Double
    let xAmp: CGFloat
    let yAmp: CGFloat
    @State private var t: CGFloat = 0
    func body(content: Content) -> some View {
        content
            .offset(x: enabled ? CGFloat(sin(Double(t))) * xAmp : 0, y: enabled ? CGFloat(cos(Double(t * 0.8))) * yAmp : 0)
            .onAppear {
                guard enabled else { return }
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: true)) { t = .pi * 2 }
            }
    }
}

fileprivate struct DriftAnimation: ViewModifier {
    let enabled: Bool
    let speed: Double
    let amplitude: CGFloat
    @State private var t: CGFloat = 0
    func body(content: Content) -> some View {
        content
            .offset(x: enabled ? CGFloat(sin(Double(t))) * amplitude : 0, y: enabled ? CGFloat(cos(Double(t * 0.7))) * amplitude : 0)
            .onAppear {
                guard enabled else { return }
                withAnimation(.linear(duration: speed).repeatForever(autoreverses: true)) { t = .pi * 2 }
            }
    }
}

fileprivate struct ParticleDrift: ViewModifier {
    let index: Int
    let enabled: Bool
    @State private var phase: CGFloat = 0
    func body(content: Content) -> some View {
        content
            .offset(x: xPos, y: yPos)
            .scaleEffect(scale)
            .onAppear {
                guard enabled else { return }
                withAnimation(.easeInOut(duration: 8 + Double(index) * 0.6).repeatForever(autoreverses: true)) { phase = .pi * 2 }
            }
    }
    private var xPos: CGFloat {
        let base = CGFloat(-180 + (index * 36))
        return base + (enabled ? CGFloat(sin(Double(phase + CGFloat(index)))) * 24 : 0)
    }
    private var yPos: CGFloat {
        let base = CGFloat(-360 + (index * 72) % 480)
        return base + (enabled ? CGFloat(cos(Double(phase * 0.9 + CGFloat(index)))) * 20 : 0)
    }
    private var scale: CGFloat { enabled ? 0.85 + CGFloat((index % 3)) * 0.06 : 0.9 }
}

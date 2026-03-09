//
//  SparkleEffect.swift
//  BTCZAwareness
//
//  Created by Rok on 25. 12. 25.
//

// SparkleEffect.swift – SKUPNI SPARKLE EFFECT ZA CELO APP
import SwiftUI

struct SparkleEffect: View {
    @State private var sparkle = false
    
    var body: some View {
        ZStack {
            ForEach(0..<20) { _ in
                Circle()
                    .fill(.yellow)
                    .frame(width: 6, height: 6)
                    .scaleEffect(sparkle ? 0 : 1)
                    .opacity(sparkle ? 0 : 1)
                    .offset(x: CGFloat.random(in: -150...150), y: CGFloat.random(in: -200...0))
                    .animation(.easeOut(duration: 1.5).delay(Double.random(in: 0...0.5)), value: sparkle)
            }
        }
        .onAppear {
            sparkle = true
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        SparkleEffect()
    }
}

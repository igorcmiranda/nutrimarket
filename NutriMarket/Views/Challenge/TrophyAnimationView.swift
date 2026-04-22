import SwiftUI

struct TrophyAnimationView: View {
    let trophy: Trophy
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 0.1
    @State private var opacity: Double = 0
    @State private var particlesVisible = false
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()

            VStack(spacing: 24) {
                // Partículas
                ZStack {
                    if particlesVisible {
                        ForEach(0..<20, id: \.self) { i in
                            Circle()
                                .fill(trophy.type.color.opacity(0.8))
                                .frame(width: CGFloat.random(in: 4...10),
                                       height: CGFloat.random(in: 4...10))
                                .offset(
                                    x: CGFloat.random(in: -150...150),
                                    y: CGFloat.random(in: -200...200)
                                )
                                .opacity(particlesVisible ? 0 : 1)
                                .animation(
                                    .easeOut(duration: 1.5)
                                    .delay(Double(i) * 0.05),
                                    value: particlesVisible
                                )
                        }
                    }

                    // Troféu principal
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [trophy.type.color.opacity(0.3), .clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 100
                                )
                            )
                            .frame(width: 200, height: 200)

                        Image(systemName: trophy.type.icon)
                            .font(.system(size: 80))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: trophy.type.animationColor,
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .rotationEffect(.degrees(rotation))
                            .scaleEffect(scale)
                            .opacity(opacity)
                            .shadow(color: trophy.type.color.opacity(0.8), radius: 20)
                    }
                }
                .frame(height: 220)

                VStack(spacing: 12) {
                    Text("🎉 Parabéns!")
                        .font(.title).fontWeight(.black)
                        .foregroundStyle(.white)
                        .opacity(opacity)

                    Text(trophy.type.displayName)
                        .font(.title2).fontWeight(.bold)
                        .foregroundStyle(trophy.type.color)
                        .opacity(opacity)

                    Text(trophy.description)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .opacity(opacity)

                    Text("\(Int(trophy.points)) pontos conquistados")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .opacity(opacity)
                }

                Button {
                    onDismiss()
                } label: {
                    Text("Incrível! 🏆")
                        .fontWeight(.bold)
                        .padding(.horizontal, 40).padding(.vertical, 14)
                        .background(trophy.type.color)
                        .foregroundStyle(.black)
                        .clipShape(Capsule())
                        .shadow(color: trophy.type.color.opacity(0.5), radius: 10)
                }
                .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) {
                scale = 1.0
                opacity = 1.0
            }
            withAnimation(.easeInOut(duration: 2).repeatCount(3)) {
                rotation = 15
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                particlesVisible = true
            }
        }
    }
}

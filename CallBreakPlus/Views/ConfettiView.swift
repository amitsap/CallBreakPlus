import SwiftUI

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var animating = false

    private let colors: [Color] = [
        Color(red: 1.0, green: 0.84, blue: 0.0),
        Color(red: 0.92, green: 0.26, blue: 0.21),
        Color(red: 0.13, green: 0.59, blue: 0.95),
        Color(red: 0.30, green: 0.69, blue: 0.31),
        Color(red: 0.61, green: 0.15, blue: 0.69),
        Color(red: 1.0, green: 0.60, blue: 0.0),
        .white,
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    particle.shape
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size * particle.aspectRatio)
                        .rotationEffect(.degrees(animating ? particle.endRotation : 0))
                        .position(
                            x: animating ? particle.endX : particle.startX,
                            y: animating ? geo.size.height + 30 : particle.startY
                        )
                        .opacity(animating ? 0 : 1)
                }
            }
            .onAppear {
                particles = (0..<50).map { _ in
                    ConfettiParticle(
                        color: colors.randomElement()!,
                        startX: CGFloat.random(in: 0...geo.size.width),
                        startY: CGFloat.random(in: -40...(-10)),
                        endX: CGFloat.random(in: -40...(geo.size.width + 40)),
                        endRotation: Double.random(in: 180...720),
                        size: CGFloat.random(in: 5...10),
                        aspectRatio: CGFloat.random(in: 0.5...2.0),
                        shapeType: Int.random(in: 0...2)
                    )
                }

                withAnimation(.easeOut(duration: 3.0)) {
                    animating = true
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let startX: CGFloat
    let startY: CGFloat
    let endX: CGFloat
    let endRotation: Double
    let size: CGFloat
    let aspectRatio: CGFloat
    let shapeType: Int

    var shape: AnyShape {
        switch shapeType {
        case 0: AnyShape(Rectangle())
        case 1: AnyShape(Circle())
        default: AnyShape(RoundedRectangle(cornerRadius: 1))
        }
    }
}

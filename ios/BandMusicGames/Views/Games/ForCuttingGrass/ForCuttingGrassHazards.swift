import CoreGraphics
import Foundation

@MainActor
enum ForCuttingGrassHazards {
    static func tickCrickets(
        _ crickets: inout [ForCuttingGrassCricket],
        delta: CGFloat,
        now: TimeInterval,
        bounds: CGRect,
        cricketMs: Int
    ) {
        for i in crickets.indices {
            // Apply velocity decay
            crickets[i].position.x += crickets[i].velocity.dx * delta
            crickets[i].position.y += crickets[i].velocity.dy * delta
            crickets[i].velocity.dx *= 0.92
            crickets[i].velocity.dy *= 0.92

            // Bounds clamp
            crickets[i].position.x = max(bounds.minX, min(bounds.maxX, crickets[i].position.x))
            crickets[i].position.y = max(bounds.minY, min(bounds.maxY, crickets[i].position.y))

            // Time to hop?
            if now >= crickets[i].nextHopAt {
                let angle = CGFloat.random(in: 0..<(2 * .pi))
                let speed: CGFloat = 80
                crickets[i].velocity = CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed)
                crickets[i].nextHopAt = now + Double(cricketMs) / 1000.0 + Double.random(in: -0.2...0.2)
            }
        }
    }

    static func tickSkunks(
        _ skunks: inout [ForCuttingGrassSkunk],
        delta: CGFloat,
        now: TimeInterval,
        bounds: CGRect,
        mowerPos: CGPoint
    ) {
        for i in skunks.indices {
            skunks[i].position.x += skunks[i].velocity.dx * delta
            skunks[i].position.y += skunks[i].velocity.dy * delta

            // Alarm rises when mower is close
            let dx = skunks[i].position.x - mowerPos.x
            let dy = skunks[i].position.y - mowerPos.y
            let d  = sqrt(dx * dx + dy * dy)
            skunks[i].alarm = max(0, min(1, (200 - d) / 200))

            // Change direction periodically, faster if alarmed
            if now >= skunks[i].changeDirAt {
                let angle = CGFloat.random(in: 0..<(2 * .pi))
                let speed: CGFloat = 30 + skunks[i].alarm * 60
                skunks[i].velocity = CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed)
                let nextIn = skunks[i].alarm > 0.5 ? Double.random(in: 0.3...0.8) : Double.random(in: 1.5...3.0)
                skunks[i].changeDirAt = now + nextIn
            }

            // Bounds clamp
            skunks[i].position.x = max(bounds.minX, min(bounds.maxX, skunks[i].position.x))
            skunks[i].position.y = max(bounds.minY, min(bounds.maxY, skunks[i].position.y))
        }
    }
}

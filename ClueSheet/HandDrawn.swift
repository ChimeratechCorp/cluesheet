import SwiftUI

/// A mark the player makes on a card name, the way they would with a pen
/// on the paper pad.
enum NameMark: String, Codable {
    case crossedOut, circled

    /// Tapping a name goes: crossed out, then circled, then clear again.
    static func next(after mark: NameMark?) -> NameMark? {
        switch mark {
        case nil: return .crossedOut
        case .crossedOut: return .circled
        case .circled: return nil
        }
    }
}

/// Draws a name mark over a card name in a loose, hand-drawn stroke. Each
/// card gets its own slight wobble, the same every time it's drawn, so the
/// sheet doesn't look stamped.
struct NameMarkView: View {
    let mark: NameMark
    let seed: String

    @State private var drawn: CGFloat = 0

    var body: some View {
        shape
            .trim(from: 0, to: drawn)
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeOut(duration: 0.3)) { drawn = 1 }
            }
    }

    private var shape: AnyShape {
        let jitter = Jitter(seed)
        switch mark {
        case .crossedOut: return AnyShape(ScribbledLine(jitter: jitter))
        case .circled: return AnyShape(ScribbledLoop(jitter: jitter))
        }
    }

    private var color: Color {
        mark == .circled ? Theme.accent : Theme.ink.opacity(0.85)
    }
}

/// Repeatable "random" numbers from a card name. String.hashValue changes
/// from launch to launch, so this rolls its own.
struct Jitter {
    private var values: [CGFloat] = []

    init(_ seed: String) {
        var state: UInt64 = 1469598103934665603
        for byte in seed.utf8 {
            state = (state ^ UInt64(byte)) &* 1099511628211
        }
        for _ in 0..<8 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            values.append(CGFloat(state >> 33) / CGFloat(UInt32.max >> 1) * 2 - 1)
        }
    }

    /// A value between -1 and 1.
    subscript(i: Int) -> CGFloat { values[i % values.count] }
}

/// A quick pen stroke through the text: starts a little before it, ends a
/// little after, slightly tilted and never quite straight.
struct ScribbledLine: Shape {
    let jitter: Jitter

    func path(in rect: CGRect) -> Path {
        let y = rect.midY + 1
        let start = CGPoint(x: rect.minX - 4 - 2 * jitter[0], y: y + 2.5 * jitter[1])
        let end = CGPoint(x: rect.maxX + 4 + 2 * jitter[2], y: y + 2.5 * jitter[3])
        var path = Path()
        path.move(to: start)
        path.addCurve(to: end,
                      control1: CGPoint(x: rect.minX + rect.width * 0.3, y: y + 3 * jitter[4]),
                      control2: CGPoint(x: rect.minX + rect.width * 0.7, y: y + 3 * jitter[5]))
        return path
    }
}

/// A loop drawn around the text in one go: a little lopsided, tilted, and
/// overshooting where it started rather than closing neatly.
struct ScribbledLoop: Shape {
    let jitter: Jitter

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let rx = rect.width / 2 + 8
        let ry = rect.height / 2 + 5
        let tilt = 0.05 * jitter[0]
        let start = -2.4 + 0.4 * jitter[1]
        let sweep = 2 * CGFloat.pi + 0.5 + 0.2 * jitter[2]
        let phase = 3 * jitter[3]
        let steps = 48

        var path = Path()
        for step in 0...steps {
            let t = CGFloat(step) / CGFloat(steps)
            let angle = start + sweep * t
            // Wobble a little, and widen as the pen goes round so the end
            // passes outside the start.
            let r = 1 + 0.035 * sin(3 * angle + phase) + 0.07 * t
            let x = rx * r * cos(angle)
            let y = ry * r * sin(angle)
            let point = CGPoint(x: center.x + x * cos(tilt) - y * sin(tilt),
                                y: center.y + x * sin(tilt) + y * cos(tilt))
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}

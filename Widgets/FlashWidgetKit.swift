import SwiftUI
import UIKit
import WidgetKit

// Every widget below is a faithful port of the 132x132 preview tiles on the app's
// WIDGETS screen. Authoring at that size and scaling keeps the proportions identical
// at every widget size instead of drifting into "roughly similar".
struct WidgetScale {
    static let design: CGFloat = 132
    let side: CGFloat
    var k: CGFloat { side / WidgetScale.design }
    func s(_ v: CGFloat) -> CGFloat { v * k }
}

/// The FLASH bolt, read from the widget target's asset catalog.
/// Accepts either name so it works whether the image set is called `FlashBolt` or keeps
/// the file's own name — an extension has its own catalog, so it must live in THIS target.
struct FlashBolt: View {
    var height: CGFloat

    private static let name: String = {
        for candidate in ["FlashBolt", "flash-bolt-on-dark", "flash-bolt"] {
            if UIImage(named: candidate) != nil { return candidate }
        }
        return "FlashBolt"
    }()

    var body: some View {
        Image(FlashBolt.name)
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(height: height)
    }
}

/// The three concentric "broadcast" rings from the tap tile and the QR badge.
/// Widgets are static snapshots — no animation — so the pulse is rendered as three
/// fixed rings stepped in scale and opacity, which is what the animation reads as.
struct PulseRings: View {
    var lineWidth: CGFloat
    var accent: Color

    var body: some View {
        ZStack {
            Circle().strokeBorder(Color(hex: 0xFFF204).opacity(0.85), lineWidth: lineWidth)
                .scaleEffect(1.0)
            Circle().strokeBorder(accent.opacity(0.60), lineWidth: lineWidth)
                .scaleEffect(0.80)
            Circle().strokeBorder(Color(hex: 0x050505).opacity(0.50), lineWidth: lineWidth)
                .scaleEffect(0.62)
        }
    }
}

/// The black tile itself: 24pt radius, hairline ring, drop shadow.
struct WidgetTile<Content: View>: View {
    var scale: WidgetScale
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: scale.s(24), style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: scale.s(24), style: .continuous)
                    .strokeBorder(Color.white.opacity(0.45), lineWidth: scale.s(1.5))
            )
    }
}

/// The NFC wave, ported from the app's SVG:
///   M7 8.5    a5.5  5.5  0 0 1 0 7
///   M11.5 5.5 a10   10   0 0 1 0 13
///   M16 2.8   a14.5 14.5 0 0 1 0 18.4
///
/// Three nested arcs, each bulging RIGHT, all centred on y = 12 of a 24x24 box.
/// Built by sampling the real circle instead of Path.addArc: SwiftUI's `clockwise`
/// flag is inverted by the y-down coordinate space, which silently draws the major
/// arc (the long way round) and mirrors the whole mark.
struct NFCArcs: Shape {
    /// (startPoint.y, endPoint.y, x of both endpoints, radius) in design units
    private static let specs: [(x: CGFloat, y0: CGFloat, y1: CGFloat, r: CGFloat)] = [
        (7.0,  8.5, 15.5, 5.5),
        (11.5, 5.5, 18.5, 10.0),
        (16.0, 2.8, 21.2, 14.5),
    ]

    func path(in rect: CGRect) -> Path {
        let k = min(rect.width, rect.height) / 24
        var path = Path()

        for s in NFCArcs.specs {
            let midY = (s.y0 + s.y1) / 2
            let half = (s.y1 - s.y0) / 2
            // sweep-flag 1 with y pointing down bulges the arc toward +x,
            // so the centre sits to the LEFT of the chord
            let dx = sqrt(max(s.r * s.r - half * half, 0))
            let cx = s.x - dx
            let a0 = atan2(s.y0 - midY, s.x - cx)     // negative (above centre)
            let a1 = atan2(s.y1 - midY, s.x - cx)     // positive (below centre)

            let steps = 28
            for i in 0...steps {
                let a = a0 + (a1 - a0) * CGFloat(i) / CGFloat(steps)
                let p = CGPoint(x: (cx + s.r * cos(a)) * k,
                                y: (midY + s.r * sin(a)) * k)
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
        }
        return path
    }
}

extension WidgetConfiguration {
    /// iOS 17 pads widget content by ~16pt. These tiles are designed edge to edge, so the
    /// system margin is removed and the design's own 9pt inset is the only padding.
    func contentMarginsDisabledIfAvailable() -> some WidgetConfiguration {
        if #available(iOS 17.0, *) { return self.contentMarginsDisabled() }
        return self
    }
}

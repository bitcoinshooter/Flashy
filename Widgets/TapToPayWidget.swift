import WidgetKit
import SwiftUI

struct TapToPayEntry: TimelineEntry {
    let date: Date
    let accent: FlashAccent
    let accentColor: Color
}

struct TapToPayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TapToPayEntry {
        TapToPayEntry(date: Date(), accent: .green, accentColor: FlashAccent.green.color)
    }
    func getSnapshot(in context: Context, completion: @escaping (TapToPayEntry) -> Void) {
        completion(TapToPayEntry(date: Date(), accent: FlashSharedState.accent, accentColor: FlashSharedState.accentColor))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<TapToPayEntry>) -> Void) {
        completion(Timeline(entries: [TapToPayEntry(date: Date(), accent: FlashSharedState.accent, accentColor: FlashSharedState.accentColor)],
                            policy: .never))
    }
}

// Port of the TAP TO PAY preview: an accent bar with the bolt + ")) NFC" across the top,
// then RECEIVE and SEND as two equal tiles underneath. Three tap targets, three deep links.
struct TapToPayWidgetView: View {
    var entry: TapToPayEntry

    var body: some View {
        GeometryReader { geo in
            let sc = WidgetScale(side: min(geo.size.width, geo.size.height))
            VStack(spacing: sc.s(7)) {
                nfcBar(sc)
                    .frame(height: sc.s(54))
                HStack(spacing: sc.s(7)) {
                    actionTile(sc, label: "RECEIVE", receive: true, url: "flash://receive")
                    actionTile(sc, label: "SEND", receive: false, url: "flash://send")
                }
            }
            .padding(sc.s(9))
        }
        // A systemSmall widget has ONE tap target and ignores Link, so the whole tile has
        // to carry the destination. The Links below still resolve individually at
        // systemMedium, where iOS does allow several targets.
        .widgetURL(URL(string: "flash://nfc"))
    }

    // MARK: the accent bar

    private func nfcBar(_ sc: WidgetScale) -> some View {
        Link(destination: URL(string: "flash://nfc")!) {
            HStack(spacing: sc.s(7)) {
                ZStack {
                    PulseRings(lineWidth: sc.s(2), accent: entry.accentColor)
                    Circle()
                        .fill(Color(hex: 0x050505))
                        .frame(width: sc.s(38), height: sc.s(38))
                    FlashBolt(height: sc.s(22.5))
                }
                .frame(width: sc.s(46), height: sc.s(46))

                HStack(spacing: sc.s(4)) {
                    NFCArcs()
                        .stroke(Color.white, style: StrokeStyle(lineWidth: sc.s(2.4), lineCap: .round))
                        .frame(width: sc.s(17), height: sc.s(17))
                    Text("NFC")
                        .font(FlashTheme.display(sc.s(14)))
                        .tracking(sc.s(0.7))
                        .foregroundStyle(entry.accent.ink)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(entry.accentColor)
            .overlay(
                RoundedRectangle(cornerRadius: sc.s(16), style: .continuous)
                    .fill(
                        LinearGradient(colors: [Color.white.opacity(0.3), .clear],
                                       startPoint: .top, endPoint: .init(x: 0.5, y: 0.18))
                    )
                    .allowsHitTesting(false)
            )
            .clipShape(RoundedRectangle(cornerRadius: sc.s(16), style: .continuous))
        }
    }

    // MARK: RECEIVE / SEND

    private func actionTile(_ sc: WidgetScale, label: String, receive: Bool, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            VStack(spacing: sc.s(3)) {
                ArrowToLine(receive: receive)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: sc.s(2.1),
                                                            lineCap: .round, lineJoin: .round))
                    .frame(width: sc.s(16), height: sc.s(16))
                Text(label)
                    .font(FlashTheme.body(sc.s(9), weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: sc.s(16), style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: sc.s(16), style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
            )
        }
    }
}

/// Arrow into / out of a baseline — the app's receive and send glyphs.
struct ArrowToLine: Shape {
    var receive: Bool
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        if receive {
            p.move(to: CGPoint(x: w * 0.5, y: h * 0.145))
            p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.605))
            p.move(to: CGPoint(x: w * 0.325, y: h * 0.43))
            p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.605))
            p.addLine(to: CGPoint(x: w * 0.675, y: h * 0.43))
        } else {
            p.move(to: CGPoint(x: w * 0.5, y: h * 0.855))
            p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.395))
            p.move(to: CGPoint(x: w * 0.325, y: h * 0.57))
            p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.395))
            p.addLine(to: CGPoint(x: w * 0.675, y: h * 0.57))
        }
        let baseY = receive ? h * 0.81 : h * 0.19
        p.move(to: CGPoint(x: w * 0.19, y: baseY))
        p.addLine(to: CGPoint(x: w * 0.81, y: baseY))
        return p
    }
}

struct TapToPayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FlashTapToPay", provider: TapToPayProvider()) { entry in
            if #available(iOS 17.0, *) {
                TapToPayWidgetView(entry: entry)
                    .containerBackground(Color.black, for: .widget)
            } else {
                TapToPayWidgetView(entry: entry).background(Color.black)
            }
        }
        .configurationDisplayName("Tap to Pay")
        .description("NFC, receive and send from the home screen.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabledIfAvailable()
    }
}

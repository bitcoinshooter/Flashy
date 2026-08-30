import WidgetKit
import SwiftUI

struct PriceEntry: TimelineEntry {
    let date: Date
    let accent: FlashAccent
    /// The exact colour the app is using, straight from the App Group.
    let accentColor: Color
    let price: Double
    let symbol: String
    let changePct: Double
    let samples: [Double]

    /// Up runs in the user's accent; a fall is always red.
    var lineColor: Color { changePct < 0 ? FlashTheme.down : accentColor }
    var isDown: Bool { changePct < 0 }
}

/// Live price straight from Coinbase — the same public endpoints the home screen uses.
/// A widget extension may make its own network calls, so this does not depend on the app
/// having been opened recently.
enum PriceFeed {
    /// 24 hourly candles: newest price, the 24h move, and the sparkline in one request.
    /// Coinbase returns [[time, low, high, open, close, volume], ...], newest first.
    static func fetch(currency: String) async -> (price: Double, changePct: Double, samples: [Double])? {
        for code in [currency.uppercased(), "USD"] where !code.isEmpty {
            let url = URL(string: "https://api.exchange.coinbase.com/products/BTC-\(code)/candles?granularity=3600")!
            var req = URLRequest(url: url)
            req.timeoutInterval = 12
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                guard (response as? HTTPURLResponse)?.statusCode == 200,
                      let rows = try JSONSerialization.jsonObject(with: data) as? [[Double]],
                      rows.count > 2 else { continue }

                // oldest -> newest, capped at 24 hours, closing price is index 4
                let closes = rows.prefix(24).reversed().map { $0[4] }
                guard let first = closes.first, let last = closes.last, first > 0 else { continue }

                let lo = closes.min() ?? first, hi = closes.max() ?? first
                let span = max(hi - lo, 0.0001)
                // normalise into 0...1 with headroom so the line never touches the edges
                let samples = closes.map { 0.12 + 0.76 * (($0 - lo) / span) }

                return (last, (last - first) / first * 100, samples)
            } catch {
                continue
            }
        }
        return nil
    }
}

struct PriceProvider: TimelineProvider {
    /// Whatever we can show without the network: the app's last write, else the design's
    /// numbers. A widget showing $0 just looks broken.
    private func cached() -> PriceEntry {
        let p = FlashSharedState.price
        return PriceEntry(
            date: Date(),
            accent: FlashSharedState.accent,
            accentColor: FlashSharedState.accentColor,
            price: p > 0 ? p : 64_160,
            symbol: FlashSharedState.currencySymbol,
            changePct: p > 0 ? FlashSharedState.changePct : 1.94,
            samples: FlashSharedState.sparkline
        )
    }

    func placeholder(in context: Context) -> PriceEntry {
        PriceEntry(date: Date(), accent: .green, accentColor: FlashAccent.green.color,
                   price: 64_160, symbol: "$", changePct: 1.94, samples: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (PriceEntry) -> Void) {
        // The gallery preview stays instant — no waiting on a request.
        completion(cached())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PriceEntry>) -> Void) {
        Task {
            let base = cached()
            var entry = base

            if let live = await PriceFeed.fetch(currency: FlashSharedState.currencyCode) {
                entry = PriceEntry(date: Date(), accent: base.accent, accentColor: base.accentColor,
                                   price: live.price, symbol: base.symbol,
                                   changePct: live.changePct, samples: live.samples)
                // hand the fresh numbers to the app too, so both agree offline
                FlashSharedState.write(price: live.price, changePct: live.changePct,
                                       sparkline: live.samples)
            }

            // ~15 min is about as often as iOS will honour; asking for less burns the
            // refresh budget and gets throttled anyway.
            let next = Date().addingTimeInterval(15 * 60)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }
}

/// The preview's exact curve, normalised 0...1, used whenever the app has sent no samples.
enum PriceCurve {
    static let design: [Double] = [
        0.20, 0.22, 0.24, 0.26, 0.31, 0.39, 0.46, 0.55, 0.58,
        0.62, 0.65, 0.71, 0.79, 0.75, 0.64, 0.72, 0.77, 0.78
    ]
}

struct PriceSparkline: View {
    let samples: [Double]
    let color: Color

    private var pts: [Double] { samples.count > 1 ? samples : PriceCurve.design }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                closed(geo.size).fill(
                    LinearGradient(colors: [color.opacity(0.28), color.opacity(0)],
                                   startPoint: .top, endPoint: .bottom)
                )
                line(geo.size).stroke(
                    color,
                    style: StrokeStyle(lineWidth: max(geo.size.width * 0.0165, 1.4),
                                       lineCap: .round, lineJoin: .round)
                )
            }
        }
    }

    private func pt(_ i: Int, _ size: CGSize) -> CGPoint {
        let n = max(pts.count - 1, 1)
        return CGPoint(x: size.width * Double(i) / Double(n),
                       y: size.height * (1 - pts[i]))
    }
    private func line(_ size: CGSize) -> Path {
        var p = Path()
        p.move(to: pt(0, size))
        for i in 1..<pts.count {
            let a = pt(i - 1, size), b = pt(i, size)
            let midX = (a.x + b.x) / 2
            p.addCurve(to: b,
                       control1: CGPoint(x: midX, y: a.y),
                       control2: CGPoint(x: midX, y: b.y))
        }
        return p
    }
    private func closed(_ size: CGSize) -> Path {
        var p = line(size)
        p.addLine(to: CGPoint(x: size.width, y: size.height))
        p.addLine(to: CGPoint(x: 0, y: size.height))
        p.closeSubpath()
        return p
    }
}

// Port of the BITCOIN PRICE preview: bolt + BITCOIN label, price, change pill, and the
// sparkline bleeding into the bottom corners.
struct BitcoinPriceWidgetView: View {
    var entry: PriceEntry

    private var priceText: String {
        let n = NumberFormatter()
        n.numberStyle = .decimal
        n.maximumFractionDigits = 0
        return entry.symbol + (n.string(from: NSNumber(value: entry.price)) ?? "0")
    }

    var body: some View {
        GeometryReader { geo in
            let sc = WidgetScale(side: min(geo.size.width, geo.size.height))
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: sc.s(4)) {
                        FlashBolt(height: sc.s(10.5))
                        Text("BITCOIN")
                            .font(FlashTheme.body(sc.s(9), weight: .semibold))
                            .tracking(sc.s(0.9))
                            .foregroundStyle(Color.white.opacity(0.45))
                    }
                    Text(priceText)
                        .font(FlashTheme.display(sc.s(18)))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.top, sc.s(4))

                    HStack(spacing: sc.s(3)) {
                        ChevronArrow(up: !entry.isDown)
                            .stroke(entry.lineColor,
                                    style: StrokeStyle(lineWidth: sc.s(1.3),
                                                       lineCap: .round, lineJoin: .round))
                            .frame(width: sc.s(8), height: sc.s(8))
                        Text(String(format: "%.2f%%", abs(entry.changePct)))
                            .font(FlashTheme.body(sc.s(9), weight: .bold))
                            .foregroundStyle(entry.lineColor)
                    }
                    .padding(.horizontal, sc.s(6))
                    .frame(height: sc.s(18))
                    .background(Capsule().fill(entry.lineColor.opacity(0.16)))
                    .padding(.top, sc.s(4))
                }
                .padding(.horizontal, sc.s(11))
                .padding(.top, sc.s(11))

                Spacer(minLength: sc.s(4))

                // full-bleed: no side padding, so the fill meets the tile's corners
                PriceSparkline(samples: entry.samples, color: entry.lineColor)
                    .frame(height: sc.s(58))
            }
        }
        .widgetURL(URL(string: "flash://home"))
    }
}

struct ChevronArrow: Shape {
    var up: Bool
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        if up {
            p.move(to: CGPoint(x: w / 2, y: h)); p.addLine(to: CGPoint(x: w / 2, y: 0))
            p.move(to: CGPoint(x: 0, y: h * 0.5)); p.addLine(to: CGPoint(x: w / 2, y: 0))
            p.addLine(to: CGPoint(x: w, y: h * 0.5))
        } else {
            p.move(to: CGPoint(x: w / 2, y: 0)); p.addLine(to: CGPoint(x: w / 2, y: h))
            p.move(to: CGPoint(x: 0, y: h * 0.5)); p.addLine(to: CGPoint(x: w / 2, y: h))
            p.addLine(to: CGPoint(x: w, y: h * 0.5))
        }
        return p
    }
}

struct BitcoinPriceWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FlashBitcoinPrice", provider: PriceProvider()) { entry in
            if #available(iOS 17.0, *) {
                BitcoinPriceWidgetView(entry: entry)
                    .containerBackground(Color.black, for: .widget)
            } else {
                BitcoinPriceWidgetView(entry: entry).background(Color.black)
            }
        }
        .configurationDisplayName("Bitcoin Price")
        .description("Live price and today's move.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabledIfAvailable()
    }
}

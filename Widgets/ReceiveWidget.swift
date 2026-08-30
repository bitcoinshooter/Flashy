import WidgetKit
import SwiftUI
import CoreImage.CIFilterBuiltins

struct ReceiveEntry: TimelineEntry {
    let date: Date
    let accent: FlashAccent
    let accentColor: Color
    let address: String
}

struct ReceiveProvider: TimelineProvider {
    private func current() -> ReceiveEntry {
        ReceiveEntry(date: Date(), accent: FlashSharedState.accent,
                     accentColor: FlashSharedState.accentColor,
                     address: FlashSharedState.lightningAddress)
    }
    func placeholder(in context: Context) -> ReceiveEntry {
        ReceiveEntry(date: Date(), accent: .green, accentColor: FlashAccent.green.color,
                     address: "you@flashapp.me")
    }
    func getSnapshot(in context: Context, completion: @escaping (ReceiveEntry) -> Void) {
        completion(current())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ReceiveEntry>) -> Void) {
        completion(Timeline(entries: [current()], policy: .never))
    }
}

enum QRCode {
    /// High correction level, because the bolt badge covers the middle of the code.
    static func image(from string: String, scale: CGFloat = 12) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "H"
        guard let out = filter.outputImage?
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale)),
              let cg = CIContext().createCGImage(out, from: out.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

// Port of the YOUR LNURL preview: bolt + LNURL label, then a white QR panel with the
// bolt badge and its rings sitting in the centre of the code.
struct ReceiveWidgetView: View {
    var entry: ReceiveEntry

    private var lnurl: String { "lightning:" + entry.address }

    var body: some View {
        GeometryReader { geo in
            let sc = WidgetScale(side: min(geo.size.width, geo.size.height))
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: sc.s(4)) {
                    FlashBolt(height: sc.s(10.5))
                    Text("LNURL")
                        .font(FlashTheme.body(sc.s(9), weight: .semibold))
                        .tracking(sc.s(0.9))
                        .foregroundStyle(Color.white.opacity(0.55))
                }
                .padding(.horizontal, sc.s(11))
                .padding(.top, sc.s(9))

                ZStack {
                    RoundedRectangle(cornerRadius: sc.s(12), style: .continuous)
                        .fill(Color.white)
                    if let qr = QRCode.image(from: lnurl) {
                        Image(uiImage: qr)
                            .interpolation(.none)     // keep the modules crisp
                            .resizable()
                            .scaledToFit()
                            .padding(sc.s(5))
                    }
                    ZStack {
                        PulseRings(lineWidth: sc.s(1.5), accent: entry.accentColor)
                        Circle()
                            .fill(Color(hex: 0x050505))
                            .frame(width: sc.s(33), height: sc.s(33))
                        FlashBolt(height: sc.s(19.5))
                    }
                    .frame(width: sc.s(40), height: sc.s(40))
                }
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, sc.s(9))
                .padding(.top, sc.s(5))
                .padding(.bottom, sc.s(9))
            }
        }
        .widgetURL(URL(string: "flash://settings"))
    }
}

struct ReceiveWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FlashReceive", provider: ReceiveProvider()) { entry in
            if #available(iOS 17.0, *) {
                ReceiveWidgetView(entry: entry)
                    .containerBackground(Color.black, for: .widget)
            } else {
                ReceiveWidgetView(entry: entry).background(Color.black)
            }
        }
        .configurationDisplayName("Your LNURL")
        .description("Scan to pay you, from any wallet.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabledIfAvailable()
    }
}

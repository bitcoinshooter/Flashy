import Foundation
import SwiftUI

// The one seam between app and widgets.
//
// Set APP_GROUP to the App Group you enable on BOTH targets (the app and the widget
// extension), then have the app call FlashSharedState.write(...) whenever the accent,
// the price, or the user's Lightning address changes, and reload the timelines:
//
//     WidgetCenter.shared.reloadAllTimelines()
//
// Until the app writes anything the widgets render the defaults below, so they still
// look right on first install and in the widget gallery.
enum FlashSharedState {
    static let appGroup = "group.com.flash.app"      // <-- change to your App Group id

    private static var store: UserDefaults? { UserDefaults(suiteName: appGroup) }

    // MARK: read

    static var accent: FlashAccent {
        guard let raw = store?.string(forKey: "accent"),
              let a = FlashAccent(rawValue: raw) else { return .green }
        return a
    }

    /// The exact hex the page reported. Preferred over the enum so a palette tweak in
    /// the web app shows up in the widgets without a Swift change.
    static var accentColor: Color {
        if let hex = store?.string(forKey: "accentHex"), hex.count >= 6 { return Color(hex: hex) }
        return accent.color
    }
    static var accentLight: Color {
        if let hex = store?.string(forKey: "accentLtHex"), hex.count >= 6 { return Color(hex: hex) }
        return accent.light
    }

    /// Spot price in the user's display currency.
    static var price: Double { store?.double(forKey: "btcPrice") ?? 0 }

    static var currencySymbol: String { store?.string(forKey: "currencySymbol") ?? "$" }

    /// ISO code used to pick the Coinbase product (BTC-USD, BTC-EUR, BTC-GBP…).
    /// Anything Coinbase does not quote falls back to USD.
    static var currencyCode: String { store?.string(forKey: "currencyCode") ?? "USD" }

    /// Percentage move over the widget's window. Sign drives the line colour.
    static var changePct: Double { store?.double(forKey: "btcChangePct") ?? 0 }

    /// Normalised 0...1 samples, oldest first. Empty renders a flat line.
    static var sparkline: [Double] { store?.array(forKey: "btcSparkline") as? [Double] ?? [] }

    /// The LNURL / Lightning address the receive widget encodes.
    static var lightningAddress: String {
        store?.string(forKey: "lightningAddress") ?? "you@flashapp.me"
    }

    static var username: String { store?.string(forKey: "username") ?? "" }

    // MARK: write (call from the app)

    static func write(accent: FlashAccent? = nil,
                      accentId: String? = nil,
                      accentHex: String? = nil,
                      accentLtHex: String? = nil,
                      price: Double? = nil,
                      currencySymbol: String? = nil,
                      currencyCode: String? = nil,
                      changePct: Double? = nil,
                      sparkline: [Double]? = nil,
                      lightningAddress: String? = nil,
                      username: String? = nil) {
        guard let store else { return }
        if let accent { store.set(accent.rawValue, forKey: "accent") }
        if let accentId { store.set(accentId, forKey: "accent") }
        if let accentHex { store.set(accentHex, forKey: "accentHex") }
        if let accentLtHex { store.set(accentLtHex, forKey: "accentLtHex") }
        if let price { store.set(price, forKey: "btcPrice") }
        if let currencySymbol { store.set(currencySymbol, forKey: "currencySymbol") }
        if let currencyCode { store.set(currencyCode, forKey: "currencyCode") }
        if let changePct { store.set(changePct, forKey: "btcChangePct") }
        if let sparkline { store.set(sparkline, forKey: "btcSparkline") }
        if let lightningAddress { store.set(lightningAddress, forKey: "lightningAddress") }
        if let username { store.set(username, forKey: "username") }
    }
}

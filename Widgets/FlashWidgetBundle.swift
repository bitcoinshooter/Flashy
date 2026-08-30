import WidgetKit
import SwiftUI

// The widget extension's entry point. One bundle, three widgets — the same three
// shown on the WIDGETS screen in the prototype, in the same order.
@main
struct FlashWidgetBundle: WidgetBundle {
    var body: some Widget {
        TapToPayWidget()
        BitcoinPriceWidget()
        ReceiveWidget()
    }
}

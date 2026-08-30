# FLASH — iOS prototype

The FLASH prototype running as a real iOS app, plus three home-screen widgets
(Tap to Pay, Bitcoin Price, LNURL).

The app itself is a single self-contained web bundle (`App/Web/index.html`) inside a
WKWebView. The widgets are native SwiftUI.

---

## Run it on your phone

You need a Mac with **Xcode 15+**, an iPhone, a cable, and any Apple ID (a free one is fine).

```bash
git clone https://github.com/bitcoinshooter/Flashy.git
cd Flashy
./setup.sh
```

That downloads a prebuilt [XcodeGen](https://github.com/yonaskolb/XcodeGen) into a
gitignored `.tools/` folder, generates `FLASH.xcodeproj`, and opens Xcode. Nothing is
installed globally and Homebrew is not required — Xcode is the only prerequisite.

Then in Xcode:

1. **Pick your iPhone** in the device menu at the top.
2. Select the **FLASH** target → **Signing & Capabilities** → set **Team** to your Apple ID.
3. If Xcode says the bundle identifier is already taken, open **`Config.xcconfig`**, change
   `FLASH_BUNDLE_ID` to something unique (e.g. `com.yourname.flash`), then re-run `./setup.sh`.
4. Press **▶ Run**.
5. First launch only — on the iPhone: **Settings → General → VPN & Device Management** →
   tap the developer profile → **Trust**.

### Add the widgets

Long-press the home screen → **Edit** (top left) → **Add Widget** → search **FLASH** → add.

---

## Why there's no .xcodeproj in the repo

Project files store absolute paths, team ids and file UUIDs, so a committed one tends to
break on anyone else's machine. `project.yml` describes the project instead and
`xcodegen` builds it locally — the `.xcodeproj` is in `.gitignore` on purpose.

## Layout

```
project.yml            XcodeGen manifest (defines both targets)
Config.xcconfig        bundle id + team — the only file you edit
setup.sh               fetch xcodegen, generate, open
App/
    ├── FlashApp.swift     WKWebView host, deep links, haptics bridge
    ├── Info.plist         flash:// URL scheme, camera usage
    ├── Web/index.html     the entire prototype, self-contained
    └── Assets.xcassets    app icon
Shared/                in BOTH targets
    ├── FlashTheme.swift        the eight accents, fonts, colours
    └── FlashSharedState.swift  the App Group seam
Widgets/
    ├── FlashWidgetBundle.swift  the three widgets
    ├── FlashWidgetKit.swift     tile, scale, bolt, NFC arcs, pulse rings
    ├── TapToPayWidget.swift
    ├── BitcoinPriceWidget.swift live price straight from Coinbase
    ├── ReceiveWidget.swift      QR generated on device
    └── Assets.xcassets          FlashBolt
```

## How app and widgets talk

| What | Direction | Mechanism |
|---|---|---|
| Widget tap → a screen | widget → app | `flash://<target>` → `#flash=<target>` on the page |
| Accent / currency / LN address | app → widgets | page posts to Swift → App Group → `reloadAllTimelines()` |
| Haptics + sounds | page → app | `webkit.messageHandlers.flash` → Taptic engine |
| Bitcoin price | widget → internet | the widget fetches Coinbase candles itself |

Deep-link targets: `nfc`, `send`, `receive`, `home`, `settings`.
Test one without a widget: type `flash://send` into Safari on the phone.

---

## Optional: accent sync (needs a PAID Apple Developer account)

Out of the box the widgets use their default accent, because sharing state between an app
and its extension needs an **App Group**, and a free Apple ID can't sign one. Everything
else — live price, QR, deep links, haptics — works without this.

To turn it on:

1. In `project.yml`, uncomment both `CODE_SIGN_ENTITLEMENTS` lines.
2. Pick an App Group id you own and put the same value in all three places:
   `App/FLASH.entitlements`, `Widgets/FlashWidgets.entitlements`, and
   `appGroup` in `Shared/FlashSharedState.swift` (currently `group.com.flash.app`).
3. Enable **App Groups** on both targets in Signing & Capabilities.
4. `./setup.sh` again.

## Optional: the app's real fonts

The widgets ask for `Sora-ExtraBold` and `Figtree-SemiBold`; without them iOS substitutes
the system face at the same weights. To add them, drop the `.ttf` files into the
`Widgets` folder and list them under `UIAppFonts` in `Widgets/Info.plist`. (The web app
already loads its own fonts, so this only affects the widgets.)

## Notes

- No analytics, no tracking. The only network calls are the live Bitcoin price.
- iPhone only, portrait only, dark mode.
- Widgets cannot animate — WidgetKit renders them as static snapshots — so the NFC and
  ring pulses are drawn as a single frame.
- Updating the prototype is a one-file drop: replace `App/Web/index.html`.

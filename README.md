# tattoonow-app

The one TattooNOW iOS app. Native shell, two halves:

- **Member half** — the studio owner's / artist's dashboard, served from
  the `tattoonow-sites` admin in **phone mode** inside a `WKWebView`.
- **Register half** — the counter. Card-present payments on a PAX D135 and
  Tap to Pay on the phone, which is native code and the only reason this
  binary has to exist at all.

The plan this repo implements is
[`docs/TATTOONOW-APP-NATIVE-PLAN.md`](https://github.com/TattooNOW/tattoonow-sites/blob/dev/docs/TATTOONOW-APP-NATIVE-PLAN.md)
in `tattoonow-sites` (D-1: own repo). Decisions that bind the code here are
restated in [`docs/DECISIONS.md`](docs/DECISIONS.md) — read it before
writing a screen.

## Why a native binary at all

A PWA already does everything the member half needs. Two things it cannot
do, and both are the Register's:

1. **Tap to Pay / reader pairing.** No browser SDK supports it.
2. **APNs.** Web Push does not work inside a `WKWebView`, so a shell that
   wraps the web app has to register for native push itself.

Everything else stays web, in one place, so there is never a second
implementation of a screen.

## Build

The Xcode project is **generated**, never committed.

```sh
brew install xcodegen
xcodegen generate          # writes TattooNOW.xcodeproj from project.yml
open TattooNOW.xcodeproj
```

Add a file by putting it in `TattooNOW/` and re-running `xcodegen generate`.
Do not add it in Xcode's UI and commit the result.

## Configuration

`Config/Debug.xcconfig` and `Config/Release.xcconfig` set `TN_WEB_ORIGIN`
(dev admin host vs prod admin host). Everything else the app needs comes
from the web app over that origin.

🚨 **No credential of any kind belongs in this repo.** Not the EPX key, not
a Supabase key, not an API token. The EPX key is entered per-iPad and held
in the Keychain, device-only, excluded from backups; the server rejects an
attempt to store it.

## The contract with the web app

The shell appends `TattooNOWApp/1.0` to the WebView's user agent.
`tattoonow-sites` reads it to set `_inNativeApp`, which hides **every price
and every upgrade CTA**. That is not cosmetic: App Store guideline
3.1.3(f) permits the member half only as a free companion to a paid web
service, and only while nothing in the app sells and nothing points out to
where it would. Changing `userAgentSuffix` without changing the reader on
the other side silently re-exposes the prices.

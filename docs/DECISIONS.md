# Decisions that bind the code in this repo

Restated from
[`docs/TATTOONOW-APP-NATIVE-PLAN.md`](https://github.com/TattooNOW/tattoonow-sites/blob/dev/docs/TATTOONOW-APP-NATIVE-PLAN.md)
in `tattoonow-sites`, which owns them. Where this file and the plan
disagree, **the plan wins** — but each rule below is here because breaking
it is cheap to do and expensive to notice.

## The shape

- **D-1 — own repo.** This one. Native code never goes into
  `tattoonow-sites`: no Tap to Pay screen, no Terminal SDK, no reader
  pairing flow there.
- **D-9 — native chrome over a PHONE MODE of the admin.** The shell strips
  chrome, never features. There is no second implementation of a screen.
- **D-10 — ONE dashboard on web and app.** Same screens, same URLs.

## The two Apple rules that apply at once

- **3.1.3(e)** — counter charges and deposits are real-world goods and
  services, so they are **never** In-App Purchase. That is the Register.
- **3.1.3(f)** — the member half is permitted only as a free companion to
  a paid web service. 🚨 So `_inNativeApp` must hide **every price and
  every upgrade CTA**, and the app must not point out to where one could
  be bought. The mechanism is one string
  (`AppConfig.userAgentSuffix = "TattooNOWApp/1.0"`) read on the other
  side. Change one end, change both; a silent re-exposure of prices is a
  rejection whose cause is invisible in the diff.
- **4.2** — a thin wrapper is rejected. The native features that answer it
  (push, reader, camera) sit on later phases, so 🚨 **never submit after
  the shell alone** (G-22).
- **4.2.6 / 4.3** — ONE binary serving many studios is the shape Apple
  requires; a per-studio generated binary is rejected, and as of June 2026
  Apple can **remove already-live apps** under 4.3 and terminate the
  account. There will never be a per-client build.
- **4.8** — 🚨 **no Google sign-in in the app.** Adding it would oblige us
  to offer Sign in with Apple. It is also moot: Google OAuth is blocked in
  an embedded web view. Sign-in is **magic link or password**.
- **5.1.1(v)** — account deletion must be reachable in-app. It is
  `/admin/account` on the web side (shipped to dev; 🚨 confirm it is on
  prod before submitting).

## Credentials

🚨 **No credential of any kind is compiled into this binary or committed
to this repo.** Not a Supabase key, not a Stripe key, not an API token.

The **EPX key** is the sharp one. It can originate charges against the
merchant account, so:

- It is entered **per iPad**, held in the **iOS Keychain**, device-only,
  **excluded from backups**.
- The server **rejects** an attempt to store it, rather than silently
  ignoring it.
- Identity that is *not* the key (`epxId`, environment, merchant name,
  terminal number) is server-side and set in Settings. **Terminal number
  is per iPad, not per studio.**

The shell authenticates to our own origin by reusing the **WebView's
session cookie**, so it holds nothing of its own.

## The payment path, and why rejecting early is unsafe

🚨 **Our server is not in the authorisation path.** The reader authorises
directly with EPX, so by the time our API is called **the card has already
been charged**. Therefore:

- Every attempt is written to an append-only log **before** any rejection
  that could follow a real capture.
- A sale with no `AUTH_GUID` is refused — there is nothing to reconcile or
  refund against.
- A bookkeeping failure **after** a capture raises a blocking screen
  saying the card **was** charged, with the reference. 🚨 It must never
  resemble a decline: a cashier who reads "failed" after a real capture
  runs the card again.

Hardware facts that are physics, not choices: the **D135 has no display**
(so the tip is taken on the iPad and lands as an artist-attributed ticket
line, which is the only way it reaches commission), it is **Bluetooth
only** (so a native app is mandatory and there is no browser fallback),
and **PIN is entered on the iPad**.

## Open before the Register ships

- **O-1 — which North SDK.** The 13 Swift files in
  `tattoonow-business-suite/ios/` target North's **PAX Mobile SDK**, but
  **Tap to Pay lives in North's separate Gateway iOS SDK** (which also
  drives the D135). That choice comes before any more Swift. Ask the North
  rep. Those legacy files have **never been compiled**; they are reference,
  and HANDS-OFF Rule 1 makes that repo read-only.
- **O-5 — the gate key is undecided.** The admin mockup calls the Register
  tab `money`; REGISTER-APP-INTEGRATION calls it `payments`. 🚨 **Neither
  is declared in `lib/entitlements.ts`**, so today it is gated by nothing.
- **O-9 — the privacy notice has had no legal review**, and the nutrition
  labels in `PrivacyInfo.xcprivacy` are unfilled because of it. Blocks
  submission.

## What `tattoonow-sites` owes this repo

1. **Read `TattooNOWApp/1.0` off the user agent and set `_inNativeApp`**,
   hiding every price and upgrade CTA — with a smoke test, because the
   failure is invisible. **Not built.**
2. `POST /api/admin/push/apns` to accept a device token.
   **Does not exist**; `PushRegistrar` reports the failure rather than
   pretending.
3. Promote the mobile/member work, the S-10 permission layer and
   `/admin/account` to **prod**. Submission needs them live.

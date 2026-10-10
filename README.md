# Dahab — Flutter Web UI prototype

A Flutter Web reproduction of the Dahab customer app prototype
(`doc/dahab-app-prototype.html`).

**Connected to the backend:** registration and sign-in (`/customer/auth/*`),
the wallet and top-ups (`/customer/me/wallet*`), and, since backend spec 010,
the market and selling:

- Home, Browse and the piece detail read the public market
  (`GET /market/listings*`). Search and the chips filter on the device, over
  the pieces that were loaded. The market never says who the seller is.
- The sell flow reads what Dahab accepts (`GET /reference/*`), uploads the
  photos, video, invoice and certificate (`POST /customer/me/uploads`), creates
  the listing and sends it for review (`/customer/me/listings*`).
- My listings shows each listing's state and the reviewer's message, with
  "Fix and resend" and "Take it down".
- Buying (backend spec 011): *Send buy request* shows the deposit terms and
  sends the price on screen (`POST /customer/me/buy-requests`); *Request sent*
  and *You need a little more* show the API's figures; the piece page shows your
  place in line and *Leave the queue*. The seller sees the first buyer in line
  on their own piece and can *Accept* (choosing one of the branches they named)
  or *Decline*.
- Orders (backend spec 012): the Orders tab lists your orders (`GET
  /customer/me/orders`), then your requests that were not accepted. The order
  screen (`/order?id=`) shows where the sale is and what to do: the seller
  brings the piece (branch and countdown) or cancels the sale; the buyer reads
  IGI's result, accepts or declines a new price, pays the balance from the
  wallet (*You need a little more* → *Add funds* when short) and shows the
  collection code; a returned piece shows the seller's code and *Put it back on
  the market*.
- Withdrawals (backend spec 013): Bank accounts (`/bank`) lists your payout
  accounts with their state (in use, under review, refused with the reason,
  being removed), *Use this one* / *Remove* / *Keep it after all*, the pause
  after a change and the recent changes (`/customer/me/payout-accounts*`); *Add a
  bank account* sends one for the name check with the declaration from
  `/reference/legal-documents/payout_account_declaration`; Your details shows
  the account in use. *Withdraw* emails a link (`/customer/me/withdrawals/
  confirmations`), waits for it (checked every 5 s), then sends the request; the
  link opens `/#/withdraw-confirm?token=…` (no sign-in). The wallet shows "On its
  way to your bank" and your withdrawals with *Cancel*.

The "You receive" estimate while filling the sell form, the diamond price
guide, promo codes and saved pieces are still the prototype's (mock), and so are
the prototype's other order screens (ask for more time, disputes, someone else
collects, rating). The video, the stone certificate and (for the owner) the invoice
open in a new browser tab. Transactions and invoices, the tax invoice screen (with its PDF and credit notes), View
invoice on a paid order and Open the invoice on the wallet line are live (backend spec 016). **Everything else**
(notifications, …) runs on local mock data until those APIs exist.

## Run

Start the backend first (`php artisan serve --port=8010` in `dahab-backend`),
and make sure its `.env` `CORS_ALLOWED_ORIGINS` includes the origin you serve
the app from. Then:

```bash
flutter pub get
flutter run -d chrome --web-port 8765 --dart-define=API_BASE_URL=http://127.0.0.1:8010/api/v1
```

`API_BASE_URL` defaults to `http://127.0.0.1:8010/api/v1`.

### Local test accounts and codes

- In the backend's `local` environment every SMS/email code is `123456`.
- A new account is `pending_verification` after sign-up. It can sign in and
  look around straight away; buying and selling answer `verification_required`
  until staff approve it (Dashboard → identity review, or Postman
  **Dashboard → Identity → Review — Verify** as `verification@dahab.test`).
- The first sign-in from a browser asks for the SMS code; after that the
  browser (its `X-Device-Id`, kept in localStorage) is trusted.

## Test

```bash
flutter analyze
flutter test
```

`test/routes_smoke_test.dart` renders every screen at 320, 375, 768 and
1280 px wide, in English and Arabic, and fails on any overflow or exception.
`test/flows_test.dart` walks the main journeys (auth against a fake backend
that returns the real API shapes), and `test/pricing_test.dart` checks the
pricing maths against the prototype.

`test/live/live_api_test.dart` runs the real auth code against a running
backend + database (register → pending → staff approval → new-device code →
sign-in → sign-out). It is skipped unless `LIVE_API` is set:

```bash
LIVE_API=http://127.0.0.1:8010/api/v1 flutter test test/live/live_api_test.dart
```

It creates one customer per run in the local database.

## Build and deploy

```bash
flutter build web --release --dart-define=API_BASE_URL=<production origin>/api/v1
```

Without `API_BASE_URL` the build talks to the local backend (`http://127.0.0.1:8010/api/v1`).
Upload the contents of `build/web/` to any static web server — no server
code, no rewrites needed (the app uses hash URLs such as `/#/orders`).
To serve from a sub-folder, build with a base href:

```bash
flutter build web --release --base-href /dahab/
```

Quick local check of the build:

```bash
python -m http.server 8765 --directory build/web
```

## Structure

```
lib/
  main.dart               wires the API and mock repositories + controllers (Provider)
  app.dart                MaterialApp.router, theme, locale/RTL, phone frame
  core/
    theme/                tokens.dart (colours, radii — from the prototype CSS), typography.dart
    i18n/                 LangController (EN/AR switch), ar_extra.dart
    utils/format.dart     money formatting
  models/                 Piece, OrderCardData (+ content blocks), wallet, account
  mock/                   all mock data, kept out of the UI
  services/
    repositories.dart     interfaces the UI depends on
    mock_repositories.dart  mock implementations (with simulated latency)
    api/                  ApiClient and the live repositories (wallet, market, listings, buy requests, orders)
    media_picker.dart     file picking for the sell flow (replaceable in tests)
    pricing.dart          commission / payout maths (ported from the prototype)
    live_rates.dart       mock live gold feed
    app_session.dart, sell_draft.dart, account_controller.dart  local UI state
  routing/                screen ids (= prototype ids), router, stack-aware navigation
  widgets/                design-system widgets: DButton, DCard, DSoft, DNote, DRow,
                          DChip, DSeg, DPill, DSlider, DInput, DOtp, DSlot, DTrack,
                          DMenu, DEmpty, DLoading, toast + modal, AppPage, PhoneFrame
  features/               screens by area: auth, home, catalog, sell, orders,
                          wallet, account, admin
assets/
  fonts/                  Inter, IBM Plex Sans Arabic, Instrument Serif, Playfair Display
  i18n/ar.json            the prototype's own Arabic dictionary, extracted verbatim
```

### Replacing the mocks with a real API

The screens only talk to the interfaces in `lib/services/repositories.dart`.
Implement them against the API and swap the `Mock*` classes in
`lib/main.dart`. Pricing in `services/pricing.dart` is pure and can be
replaced by server quotes.

## Language and RTL

Switch language on the splash screen (English / العربية) or under
Account → Language. Arabic flips the whole layout to RTL and uses
IBM Plex Sans Arabic. Translations come from the prototype's dictionary
(`assets/i18n/ar.json`); a few strings it lacks are in
`lib/core/i18n/ar_extra.dart`.

## Git attribution

Never record Claude (or any AI tool) as a participant in a git action: no `Co-Authored-By:` trailer, no `Claude-Session:` line, no "Generated with Claude Code" text, no claude.ai links and no model or tool name in any commit message, merge commit, cherry-pick, squash, tag, PR title or PR body. Messages are plain, in the project's style (`feat(scope): …`, `docs(scope): …`, `test(scope): …`), authored only by the git user already configured on the machine; never change `user.name` or `user.email`. Check the full message before every commit and merge. Only fix commits you created yourself; never rewrite shared history unless asked. This is Golden rule 10 of `../dahab-backend/CLAUDE.md`.

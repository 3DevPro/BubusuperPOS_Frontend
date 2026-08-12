# BubusuperPOS Frontend — Turbo POS

Flutter app (iOS, Android, web) for **Turbo POS** — a retail point-of-sale
app extended with a "Turbo" layer (income certification, micro-insurance,
branch/O2O) built for the TURBO Business Case Competition 2026 pitch
(Ngernturbo).

## Try it live

**https://porkornrawee.site** — served as a Flutter web build (production,
same backend as native builds). Works from any phone browser, no install
needed. On iOS/Android, "Add to Home Screen" from the browser share menu
gives it a home-screen icon and full-screen (no browser chrome) launch —
the free alternative to a native install (see `manifest.json` /
`web/index.html`'s `apple-mobile-web-app-capable` tag).

A true native iOS install (App Store / TestFlight / sideload) needs a paid
Apple Developer Program membership ($99/yr) or AltStore-style sideloading
(free, but the signed app expires every 7 days without a re-sign) — there
is no free, maintenance-free way to get a native, link-installable iOS
build. Android has no such restriction — `flutter build apk --release`
produces a directly-installable `.apk`, no account needed.

Part of a 4-repo split: `BubusuperPOS_Backend` (POS API), `BubusuperPOS_Frontend`
(this repo), `BubusuperPOS_chatbot` (AI assistant service), `BubusuperPOS_Infra`
(Docker Compose / deploy). All four are expected to live as sibling
directories.

## Architecture

State management is Riverpod; navigation is go_router (`lib/core/router.dart`).
Each screen's data flows through a `*_repository.dart` (raw Dio calls +
DTOs) and a `*_providers.dart` (Riverpod providers wrapping the repository)
in its feature folder.

**Two account types share one app, kept on separate rails:**

- **Shop accounts** (`owner` / `manager` / `cashier`) live inside the tabbed
  shell (`lib/shared/app_shell.dart`): POS, Inventory, Dashboard, Chat, More.
  `allowedRolesForRoute()` in `router.dart` mirrors Backend's `Permission`
  grants so a cashier never lands on a screen whose API calls would all
  403 — a UX nicety, not the real security boundary (the server enforces
  that regardless).
- **Branch Champion accounts** (`branch_champion`) — Ngernturbo staff, not
  shop staff — live entirely under `/branch` (`lib/features/branch/`), never
  inside the shop shell. The router's `redirect` callback checks the
  authenticated role on every navigation and keeps each account type inside
  its own half of the app; landing on the other half is redirected away
  automatically.
- **`/quote`** is the one route that's neither — a public, unauthenticated
  O2O price-check page, reachable and functional whether or not anyone is
  logged in.

Login is shared (`/login` — `/api/v1/auth/login`) for both account types;
only signup differs (`/signup` for shops, `/branch-signup` for branch staff).

### Feature folders

```
lib/features/
  pos/, inventory/, reports/, customers/, suppliers/,
  purchase_orders/, staff/, settings/, audit_log/, chat/, dashboard/, more/
                          ordinary POS features (see each folder's own files)
  auth/                   login/signup screens, AuthController (session state)
  turbo/                  daily-close card, income certificate (+ PDF export),
                          insurance quote/purchase/claims, dashboard claim banner
  branch/                 branch signup, branch home (prospects/leads/
                          leaderboard tabs), public O2O quote page
```

### Turbo features

- **Daily close** — a dashboard card for closing out each business day
  (normal, or sick/accident/holiday/other), the signal the rest of Turbo
  depends on to tell "day genuinely closed" apart from "no data yet".
- **Income certificate** (`/turbo/income-certificate`) — revenue streak
  ring, verified (QR/card) vs. self-reported cash split, credit tier, and a
  PDF export suitable for handing to a landlord or lender.
- **Insurance** (`/turbo/insurance`) — a small product catalog, a 3-tap
  quote → purchase flow, and a claims list; the dashboard shows a banner the
  moment auto-detected claimable days exist.
- **Branch Champion** (`/branch`) — Morning Route (merchant prospects in a
  walking radius), a leads inbox with a live 15-minute first-response SLA
  countdown, and a cross-branch leaderboard.
- **O2O quote** (`/quote`) — a public "price in 3 fields" form (occupation,
  age, monthly budget) that creates a lead routed to a nearby branch, no
  login required.

## Setup

```bash
flutter pub get
```

Requires the Backend and chatbot services reachable — the default
(`lib/core/config.dart`) points at `localhost:8000` / `localhost:8001` for
debug builds, `10.0.2.2` instead of `localhost` on the Android emulator
automatically. Override with `--dart-define=API_BASE_URL=...` and
`--dart-define=CHATBOT_BASE_URL=...` for a release build against a real
domain.

## Running

```bash
flutter run                      # picks a connected device/simulator
flutter run -d <device-id>       # a specific one — see `flutter devices`
```

Bring up Backend + chatbot + Postgres first:

```bash
cd ../BubusuperPOS_Infra && docker compose up -d
```

Then seed some demo data (see `BubusuperPOS_Backend/README.md` for details):

```bash
docker exec infra-backend-1 python scripts/seed_demo.py          # shop side
docker exec infra-backend-1 python scripts/seed_branch_demo.py   # branch side
```

### Demo logins

| Account | Email | Password |
|---|---|---|
| Shop owner (ร้านไก่ทอด) | `test@test.cpm` | `12345678` |
| Branch Champion (สาขาสีลม) | `test2@test.com` | `12345678` |

Both password fields have a show/hide toggle on login and signup.

## Tests

```bash
flutter test
```

Covers cart math, tax/PromptPay calculation, offline sale queueing, the SSE
chat-stream parser, and router role-guard logic (`allowedRolesForRoute`).
Screen-level/widget tests aren't part of this suite — coverage here is
business-logic-focused, matching where bugs have actually shown up.

## Analysis

```bash
flutter analyze
```

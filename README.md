# Skutla

> Decentralized peer-to-peer ride matching. No backend, no accounts — just a Flutter
> app, OpenStreetMap, and a public MQTT broker.

## Live demos

- **Firebase Hosting** — https://skutla-rides.web.app
- **GitHub Pages** — https://sigmarkarl.github.io/skutla/

Open the URL on two devices (or a phone + a desktop), pick **Driver** on one and
**Passenger** on the other, and they discover each other through the broker
without any Skutla-operated server in between.

## What it does

- Passenger taps the map to drop a destination, taps **Request ride**, and
  drivers in the nearby geohash cell receive the broadcast.
- Each interested driver sees an editable bid card (auto-priced from
  pickup-distance + trip-distance × per-km in the local currency) and submits a
  price.
- Passenger sees incoming bids (name, ★ rating, vehicle, price); tapping a bid
  card highlights the driver's marker on the map and vice versa.
- After accepting a bid, both sides see live driver location, the destination
  flag, and contact / payment chips (Phone, WhatsApp, Messenger; Aur, PayPal,
  Venmo, WeChat). Tap the destination flag to launch Apple/Google Maps with
  directions pre-populated.
- After **End ride**, both sides rate each other (1-5 ★ + comment). Ratings are
  stored locally; an aggregate average travels with each peer's broadcast so
  future counterparts can see it.
- A local **Ride history** keeps a record of every completed trip on each
  device (counterparty, role, time, duration, agreed price).

## How it works

| Concern | Approach |
| --- | --- |
| Discovery | Drivers publish retained presence to `skutla/v1/drivers/geo/<geohash5>/<peerId>`. Passengers subscribe to a 9-cell window (own + 8 neighbours) so it scales spatially. |
| Request fan-out | Passenger broadcasts a one-shot ride request to `skutla/v1/requests/geo/<geohash5>` (not retained); drivers in that cell receive it. |
| Bid / accept | Driver bids land in passenger's per-peer inbox `skutla/v1/inbox/<passengerId>`; passenger accepts one and decline-broadcasts to the rest. |
| Identity | Random UUID v4 per device install, stored in `shared_preferences` (or browser `localStorage`). No accounts. |
| Pricing currency | Reverse-geocoded from your first GPS fix via OSM Nominatim, mapped to ISO-4217. Driver can override and sticky-save their preference. |
| External nav | `tel:` / `https://wa.me/…` / `https://m.me/…` / `https://maps.apple.com/?daddr=…` / `https://www.google.com/maps/dir/?api=1&destination=…` |
| Reconnect resilience | Tracks all subscriptions internally; replays them on `onAutoReconnected`. |

## Tech stack

- [Flutter](https://flutter.dev) (web + iOS + Android + macOS + Windows targets)
- [`mqtt_client`](https://pub.dev/packages/mqtt_client) — MQTT 3.1.1 over secure
  WebSockets to the public **HiveMQ** broker (`broker.hivemq.com:8884/mqtt`)
- [`flutter_map`](https://pub.dev/packages/flutter_map) +
  [OpenStreetMap](https://www.openstreetmap.org/) tiles
- [`geolocator`](https://pub.dev/packages/geolocator) for device location
- [`shared_preferences`](https://pub.dev/packages/shared_preferences) for
  on-device persistence
- [`url_launcher`](https://pub.dev/packages/url_launcher) for tel:/maps:/wa.me
  deep links
- [`intl`](https://pub.dev/packages/intl) for currency formatting
- OSM **Nominatim** for reverse-geocoding to a country code

No backend services, no analytics, no telemetry.

## Privacy

Skutla doesn't operate a server. All your data lives on your device and
broadcasts only while the app is open. See [the full privacy policy](web/privacy.html)
or the live version at https://skutla-rides.web.app/privacy.html.

## Run locally

Requires the Flutter SDK on the dev (`master` channel — pubspec uses
`sdk: ^3.13.0-84.0.dev`).

```bash
# Web (headless dev server — open the URL in your normal Chrome so localStorage persists)
flutter run -d web-server --web-port 8765

# Phone (wireless or wired)
flutter run -d <device-id>

# macOS desktop
flutter run -d macos
```

## Build for distribution

```bash
# Static web bundle
flutter build web --release --pwa-strategy=none

# iOS (App Store / TestFlight)
flutter build ipa --release --export-method app-store

# Android
flutter build appbundle --release
```

## Deploy

Two deploy targets are wired:

- **GitHub Pages** — automatic on push to `main` via
  [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml). Builds with
  `--base-href /skutla/`.
- **Firebase Hosting** — `firebase deploy --only hosting:skutla` deploys to
  `skutla-rides.web.app`. Uses the `skutla` deploy alias defined in
  [`.firebaserc`](.firebaserc).

## License

[MIT](LICENSE) © Sigmar Stefansson

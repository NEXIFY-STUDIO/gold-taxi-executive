# GoldTaxi v2.5 — Bolt-style Flutter UI/UX

Toto je verzia **2.5**, nie prázdna kostra. Obsahuje reálny Flutter app shell, passenger flow, driver console, admin dashboard, pricing service, dispatch service, ride state machine, mock realtime simuláciu a Firebase-ready setup.

## Environment Setup

### Local Development
Copy `.env.local` to create your local environment file:
```bash
cp .env.local .env.local.development
# Edit .env.local.development with your keys
```

### Production
Copy `.env.production` to create your production environment file:
```bash
cp .env.production .env.production.development
# Edit .env.production.development with your production keys
```

**Required Keys:**
- `GOOGLE_MAPS_API_KEY` - From Google Cloud Console (Maps JavaScript API)
- `GOOGLE_PLACES_API_KEY` - From Google Cloud Console (Places API)
- `FIREBASE_WEB_VAPID_KEY` - From Firebase Console > Project Settings > Cloud Messaging > Web config
- `BACKEND_MODE` - Set to `mock` for development, `firebase` for production

### Whitelabel build labels
These are public UI labels, not secrets. They can be passed through an env file
or individual `--dart-define` flags:

```bash
flutter build web --release \
  --dart-define-from-file=.env.production.deployment \
  --dart-define=WHITELABEL_BRAND_NAME="Partner Taxi" \
  --dart-define=WHITELABEL_OPERATOR_LABEL="Private chauffeur platform" \
  --dart-define=WHITELABEL_MARKET_LABEL="Swiss premium mobility" \
  --dart-define=WHITELABEL_POWERED_BY="Powered by GoldTaxi"
```

## Lokálne spustenie

```bash
cd goldtaxi_bolt_v2_5
flutter pub get
flutter analyze
flutter test
flutter run -d chrome --dart-define-from-file=.env.local
```

## Web build

```bash
# For development build
flutter build web --release --dart-define-from-file=.env.local

# For production build
flutter build web --release --dart-define-from-file=.env.production
```

## Firebase deploy

```bash
# Build for production with production environment variables
flutter build web --release --dart-define-from-file=.env.production

# Deploy to Firebase Hosting
firebase deploy --only hosting
```

## Production Google Auth smoke

This opens Chrome and requires a real account selection by the tester:

```bash
bash scripts/google_auth_manual_smoke.sh
```

## Legacy backend schema

`database/supabase_schema.sql` zostáva ako dokumentácia pre prípadný neskorší backend export, ale appka už Supabase nepoužíva v runtime.

## Firebase backend foundation

- Auth contract: Firebase Auth
- Firestore schema: `firebase/firestore.schema.json`
- Rules: `firebase/firestore.rules`
- Indexes: `firebase/firestore.indexes.json`
- Functions scaffold: `functions/src/index.ts`
- Collections: `users`, `drivers`, `vehicles`, `rides`, `ride_events`, `payments`

## Čo je hotové

- Passenger landing/map/order flow
- Vehicle class selection
- Live mock drivers
- Pricing engine
- Dispatch selection
- Active ride lifecycle
- Driver online/offline console
- Admin operational dashboard
- Mock repository pripravený pre Firebase-only runtime
- SQL schema + RLS v `database/supabase_schema.sql`
- Stripe/Firebase Functions blueprint v `functions/stripe_connect_blueprint.ts`
- Technický blueprint v `docs/BLUEPRINT_V2_5.md`
- Mega postupový plán (status + ďalšie fázy) v `docs/todo.md`

## Čo musíš doplniť pred ostrou produkciou

- Reálny backend podľa budúcej Firebase implementácie
- Stripe secret key iba na backend
- Google Maps keys s restrictions
- Apple/Google store permissions pre location/background mode
- Reálny KYC proces vodičov
- Produkčné legal texty a poistné podmienky

Nie je to hračka. Je to základ, ktorý sa dá normálne rozšíriť bez toho, aby si po týždni pálil repo ako dôkazný materiál.

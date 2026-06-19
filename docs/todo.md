# GoldTaxi v2.5 — Mega Blueprint TODO (postupný execution plan)

Aktualizované: 2026-06-19

Legenda:

- [x] hotové

- [\~] čiastočne hotové / skeleton

- [ ] nezačaté

---

## 0) Aktuálny snapshot (truth source)

- Firebase project: `goldtaxi-202ff`
- Firestore DB: `(default)`, `FIRESTORE_NATIVE`, `STANDARD`, `europe-west6 (Zurich)` ✅
- Hosting live: `https://goldtaxi-202ff.web.app` ✅
- Cloud Functions v2 nasadené na `nodejs24` ✅
- Runtime backend v appke: stále `mock` (produkčný server-side flow ešte nie) ⚠️
- P1.1 Passenger polish: hotové ✅
- P1.5 UI anti-GPT cleanup: hotové ✅
- P1.6 test coverage: hotové ✅

---

## P1.1 — Passenger MVP polish

- [x] `/home` CTA flow (`Book premium ride` → `/app`)
- [x] copywriting cleanup na premium mobility tón
- [x] empty/loading/error states pre web/app shell flow
- [x] responsive QA pass pre mobile/tablet/desktop

---

## P1.5 — UI anti-GPT cleanup

- [x] odstránené generic dashboard/demo texty z landing a app shell
- [x] passenger UI zjednotený na premium ride-hailing flow
- [x] driver UI upravený na pracovný nástroj
- [x] admin/ops UI upravený na operačný panel
- [x] fake KPI vibe odstránený zo summary kariet

---

## P1.6 — Test coverage

- [x] `/home` widget test
- [x] `/app` deferred loader test
- [x] driver lifecycle test
- [x] admin resolve test
- [x] UI copy guard script

---

## P1.8 — Whitelabel UI/UX polish checkpoint

Aktualizované: 2026-06-19 18:58 CEST

- [x] pridaný verejný `BrandConfig` pre whitelabel názov, market label a powered-by text
- [x] landing a passenger shell používajú brand config namiesto hardcoded titulku v route title/nav/appbar
- [x] language switcher zjednotený na `EN / DE / SK / ES`
- [x] passenger booking panel obmedzený na profesionálnu max šírku na desktope
- [x] pridaný trip summary bar pre route, ETA a fare
- [x] vehicle tier selector upravený na horizontálny showroom pás
- [x] account panel skompaktnený pre guest/Google sign-in flow
- [x] web shell spevnený proti horizontálnemu browser overscrollu
- [x] README doplnené o whitelabel `--dart-define` premenné

**Verification:**

- `flutter analyze` ✅ PASS
- `flutter test` ✅ PASS (41/41)
- `flutter build web --release --dart-define-from-file=.env.production.deployment` ✅ PASS
- lokálny build server: `http://localhost:54821` ✅
- `curl -I /`, `/manifest.json`, `/offline.html` na lokálnom builde ✅ 200

---

## P1.7 — Firebase hosting hardening

- [x] overiť SPA rewrites (`firebase.json` rewrite `** -> /index.html`)
- [x] overiť cache headers (`no-cache` pre HTML/json/txt/xml, `immutable` pre js/css/wasm)
- [x] overiť manifest (`web/manifest.json`, brand + `/home` start\_url)
- [x] overiť robots/sitemap (`web/robots.txt`, `web/sitemap.xml`)
- [x] pridať `/app` direct URL smoke check (`test/hosting_smoke_test.dart`)
- [x] pridať Lighthouse baseline (`lighthouse-baseline.json`)
- [x] Safe PWA offline shell (`web/sw.js`, `web/offline.html`, `web/flutter_bootstrap.js`)

- [\~] dosiahnuť 95+ Lighthouse vo všetkých kategóriách (baseline existuje, score target ešte nie je splnený)

**Poznámka:** Hosting má 2 sites (`goldtaxi-202ff`, `gold-taxi-clean`). Produkčný route pre Flutter app je `gold-taxi-clean`.

**Safe PWA offline shell notes:**

- service worker je zapnutý bezpečne bez blokovania Flutter bootstrapu
- offline fallback stránka existuje len pre verejný statický shell
- Firebase/Auth/Firestore/API/runtime dáta sa offline necachujú zámerne
- test coverage kontroluje `manifest.json`, `offline.html`, `sw.js` a bezpečnostné vylúčenia
- plný offline booking je mimo scope, kým nebude existovať per-user encrypted local storage a sync conflict handling
- browser smoke test existuje v `scripts/pwa_browser_smoke.js` a beží cez `bash scripts/pwa_browser_smoke.sh`
- browser smoke acceptance: `/offline.html` musí vracať `200`, service worker musí byť registrovaný, offline navigácia musí spadnúť na `offline.html`, Cache Storage nesmie obsahovať Firebase/Auth/API/Firestore/Google APIs/Supabase/cross-origin runtime URL patterns ani citlivé runtime cesty
- 2026-06-19 forensic PWA fix:
    - opravený nekonečný viewport `MutationObserver` loop v `web/index.html`
    - service worker registrácia presunutá do HTML shellu cez `window.goldTaxiServiceWorkerReady`
    - `web/flutter_bootstrap.js` už obsahuje iba Flutter loader, bez vlastnej duplicitnej SW registrácie
    - `web/sw.js` cache bumpnutá na `goldtaxi-static-v2`
    - `/sw.js` má na Firebase Hosting hlavičku `Service-Worker-Allowed: /`
    - `scripts/pwa_browser_smoke.js` už nerobí ručnú fallback registráciu service workeru; testuje pasívnu produkčnú registráciu stránky
    - `flutter analyze` ✅
    - `flutter test` ✅
    - `bash scripts/smoke_hosting.sh` ✅
    - hosting redeploy na `https://gold-taxi-clean.web.app` ✅
    - `curl -I https://gold-taxi-clean.web.app/offline.html` → `200` ✅
    - Playwright browser smoke:
        - stránka pasívne zaregistrovala `https://gold-taxi-clean.web.app/sw.js` so scope `/` ✅
        - offline navigation fallback na random route zobrazil `offline.html` ✅
        - Cache Storage snapshot neukázal zakázané Firebase/Auth/API/runtime URL patterns ✅
    - runtime check: hlavná stránka skončila `document.readyState=complete`, Flutter shell existoval a `#loading` bol odstránený ✅

**2026-06-19 browser smoke result:**

- `flutter analyze` ✅
- `flutter test` ✅
- `bash scripts/smoke_hosting.sh` ✅
- hosting redeploy na `https://gold-taxi-clean.web.app` ✅
- `curl -I https://gold-taxi-clean.web.app/offline.html` → `200` ✅
- `bash scripts/pwa_browser_smoke.sh` ✅
- browser smoke potvrdil registráciu service workeru, offline navigation fallback na `offline.html` a čistý Cache Storage bez Firebase/Auth/API/Firestore/Google APIs/Supabase/cross-origin URL patternov aj bez citlivých runtime ciest

---

## P2.1 — Real maps decision

- [x] rozhodnúť Google Maps vs Mapbox
- [x] odporúčanie: Google Maps pre MVP (`lib/src/config/maps_config.dart`)
- [x] pripraviť API key restrictions (v `recommendedApiKeyRestrictions`)
- [x] pripraviť Places autocomplete kontrakt (`PlacePrediction`, `MapsService.autocomplete`)
- [x] pripraviť route polyline kontrakt (`RoutePolyline`, `MapsService.routeBetween`)
- [x] napojiť provider do runtime flow (Google HTTP provider + mock fallback)
- [x] nahradiť mock inputy za autocomplete + route preview v passenger flow

- [\~] produkčné API kľúče / env wiring (`GOOGLE_MAPS_API_KEY`, `GOOGLE_PLACES_API_KEY`)

---

## P2.2 — Firebase backend foundation

- [x] Firebase Auth (service/API vrstva zapnutá)
- [x] Firestore schema (`firebase/firestore.schema.json`)
- [x] Security Rules (`firebase/firestore.rules`) + deploy
- [x] Cloud Functions skeleton (`functions/src/index.ts`) + deploy
- [x] collections: `users`, `drivers`, `vehicles`, `rides`, `ride_events`, `payments`

- [\~] App client integration na Auth/Firestore (server foundation hotová, klient runtime ešte mock)
- [\~] tvrdé field-level validation v rules (základ je hotový, ešte treba sprísnenie)

---

## P2.3 — Real dispatch (server-side only)

- [x] `createRide` server-side callable/function
- [x] `dispatchRide` server-side assignment logic
- [x] `acceptRide` server-side transition + audit event
- [x] `declineRide` server-side transition + retry dispatch
- [x] `driverArrived` server-side transition
- [x] `startRide` server-side transition
- [x] `completeRide` server-side transition + final fare lock
- [x] odstrániť klientsky lifecycle mutation (klient len command, server authoritatívny stav)
- [x] idempotency + race protection (double accept / stale commands)

**Definition of done:**

1. všetky transitions sa dejú iba v Functions/Firestore rules enforce
2. klient nedokáže priamo prepísať status/fare/driverId
3. audit trail v `ride_events` je konzistentný

---

## P2.4 — Push notifications (FCM)

- [x] FCM setup (web + mobile target architecture)
- [x] driver ride offer push
- [x] passenger driver accepted push
- [x] passenger driver arrived push
- [x] passenger ride completed push
- [x] passenger payment failed push
- [x] retry/fallback policy + dedup event IDs

- [\~] web VAPID key wiring per environment (`FIREBASE_WEB_VAPID_KEY`)

---

## P3 — Payments (Stripe)

- [ ] Stripe Customer provisioning
- [ ] PaymentIntent pre-auth pred jazdou
- [ ] capture po jazde
- [ ] cancellation fee flow
- [ ] refund flow
- [ ] Stripe Connect až po stabilnom ride MVP

**Hard guardrails:**

- žiadne Stripe secret keys v klientovi
- všetko cez backend functions
- payment state machine naviazaný na ride state machine

---

## P4 — Pilot readiness

- [ ] GDPR pages
- [ ] Terms
- [ ] Privacy Policy
- [ ] contact/support flow
- [x] basic admin override (cancel + resolve v mock ops state)
- [ ] production env separation (dev/stage/prod config + hosting targets)
- [ ] first pilot operator config (tenant/operator bootstrap)

---

## P0 sprint checkpoint — 2026-06-19

### Backend Role Enforcement Test Coverage Added

**Files changed:**
- `functions/src/roles.ts` - New module extracting role guard logic (ensureAuth, requireAdmin, requireDriver, requirePassenger) with mockable role resolver for testing
- `functions/src/roles.test.ts` - Comprehensive role enforcement test suite with 38 test cases
- `functions/src/index.ts` - Updated to use role guards from roles.ts with Firestore role resolver
- `functions/package.json` - Added test dependencies (jest, @types/jest, ts-jest) and test scripts
- `functions/jest.config.js` - Jest configuration for TypeScript testing
- `functions/tsconfig.json` - Updated to include test files and jest types

**Test coverage:**
- Unauthenticated user cannot call privileged functions (ensureAuth)
- Passenger cannot call admin-only functions (requireAdmin)
- Driver cannot call admin-only functions (requireAdmin)
- Passenger cannot call driver-only functions (requireDriver)
- Admin cannot call driver-only functions (requireDriver)
- Admin can call admin-only functions like opsCancelRide
- Driver can call driver-only functions like setDriverOnline, acceptRide, etc.
- Token claims are prioritized over Firestore role (performance optimization)
- Firestore role fallback works when token claims are absent

**Test commands:**
```bash
# Run all backend tests
npm --prefix functions test

# Run only role enforcement tests
npm --prefix functions run test:roles
```

**Test results:**
- `npm --prefix functions run build` ✅ PASS
- `npm --prefix functions test` ✅ PASS (38/38 tests)
- `npm --prefix functions run test:roles` ✅ PASS (38/38 tests)
- `flutter analyze` ✅ PASS
- `flutter test` ✅ PASS
- `flutter build web --release --dart-define-from-file=.env.production.deployment` ✅ PASS
- `bash scripts/smoke_hosting.sh` ✅ PASS
- `bash scripts/pwa_browser_smoke.sh` ✅ PASS

**Unauthorized paths now covered:**
- ✅ Unauthenticated user cannot call driver-only callable (setDriverOnline, acceptRide, declineRide, driverArrived, startRide, completeRide)
- ✅ Passenger cannot call driver-only callable (same functions as above)
- ✅ Passenger cannot call admin-only callable (opsCancelRide, dispatchRide, seedRideEventFromManualAction)
- ✅ Driver cannot call admin-only callable (same functions as above)
- ✅ Unauthenticated user cannot call any privileged callable
- ✅ Admin cannot call driver-only callables (separation of concerns)

**Limitations:**
- Tests use unit testing approach with mockable role resolver instead of full Firebase emulator
- Production role checks remain server-side against Firestore and token claims
- Token claim priority is preserved (claims checked first, Firestore as fallback)
- No weakening of production security - tests validate the same logic path

**Final verdict: PASS ✅**

- [x] Firebase startup sequencing hardened:

    - `AppModule` now awaits Firebase runtime bootstrap before `AppState.start()`
    - `AppState` no longer subscribes to Firestore-backed driver streams inside the constructor

- [x] auto-driver bootstrap removed from client bootstrap paths
- [x] passenger default preserved; existing `driver` / `admin` role is no longer overwritten back to `passenger`
- [x] role gating added:

    - passenger UI only by default
    - driver tab only for `driver`
    - ops tab only for `admin`
    - driver-only Cloud Functions now require `driver` role explicitly
    - ops cancellation now uses dedicated admin-only callable `opsCancelRide`

- [x] validation run:

    - `flutter analyze` ✅
    - `flutter test` ✅
    - `flutter build web --release --dart-define-from-file=.env.production.deployment` ✅
    - `npm --prefix functions run build` ✅
    - `bash scripts/smoke_hosting.sh` ✅
    - `bash scripts/pwa_browser_smoke.sh` ✅

- [x] live smoke confirmed against `https://gold-taxi-clean.web.app`

Open follow-up after this sprint:

- add a real admin-controlled workflow that assigns `users/{uid}.role = driver` and provisions the matching driver profile
- [x] add backend tests for Cloud Functions role enforcement once a functions test runner is introduced

---

## Production deploy checkpoint — 2026-06-19 16:12:29 CEST

**Checkpoint archive**

- `.checkpoints/goldtaxi_bolt_v2_5-checkpoint-20260619-160654.tar.gz`
- `.checkpoints/goldtaxi_bolt_v2_5-checkpoint-20260619-160654.tar.gz.sha256`
- `.checkpoints/goldtaxi_bolt_v2_5-checkpoint-20260619-160654.manifest.txt`

**Git hygiene**

- `git status --short` -> failed with `fatal: not a git repository`
- `git diff --stat` -> failed with `warning: Not a git repository`
- result: no files are staged or committed from this directory because this project is still outside a Git working tree
- generated directories exist locally but cannot be staged here:
  - `build/`
  - `node_modules/`
  - `.dart_tool/`
  - `coverage/`
  - `test-results/`
  - `functions/node_modules/`

**Commands run**

```bash
flutter analyze
flutter test
npm --prefix functions test
npm --prefix functions run build
flutter build web --release --dart-define-from-file=.env.production.deployment
firebase deploy --only hosting,functions
bash scripts/smoke_hosting.sh
bash scripts/pwa_browser_smoke.sh
curl -s -o /dev/null -w 'root:%{http_code}\noffline:%{http_code}\n' \
  https://gold-taxi-clean.web.app/ \
  https://gold-taxi-clean.web.app/offline.html
```

**Results**

- `flutter analyze` ✅ PASS
- `flutter test` ✅ PASS (`34/34`)
- `npm --prefix functions test` ✅ PASS (`38/38`)
- `npm --prefix functions run build` ✅ PASS
- `flutter build web --release --dart-define-from-file=.env.production.deployment` ✅ PASS
- `firebase deploy --only hosting,functions` ✅ PASS
- `bash scripts/smoke_hosting.sh` ✅ PASS
- `bash scripts/pwa_browser_smoke.sh` ✅ PASS
- `GET /` ✅ `200`
- `GET /offline.html` ✅ `200`

**Live verification**

- hosting URL live: `https://gold-taxi-clean.web.app`
- service worker scope: `https://gold-taxi-clean.web.app/`
- service worker script: `https://gold-taxi-clean.web.app/sw.js`
- browser smoke cache audit passed with `12` cached entries checked
- forbidden Firebase/Auth/API/runtime URLs were not found in Cache Storage
- passenger browser check on `/app` showed:
  - `Driver` tab count: `0`
  - `Ops` tab count: `0`
  - no page errors captured
  - no obvious startup crash captured in browser console

**Open items**

- Git repository was initialized after this checkpoint in commit `624f7826eb9cf829b9c4fdccf70aa0e8321c3fba`
- driver enablement still needs a dedicated admin provisioning flow

**Verdict**

- `PASS`

---

## CI checkpoint — GitHub Actions

**Workflow name**

- `Gold Taxi CI`

**Workflow files**

- `.github/workflows/ci.yml`
- `.github/workflows/firebase-hosting-merge.yml`

**CI coverage**

- runs on pull requests targeting `main`
- runs on pushes to `main`
- Flutter app gate:
  - `flutter pub get`
  - `flutter analyze`
  - `flutter test`
  - `flutter build web --release`
- Firebase Functions gate:
  - `npm --prefix functions ci`
  - `npm --prefix functions test`
  - `npm --prefix functions run build`

**Production deploy workflow**

- deployment remains separate from CI
- hosting deploy now waits for successful `Gold Taxi CI` completion on `main`
- production deploy build creates a temporary `.env.production` from GitHub Secrets
- no `.env.production.deployment` file is committed or used by CI

**Required GitHub Secrets for production hosting deploy**

- `GOOGLE_MAPS_API_KEY`
- `GOOGLE_PLACES_API_KEY`
- `FIREBASE_WEB_VAPID_KEY`
- `FIREBASE_SERVICE_ACCOUNT_GOLDTAXI_202FF`

**Branch protection recommendation**

- require `Gold Taxi CI / Flutter app` before merge
- require `Gold Taxi CI / Firebase Functions` before merge
- block direct pushes to `main` where possible
- require pull request review before merge once collaborators are added
- keep Firebase deploy secrets available only to trusted branches/environments

**Still manual**

- configuring GitHub branch protection rules in repository settings
- verifying production deploy secrets exist in GitHub repository secrets
- pushing this repository to GitHub if the remote has not yet been connected
- full production deploy remains controlled by the separate hosting workflow

---

## Ďalšia diagnostika (repeatable audit gate pred každou fázou)

Spúšťať pred PR/deploy:

flutter analyze
dart format --output=none --set-exit-if-changed .
flutter test --coverage
flutter build web --release --wasm
firebase deploy --only hosting --project goldtaxi-202ff
firebase deploy --only firestore --project goldtaxi-202ff
firebase deploy --only functions --project goldtaxi-202ff

Produkčný smoke:

```bash
BASE=https://goldtaxi-202ff.web.app
for r in / /home /app /manifest.json /robots.txt /sitemap.xml; do
  curl -s -o /dev/null -w "%{http_code}  $r\n" "$BASE$r"
done
curl -sI "$BASE/home" | grep -Ei "cache-control|strict-transport-security|content-security-policy|x-frame-options|referrer-policy|permissions-policy"
```

---

## Prompty pre ďalšie fázy (copy/paste)

### Prompt — P2.3 Real Dispatch

> Implementuj P2.3 server-side dispatch end-to-end. Klient nesmie meniť ride status priamo. Všetky prechody (`createRide`, `dispatchRide`, `acceptRide`, `declineRide`, `driverArrived`, `startRide`, `completeRide`) urob cez Cloud Functions + Firestore rules enforcement. Pridaj testy na neplatné prechody, idempotency a race conditions.

### Prompt — P2.4 Push

> Implementuj FCM notifications pre offer/accepted/arrived/completed/payment-failed. Použi event IDs proti duplicitám, retry policy a audit log do `ride_events`.

### Prompt — P3 Payments

> Implementuj Stripe payment lifecycle: customer, pre-auth, capture, cancellation fee, refund. Žiadne secret keys mimo backendu. Payment status musí byť konzistentný s ride state machine.

### Prompt — P4 Pilot

> Dokonči pilot readiness: GDPR/Terms/Privacy, support flow, admin override completion, environment separation (dev/stage/prod), onboarding config pre prvého operátora.

---

## Prioritné poradie realizácie

1. P2.3 Real dispatch (server authoritative core)
2. Sprísnenie Firestore rules (field-level + immutable fields)
3. P2.4 Push notifications
4. P3 Payments
5. P4 Pilot readiness + legal + env separation

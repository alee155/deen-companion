# Deen Companion: Ads Flow and AdMob Setup

Shareable guide for the AdMob / ads-service / backend team. It covers how the
app handles ads, what the app already does to keep ads appropriate for an
Islamic audience, and what must be done in the AdMob console and on the server.

---

## 1. Summary

- The app uses **Google AdMob** on **Android and iOS** (`google_mobile_ads`).
- Three ad types: **Banner**, **Interstitial**, **App Open**.
- **The server decides** whether ads show and which ad unit IDs to use. The app
  never hardcodes a real ad unit ID.
- **Ads are OFF on the server at launch.** They are turned on only after the
  App Store and Play Store approve the app (see section 9).
- The app asks the SDK for **G-rated (family-safe) ads only**. This is
  enforced in code, but AdMob console blocking (section 7) is still required
  because it is the stronger layer.

---

## 2. Big picture

```
App launch
   │
   ▼
1. Ads config   GET https://ads.dgexpense.com/v1/apps/deen_companion/ads?platform=android|ios
   │            (saved copy used instantly; refetched after ttl_seconds; no answer = NO ads)
   ▼
2. Switch check ads_enabled == true  AND  the ad type's enabled == true  AND  has unit_id
   │            (any "no" = nothing is requested, nothing is shown)
   ▼
3. Consent      Google UMP form (EU / UK / CH), then iOS App Tracking prompt
   │            (consent says no = no ads this session)
   ▼
4. Rating       Max ad content rating set to G, before the SDK starts
   ▼
5. SDK start    MobileAds.initialize()
   ▼
6. Load + show  Banner / Interstitial / App Open (rules in section 4)
```

Every ad request goes through this one gate, so **no ad request can happen
before the config, the consent choice and the G rating are all in place.**

---

## 3. The ads config (server → app)

**Endpoint (public, no login):**
`GET https://ads.dgexpense.com/v1/apps/deen_companion/ads?platform=android|ios`

**Response shape the app expects:**

```json
{
  "ads_enabled": true,
  "ads": {
    "banner":       { "enabled": true,  "unit_id": "ca-app-pub-XXXX/YYYY" },
    "interstitial": { "enabled": true,  "unit_id": "ca-app-pub-XXXX/YYYY" },
    "app_open":     { "enabled": false, "unit_id": null }
  },
  "config_version": 7,
  "ttl_seconds": 3600
}
```

| Field | Meaning |
|---|---|
| `ads_enabled` | Master switch. `false` = no ads at all, on that platform. |
| `ads.<type>.enabled` | Switch for one ad type. |
| `ads.<type>.unit_id` | The real AdMob ad unit ID for that type and platform. |
| `ttl_seconds` | How long the app may reuse its saved copy (default 3600). |
| `config_version` | Informational. |

**App behaviour:**
- Saved copy is used immediately; refetched when older than `ttl_seconds` and
  each time the app returns to the foreground.
- Supports `ETag` / `If-None-Match` (a `304` keeps the saved copy).
- Timeout is 5 seconds. **Any failure with no saved copy means no ads.** The app
  never guesses a config.
- An ad type is shown only if it is enabled **and** has a non-empty `unit_id`.

**Because of this, the server alone can switch ads on or off, per platform and
per ad type, with no app update.** This is the kill switch.

---

## 4. Where and when each ad appears

### Banner
Shown at the bottom of selected screens, sized to the screen width (adaptive).
Screens: Prayer Times, Explore (All features), Dua search, Islamic calendar hub,
Mutashabihat hub and comparison, Reminders, Recent activity.
Not shown on Home, Quran reading, Groups, Profile, Settings, Zakat.

### Interstitial (full screen)
- Shown when a user **opens a snap** someone sent them.
- A user can open up to 5 snaps a day (one per prayer), but ads appear on
  **3 of them only**. The 3 are picked at random once per day and kept, so
  reopening the app does not re-roll. No prayer is favoured.
- Never within **90 seconds** of another full-screen ad.
- If the ad is not loaded, it is skipped and **the snap always opens
  normally**. The user is never blocked.

### App Open
- Shown when the app starts, or when the user returns after being away.
- **Cold start:** the splash waits at most **1.5 seconds** for the ad. If it is
  not ready, Home opens and that launch has no ad. It is never shown late.
- **Return from background:** only after **10+ minutes** away, and only if
  already loaded (the user is never made to wait).
- At most **one every 4 hours**.
- Never on a brand-new user's very first launch, and never on a launch where a
  consent or tracking prompt was just shown.

### Test vs real ads
- **Debug builds** always use Google's public test ad units, so development
  never generates real traffic.
- **Release builds** use the unit IDs from the server config.

---

## 5. Consent and privacy

- **Google UMP consent form** shows automatically for users in the EU, UK and
  Switzerland (needs the message to be set up in AdMob, section 6).
- **iOS App Tracking Transparency prompt** is shown on iPhone (after UMP).
- If consent forbids ads, or consent state cannot be read, **no ads are
  requested** that session.
- Child-directed treatment: **No**. Under-age-of-consent treatment: **No**. The
  app is a general-audience app, not a children's app.

---

## 6. What the AdMob team must set up (checklist)

### A. Apps and ad units
1. Create / confirm the **Android app** and the **iOS app** in AdMob.
   - iOS App ID currently in `Info.plist`: `ca-app-pub-1880428028238946~2695714936`.
   - Android App ID is supplied at build time (`android/admob.properties`,
     gitignored). Give the developer the final Android App ID.
2. Create **3 ad units per platform (6 total)**:
   - Banner
   - Interstitial
   - App Open
3. Send the 6 ad unit IDs to the backend developer so they can be put into the
   ads service config (section 3). They go **only** on the server.
4. Link both apps to their store listings once the apps are published (needed
   for `app-ads.txt`, and for correct reporting).

### B. Consent (required for EU / UK / CH)
5. Privacy & messaging → create a **GDPR message** (consent form) and publish
   it for both apps.
6. For iOS: create an **IDFA explainer / ATT message** and publish it.
7. Make sure the **US state regulations** message is set up if US traffic is
   expected.

### C. Ad content blocking (most important for an Islamic app)
See section 7. The app asks for G-rated ads in code, but the console blocks
below are the real enforcement layer and **must** be configured.

### D. Other
8. Add the **`app-ads.txt`** file to the developer website domain listed in the
   store listing, and verify it in AdMob.
9. Set up **payments** (address, tax info, payment method) so earnings can be
   paid.
10. Confirm both apps are in the same AdMob account as the ad units used by the
    server.

---

## 7. Ad content blocking: AdMob console settings

Where: **AdMob → Blocking controls**. Apply to **both apps** (Android and iOS).
Changes can take up to ~24 hours to apply.

| Control | Setting |
|---|---|
| **Sensitive categories** | Switch to **Restricted** (or block individually): **Dating, Sexual & Reproductive Health, Get-Rich-Quick, Drugs & Supplements, Politics, Religion, Gambling & Betting, Alcohol, Weight Loss, Astrology & Occult, Social Casino Games, Lotteries**. |
| **General categories** | Block: **Dating, Alcohol, Gambling / Casino / Betting, Lingerie / Swimwear / Adult-adjacent, Astrology / Horoscopes, Occult**. Also review: Beauty, Drugs, Weight loss. |
| **Advertiser URLs** | Add any specific advertiser domains seen in the app that should not appear. |
| **Ad review center** | **Enable it** (account-level) so individual ads can be reviewed and blocked, and check it weekly, especially in the first weeks after launch. |
| **Maximum ad content rating** | Set the app-level maximum to **G** (matches what the app already requests in code). |

Notes:
- Blocking is by **category and advertiser**, not by country.
- No filter is perfect. The Ad review center is how unsuitable ads that slip
  through are blocked afterwards.
- Banning more categories lowers fill and earnings slightly. This is expected
  and acceptable for this audience.
- Optional: block the **Religion** category entirely if other faiths' ads are
  not wanted.

---

## 8. What the app already enforces in code (no action needed)

- **Max ad content rating = G**, sent to the SDK **before** it starts, and
  applied to every banner, interstitial and App Open request.
- Child-directed = No, under-age-of-consent = No (explicit, not left default).
- No ad request before: config answered, consent settled, rating applied.
- Frequency limits (section 4) so ads are not a nuisance.
- Real ad unit IDs only from the server; test units in debug builds.
- Automated tests cover: the rating is G, the rating is sent before SDK start,
  and all three ad types share the same filtered request.

Not included in the app (optional future work): an in-app "Report this ad"
link (needs a support email), and ad keyword targeting.

---

## 9. Go-live order

1. App is submitted and **approved** on the App Store and Google Play. Ads are
   still **off** on the server.
2. AdMob team completes sections 6 and 7 (apps, 6 ad units, consent messages,
   blocking controls, Ad review center, G rating).
3. Backend developer puts the 6 ad unit IDs into the ads service config.
4. Test on a **release build**: with ads still disabled on the server, confirm
   no ads appear. Then enable **one platform and one ad type** (for example
   Android banner), confirm a real ad shows and is appropriate.
5. Enable the remaining types, then iOS.
6. Watch the **Ad review center** daily for the first week and block anything
   unsuitable.
7. **To stop all ads at any time:** set `ads_enabled: false` in the ads
   service. No app update needed; takes effect within the config `ttl_seconds`
   (default 1 hour) or the next time the app is reopened.

---

## 10. Quick reference

| Item | Value |
|---|---|
| Ads service base URL | `https://ads.dgexpense.com` |
| App key | `deen_companion` |
| Config endpoint | `/v1/apps/deen_companion/ads?platform=android` or `ios` |
| Ad types | banner, interstitial, app_open |
| Max content rating in app | G |
| Config cache | `ttl_seconds` (default 3600 s) |
| Interstitial | 3 per day on snap open, min 90 s apart |
| App Open | max 1 per 4 h, 10+ min away on resume, 1.5 s cold-start budget |
| Debug builds | Google test ads only |

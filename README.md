![Deen Companion](screenshot/App_SS.jpeg)

# Deen Companion

**Your daily Islamic companion: Quran, prayer times, and a community that keeps you consistent.**

Deen Companion brings the essentials of daily worship into one calm, polished app for iOS and Android. Read and listen to the Quran, never miss a prayer, find your Qibla, make duas, calculate your Zakat, and pray together with friends and family, with shared streaks that keep everyone motivated.

> **Status:** in active development, being prepared for release on the Google Play Store and the Apple App Store.

---

## Why Deen Companion

- **Everything in one place.** Quran, prayer times, Qibla, Hadith, duas, the 99 names of Allah, the Hijri calendar and Zakat, without juggling several apps.
- **Reliable where it matters.** Prayer reminders are scheduled on the device and fire on time, offline, even after a restart.
- **Built for consistency.** Prayer logging, points and streaks, plus groups where members encourage one another.
- **Respectful and safe.** Content in groups can be reported, and people can be blocked.
- **Fast and polished.** Cached content opens instantly, with a consistent design in light and dark themes.

---

## Key features

### Worship

| | |
| --- | --- |
| **Quran** | Surah list with translation and transliteration, search, last-read tracking, a dedicated Juz hub and reader, and reading preferences shared with Hadith. |
| **Quran audio** | Streaming recitation by surah with multiple reciters, a mini player and full-screen player, background playback and lock-screen controls. |
| **Prayer times** | Accurate times for your location, with your choice of calculation method and Asr setting, a monthly calendar and an upcoming-days view. |
| **Prayer reminders** | Per-prayer reminders delivered as native alarms. Android has a full-screen alarm with snooze and dismiss. iOS has a branded prayer screen and, on iOS 26+, alarms that ring even in silent mode and Focus. |
| **Silence during prayer** | Optionally silence the phone around each prayer. Android uses Do Not Disturb with configurable windows. iOS offers a guided setup. |
| **Qibla** | A live compass using the true-north bearing, corrected for the device's magnetic declination, with calibration prompts. |
| **Hadith** | Major collections, reading mode, search, grading and a Hadith of the day. |
| **Duas** | Duas by situation, with a reader, search, favourites and a dua of the day. |
| **Asma-ul-Husna** | The 99 names with meanings, search, detail pages and a daily practice. |
| **Mutashabihat** | Compare similar verses across surahs with the differences highlighted. |
| **Islamic names** | A boy and girl names directory with origin filters and detail pages. |
| **Islamic calendar** | The Hijri calendar, key events, a Gregorian to Hijri converter and a regional day adjustment. |
| **Zakat** | Wealth and harvest calculators with a clear breakdown of what is due. |

### Community

| | |
| --- | --- |
| **Prayer groups** | Create or join groups for family, friends or your community, with privacy options and invite links. |
| **Prayer snaps** | Log the prayer that is open by sending a photo snap to the groups you choose. A snap opens once per viewer and expires when the prayer time ends. |
| **Streaks and points** | Personal and group streaks, daily goals, points and statistics to track your progress over time. |
| **Live updates** | Group activity updates in real time, with members ordered by who snapped most recently. |
| **Safety** | Report snaps or people, block members, and manage blocked people from Settings. |

### Experience

- Light and dark themes, adjustable reading preferences and reduced-motion-aware animation.
- An app-wide connection banner, so it is always clear when you are offline.
- Cache-first loading for Quran, Hadith and other content.
- Daily Ayat and Hadith notifications.

---

## Technology

| Area | Choice |
| --- | --- |
| Framework | Flutter and Dart, one codebase for iOS and Android |
| State management and DI | Riverpod |
| Navigation | go_router |
| Networking | Dio, with retry and connectivity handling |
| Realtime | Socket.IO for live group updates |
| Local storage | Hive for preferences and cached content, secure storage for the session |
| Audio | just_audio with background playback |
| Location and sensors | Geolocator, compass, permission handling |
| Camera | Camera, image cropping and compression for snaps |
| Notifications and alarms | Native Android alarms, AlarmKit on iOS 26+, local notifications for daily content |
| Native code | Kotlin (Android alarms, Do Not Disturb, magnetic declination) and Swift (iOS alarms and prayer screen) |
| Quality | Automated tests across domain, data and UI layers, static analysis and format checks in CI |

---

## Architecture

The code is organised **by feature**, and every feature follows **Clean Architecture** with dependencies pointing inward:

```
presentation  ──▶  domain  ◀──  data
 (screens,         (entities,    (models, datasources,
  Riverpod          repository    repository
  providers)        contracts,    implementations)
                    business rules)
```

- **Domain** is plain Dart: entities, repository contracts and business rules, with no framework dependencies.
- **Data** implements those contracts. Network and storage errors are turned into typed failures, so the UI never sees raw exceptions.
- **Presentation** holds screens, widgets and Riverpod providers. Widgets never talk to the network or storage directly.
- **Platform code stays behind interfaces.** Alarms, Do Not Disturb, location and sensors can be replaced in tests.
- **Shared design system** for colours, typography, motion and reusable components, so every screen feels consistent.

```
lib/
├── core/        # networking, storage, routing, theme, errors, connectivity
├── shared/      # cross-feature widgets and providers
└── features/    # quran, prayer_times, prayer_reminders, groups, snaps,
                 # streaks, statistics, moderation, hadith, duas, zakat, ...
                 #   └── domain / data / presentation
```

---

## Quality and delivery

- Every change is checked with formatting, static analysis and the full automated test suite.
- GitHub Actions builds signed Android and iOS release artifacts for release commits. See [docs/CI_CD.md](docs/CI_CD.md).

---

## Platforms

| Platform | Status |
| --- | --- |
| iOS (15+) | Release builds on TestFlight, App Store release planned |
| Android | Primary target, Google Play release planned |

---

## Roadmap

- Public release on the Google Play Store and the Apple App Store.
- Offline downloads for Quran recitations.
- Sending a snap to more groups after the first send.
- Localisation beyond English.

---

© Deen Companion. All rights reserved.

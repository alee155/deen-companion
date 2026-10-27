# CI/CD

One workflow, [`.github/workflows/ci.yml`](../.github/workflows/ci.yml), covers
quality checks and release builds.

```
push / pull request
      │
      ├─ plan ──────────────► is this a release? (commit message contains "[Release]")
      │                          └ also computes version + build number
      ├─ quality ───────────► format (changed files) → analyze → test      (always)
      │
      ├─ android ───────────► signed AAB + APK + symbols                   (only [Release], after quality)
      ├─ ios ───────────────► signed build uploaded to TestFlight          (only [Release], after quality)
      │
      └─ pipeline-status ───► single required check for branch protection
```

## When does a build happen?

| Event | Quality checks | Release build |
| --- | --- | --- |
| Pull request to `main` | yes | **never** |
| Push to `main` / `release/**`, normal commit | yes | no |
| Push to `main` / `release/**`, a commit message contains `[Release]` | yes | **yes**, after the checks pass |
| Push to any other branch | (use a pull request) | no |

- The match is case-insensitive and applies to **every commit in the push**, not
  just the last one. Messages are read from git history by
  `tool/ci/commit_messages.sh`, so there is no cap on how many commits a push
  can contain.
- Pull requests never build releases: they may come from forks and must not be
  able to reach signing credentials.
- With **squash merges**, put `[Release]` in the squash commit message (the
  default message includes the PR title).
- Add `[skip ci]` to a message to skip the whole pipeline (GitHub built-in).
- Change the token or the release branches in `tool/ci/detect_release.sh`
  (`RELEASE_TOKEN`, `RELEASE_BRANCHES`). The script is plain bash and can be run
  locally to test a message:

  ```bash
  EVENT_NAME=push REF_NAME=main COMMIT_MESSAGES="fix: x [Release]" tool/ci/detect_release.sh
  ```

## Cutting a release

1. Bump `version:` in `pubspec.yaml` if the user-visible version changes
   (`1.0.0` part only — the build number is automatic).
2. Commit with `[Release]` in the message, e.g. `chore: release 1.1.0 [Release]`.
3. Push to `main`. When the run is green, download from the run page →
   **Artifacts**:
   - `android-aab-<version>+<build>` — upload this to Play Console.
   - `android-apk-<version>+<build>` — for direct installs and testers.
   - `android-symbols-<version>+<build>` — keep it; it de-obfuscates crash traces
     for this exact build (retained 90 days).
4. The run summary shows the **signing certificate SHA-256** of the build —
   handy for checking it matches the fingerprints in `assetlinks.json`.

Version name comes from `pubspec.yaml`. The **build number is
`run number + ANDROID_BUILD_NUMBER_OFFSET`**, so it always increases.

## One-time setup (repository owner)

### 1. Create the `release` environment

*Settings → Environments → New environment → `release`.* Store the secrets below
**in this environment** (not as repository secrets) so only release jobs can read
them. Optionally add **Required reviewers**: every release build then waits for a
manual approval.

### 2. Secrets (environment `release`)

| Secret | Value |
| --- | --- |
| `PROD_CONFIG_JSON` | The full contents of your local `config/prod.json` |
| `ANDROID_KEYSTORE_BASE64` | The upload keystore, base64: `base64 -i android/app/deen-upload-keystore.jks \| pbcopy` |
| `ANDROID_KEYSTORE_PASSWORD` | `storePassword` from `android/key.properties` |
| `ANDROID_KEY_ALIAS` | `keyAlias` from `android/key.properties` |
| `ANDROID_KEY_PASSWORD` | `keyPassword` from `android/key.properties` |
| `ADMOB_APP_ID` | `admobAppId` from `android/admob.properties` |
| `ASC_KEY_ID` | iOS: Key ID of an App Store Connect API key (*Users and Access → Integrations → App Store Connect API*; role **Admin**, so Xcode can create the distribution certificate) |
| `ASC_ISSUER_ID` | iOS: the Issuer ID shown on that same page |
| `ASC_KEY_P8_BASE64` | iOS: the downloaded `AuthKey_<id>.p8`, base64: `base64 -i AuthKey_XXXX.p8 \| pbcopy` |

The workflow recreates the same git-ignored files you use locally
(`config/prod.json`, `android/key.properties`, `android/admob.properties`, the
keystore) on the runner, and deletes them at the end of the job. Values are
passed through environment variables, never written into the workflow, and
GitHub masks them in logs.

### 3. Repository variables (*Settings → Secrets and variables → Actions → Variables*)

| Variable | Purpose |
| --- | --- |
| `IOS_BUILD_NUMBER_OFFSET` | Same idea for TestFlight: a build number must exceed every build already uploaded for that version. Defaults to `0`. |
| `ANDROID_BUILD_NUMBER_OFFSET` | **Set this before the first release.** Google Play needs a `versionCode` higher than any already uploaded. Set it to the highest uploaded code (for example `10`); the first CI build is then `10 + run number`. Defaults to `0`. |

### 4. Branch protection (recommended)

Require the **Pipeline status** check on `main`. It fails if any job failed or
was cancelled, and ignores release jobs that were legitimately skipped.

## What the checks do

- **Format** — `dart format` must leave the Dart files *changed in this push/PR*
  untouched. Only changed files are checked, because some older files aren't
  formatted yet; this stops new debt without a repo-wide reformat. After a one-off
  `dart format .` commit, switch `tool/ci/check_format.sh` to a whole-repo check.
- **Analyze** — `flutter analyze --no-fatal-infos`: errors and warnings fail the
  build; existing info-level lints are listed but don't block.
- **Test** — `flutter test --coverage`; `lcov.info` is uploaded for 7 days.
- `flutter pub get --enforce-lockfile` fails the build if `pubspec.yaml` and
  `pubspec.lock` disagree, so CI builds exactly what was reviewed.

## Speed

Flutter SDK and pub cache (`subosito/flutter-action` cache), Gradle
(`actions/setup-java` cache), shallow
fetch except where history is needed, and superseded *pull-request* runs are
cancelled (runs on `main` / `release/**` are never cancelled, so a release build
can't be killed by the next commit). Release builds wait for the quality job, so a broken commit
never burns build minutes.

## Platform notes and limits

**Android** builds a release AAB and APK with the production entry point
(`lib/main_prod.dart`), `--dart-define-from-file=config/prod.json`, Dart
obfuscation and split debug info. The build fails if the APK turns out to be
signed with a debug key.

**iOS** builds a release with the same entry point, config file, obfuscation and
build-name/number rules, archives it, and uploads it to TestFlight. It runs on
`macos-latest` with the latest stable Xcode (prayer alarms need the iOS 26 SDK).
Signing uses Xcode's automatic signing with the App Store Connect API key, so no
certificate or provisioning profile is stored as a secret. Needs, once:

- the app record in App Store Connect (bundle id `com.devsouq.deencompanion.ios`),
- the three `ASC_*` secrets above and the `release` environment,
- the Apple team in `DEVELOPMENT_TEAM` (read from the Xcode project).

The Dart symbols for de-obfuscating crashes are kept as an artifact for 90 days.
The job has not yet run on GitHub: the first release run is the real test, so
expect to fix small things (runner Xcode version, API key role).

**Not included (add when needed):** automatic Play Store upload (needs a Google
service account and the Play Developer API), GitHub Releases, and Slack/email
notifications. The `android` job is the place to extend: the AAB is already at
`build/app/outputs/bundle/release/app-release.aab`.

## Updating

- **Flutter version:** change `FLUTTER_VERSION` at the top of `ci.yml` (one
  place), together with your local SDK.
- **Actions:** the pinned action versions (`@v4`, ...) are updated by hand when GitHub deprecates one.
- **New secret:** add it to the `release` environment, read it via `env:` in the
  step (never `${{ secrets.X }}` inside a `run:` script), and clean up any file
  you write.

## Troubleshooting

| Symptom | Cause / fix |
| --- | --- |
| IDE shows "Context access might be invalid" for `release` or one of the secrets / variables | The GitHub Actions extension checks against the real repo; these appear until the environment, secret and variable exist (see setup above). They are not workflow errors. |
| Release job not created | Not a push to `main`/`release/**`, or no `[Release]` in any commit of the push. See the *Plan* summary for the reason. |
| `Missing release secret(s): …` | The named secret isn't in the `release` environment. |
| Play rejects the upload: version code already used | Raise `ANDROID_BUILD_NUMBER_OFFSET`. |
| `pubspec.lock … out of date` | Run `flutter pub get` locally and commit `pubspec.lock`. |
| Format check fails | Run `dart format <the listed files>` and commit. |

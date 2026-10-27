# iOS Universal Links (group invites)

Invite links look like `https://deencompanion.dgexpense.com/invite/<token>`.
On Android they are verified through `/.well-known/assetlinks.json`; iOS needs
the equivalent file, which the **backend must serve**.

## Server file

Serve this at

    https://deencompanion.dgexpense.com/.well-known/apple-app-site-association

- over HTTPS with a valid certificate, no redirects,
- `Content-Type: application/json`,
- no `.json` extension.

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["22SSYM39V3.com.devsouq.deencompanion.app"],
        "components": [{ "/": "/invite/*" }]
      }
    ]
  }
}
```

`appIDs` is `<Team ID>.<Bundle ID>`: the team in `DEVELOPMENT_TEAM` and the
bundle id in `ios/Runner.xcodeproj`. Change both here if either changes.

## App side (already done)

- `ios/Runner/Runner.entitlements`: `applinks:deencompanion.dgexpense.com`
- `Info.plist`: `FlutterDeepLinkingEnabled`
- `go_router` routes `/invite/:token` to the join screen.

## Checking it

- `curl -i https://deencompanion.dgexpense.com/.well-known/apple-app-site-association`
  returns 200 and the JSON above.
- On a device, tapping an invite link in Notes or Messages (not typing it in
  Safari's address bar) opens the app. iOS caches the file at install time, so
  reinstall after the server file first goes live.
- Apple's CDN caches it too; `?mode=developer` on the associated domain
  (Settings > Developer > Universal Links) bypasses that for development.

# iOS app

Native SwiftUI app (iOS 17+) on top of the backend's `/api/v1`, with dictation and local reminders.

## Requirements

- Xcode 16+ and XcodeGen (`brew install xcodegen`)
- A free Apple account in Xcode → Settings → Accounts
- A device token: `python -m app.cli create-token "iPhone"` inside the app container (locally: `docker compose -f docker-compose.local.yml exec api python -m app.cli create-token "iPhone"`)
- For access from outside: a Cloudflare service token (see `docs/deployment.md`)

## Build and test

    cd ios
    xcodegen generate
    xcodebuild test -project Planer.xcodeproj -scheme Planer -destination 'platform=iOS Simulator,name=iPhone 16'

## Install on a device

1. Connect the iPhone, trust the Mac, enable Developer Mode (Settings → Privacy & Security).
2. `open Planer.xcodeproj` → target "Planer" → Signing & Capabilities → pick your personal team. If the bundle ID is taken, change `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` and run `xcodegen generate` again.
3. Select the iPhone and hit ⌘R.
4. On first launch: Settings → General → VPN & Device Management → trust the developer app.

With a free account the certificate expires after 7 days. Reconnect and hit ⌘R again, the keychain data survives.

## Setup in the app

- **Server URL**: your Cloudflare hostname, or `http://<server-lan-ip>:8080` on the LAN. Plain HTTP is only allowed for local addresses.
- **Cloudflare service token**: client ID and secret. Leave empty on the LAN.
- **Device token**: if it gets revoked, the app says so and goes back to setup.

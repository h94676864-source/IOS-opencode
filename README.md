# OpenCode iOS

A native SwiftUI iPhone client for an OpenCode server.

## Current behavior

- Validates the actual OpenCode `/global/health` response (including `healthy` and server version) before opening the web UI.
- Opens the server web UI in a WKWebView after a successful health check.
- Stores the configured server URL and username on device; stores the password in iOS Keychain.
- Uses HTTP Basic authentication without putting credentials in the URL.
- Rejects redirects during the credentialed health check to prevent credentials being forwarded to another host.
- Restricts WebView navigation and authentication to the configured server origin.
- Provides connection diagnostics, retry, and reload controls.

## Connect an iPhone to a computer running OpenCode

OpenCode binds to `127.0.0.1` by default, which is only reachable from the computer itself. For a phone on the same trusted Wi-Fi network, start the server so it listens on the LAN interface and protect it with a password.

macOS / Linux:

```sh
OPENCODE_SERVER_PASSWORD='choose-a-long-unique-password' opencode serve --hostname 0.0.0.0 --port 4096
```

Windows PowerShell:

```powershell
$env:OPENCODE_SERVER_PASSWORD = "choose-a-long-unique-password"
opencode serve --hostname 0.0.0.0 --port 4096
```

Then:

1. Keep the computer and iPhone on the same trusted Wi-Fi network.
2. Allow incoming TCP port `4096` in the computer's firewall for the private network only.
3. Find the computer's LAN IPv4 address (for example, `192.168.1.20`).
4. In the iPhone app, open Connection settings and enter `http://192.168.1.20:4096`.
5. Use username `opencode` and the password set in `OPENCODE_SERVER_PASSWORD`.
6. Tap **Save and connect**.

Do not enter `127.0.0.1`, `localhost`, or `0.0.0.0` in the iPhone app. Those are not the computer's reachable LAN address. Use the actual LAN IP. Do not expose an unauthenticated OpenCode server to the public internet; use a secured HTTPS reverse proxy or private VPN for remote access.

## Build locally

Requirements: macOS, Xcode 16+, and XcodeGen.

```sh
brew install xcodegen
xcodegen generate
xcodebuild -project OpenCodeIOS.xcodeproj -scheme OpenCodeIOS -destination 'generic/platform=iOS Simulator' build
```

## IPA

Pushing to `ios/local-port` or manually running **Build iOS IPA** triggers a macOS GitHub Actions build. The workflow validates the generated app bundle, packages an unsigned IPA, and uploads it as an artifact. An unsigned IPA is not installable on a standard iPhone until signed with an Apple certificate and a matching provisioning profile.

## Important runtime limitation

The Android app runs a Linux/PRoot/Alpine environment and Linux OpenCode binaries. iOS cannot run that Android/Linux root filesystem or those Linux binaries as-is. This branch is a native iOS client for a separately running OpenCode server; it is not yet an offline, self-contained port of the Android engine.

Matching Android's fully local behavior requires a separate iOS-compatible engine/runtime implementation. Copying the Android root filesystem into an IPA does not create an iOS runtime.

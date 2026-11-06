# OpenCode iOS

A native SwiftUI iPhone client for an OpenCode server.

## Current behavior

- Checks the OpenCode `/global/health` endpoint.
- Opens the server web UI in a WKWebView after a successful health check.
- Stores the configured server URL on device.
- Provides clear diagnostics instead of silently trying to connect to an unavailable iPhone-local server.

## Connect an iPhone

1. Start OpenCode on a computer or server reachable by the iPhone.
2. Put both devices on the same Wi-Fi network, or configure a secured HTTPS endpoint.
3. In the app, open Connection settings and enter the server's LAN address, for example `http://192.168.1.20:4096`.
4. Allow local-network access if iOS requests it, then tap Connect.

Do not use `127.0.0.1` for a computer on the network. On iPhone, that address means the iPhone itself.

## Build locally

Requirements: macOS, Xcode 16+, and XcodeGen.

```sh
brew install xcodegen
xcodegen generate
xcodebuild -project OpenCodeIOS.xcodeproj -scheme OpenCodeIOS -destination 'generic/platform=iOS Simulator' build
```

## IPA

Pushing to `ios/local-port` or manually running **Build iOS IPA** triggers a macOS GitHub Actions build and uploads an unsigned IPA artifact. It is not installable on a standard iPhone until signed with an Apple certificate and matching provisioning profile.

## Important runtime limitation

The Android app runs a Linux/PRoot/Alpine environment and Linux OpenCode binaries. iOS does not support running that Android/Linux root filesystem or those binaries. This branch is currently a native iOS client for a separately running OpenCode server; it is not yet an offline, self-contained port of the Android engine.

Matching Android's fully local behavior requires a separate iOS-compatible engine/runtime port. The Android root filesystem cannot simply be copied into an IPA and launched.

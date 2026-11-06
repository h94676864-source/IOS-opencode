# OpenCode iOS

Native SwiftUI iPhone client for an existing OpenCode server. The app checks the server health endpoint and displays the server web UI in a WKWebView restricted to the configured host.

## Build locally

Requirements: macOS, Xcode 16+, and XcodeGen.

```sh
brew install xcodegen
xcodegen generate
xcodebuild -project OpenCodeIOS.xcodeproj -scheme OpenCodeIOS -destination 'generic/platform=iOS Simulator' build
```

## Connect

1. Start OpenCode on a computer/server reachable by the iPhone.
2. Configure its HTTP(S) URL in Connection settings.
3. For a home-LAN server, use its LAN IP and port.
4. Protect remote access with HTTPS, authentication, and suitable network controls.

## IPA

Pushing to `ios/local-port` or manually running **Build iOS IPA** triggers a macOS GitHub Actions build and uploads an unsigned IPA artifact. It is not installable on a standard iPhone until signed with an Apple certificate and matching provisioning profile.

## Runtime compatibility

The Android project bundles Linux/PRoot/Alpine assets and launches a Linux OpenCode process locally. iOS does not support that Android/Linux execution model. This iOS target is a native client for a separately running OpenCode server; it does not run the Android root filesystem or Linux binaries on iOS. A true on-device engine requires a separate iOS-compatible runtime implementation.

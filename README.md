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

## Deploy a cloud server (no PC required)

This repository now includes a Dockerfile and Railway configuration for hosting the real OpenCode server. The iPhone app connects to that server over HTTPS; the server, workspace, sessions, and provider credentials live in the cloud volume.

1. Open [Railway](https://railway.com/) in Safari and sign in.
2. Create a new project and choose **Deploy from GitHub repo**.
3. Select `h94676864-source/IOS-opencode` and branch `ios/local-port`. Railway detects the included `Dockerfile`.
4. In the service's **Variables**, add `OPENCODE_SERVER_PASSWORD` with a long, unique password. Do not reuse a password from another account.
5. In **Settings → Volumes**, add a persistent volume mounted at `/data`. This preserves OpenCode settings, provider credentials, sessions, and workspace files across deploys.
6. In **Settings → Networking**, generate a public HTTPS domain and wait for the deployment to become healthy.
7. The iPhone app now starts with `https://ios-opencode-production.up.railway.app` prefilled. In Connection settings, confirm the generated URL, enter username `opencode` and the exact password from step 4, then tap **Save and connect**.

Railway hosting may incur charges; check its current plan and usage before deploying. The OpenCode server is password-protected, but it can run shell commands and access files in its workspace: keep the URL and password private. Configure an OpenCode model/provider from the OpenCode UI or supported provider-auth flow before sending prompts. Provider API usage may incur separate charges.

The container runs `opencode web` on Railway's injected `PORT` and binds to `0.0.0.0`, so the same OpenCode browser interface opens inside the iOS app. Locally, the container defaults to port `4096`. Do not publish the service without setting `OPENCODE_SERVER_PASSWORD`.

## Connect an iPhone to a computer running OpenCode

OpenCode binds to `127.0.0.1` by default, which is only reachable from the computer itself. For a phone on the same trusted Wi-Fi network, start the server so it listens on the LAN interface and protect it with a password.

macOS / Linux:

```sh
OPENCODE_SERVER_PASSWORD='choose-a-long-unique-password' opencode web --hostname 0.0.0.0 --port 4096
```

Windows PowerShell:

```powershell
$env:OPENCODE_SERVER_PASSWORD = "choose-a-long-unique-password"
opencode web --hostname 0.0.0.0 --port 4096
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

## Runtime architecture

The Android app runs a Linux/PRoot/Alpine environment and Linux OpenCode binaries. iOS cannot run that Android/Linux root filesystem or those Linux binaries as-is. The iOS app is a native client; the cloud Docker service runs the actual OpenCode engine. This gives the phone the OpenCode server's full tool/runtime capabilities without pretending the Linux engine runs inside iOS.

Matching Android's fully on-device behavior would require a separate iOS-compatible engine/runtime implementation.

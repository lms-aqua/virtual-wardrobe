# Virtual Wardrobe — iOS app

A SwiftUI app that connects to the Virtual Wardrobe API, signs the user in with
an email magic link, captures a guided 4-view body scan, uploads the photos to
private storage, and shows the generated (mock) 3D avatar plus a wardrobe.

## How it connects to "the domain"

The app talks to the backend at `AppConfig.baseURL`
([App/../Core/Config.swift](VirtualWardrobe/Core/Config.swift)):

- Default: `https://api.virtualwardrobe.app` — change this constant to your
  deployed API domain (e.g. a Caddy route on the Ubuntu box such as
  `https://wardrobe-api.losthosting.com`).
- Or set it at runtime: launch the app → gear icon (top-right of Welcome) →
  **Settings** → enter the URL. For the Simulator against a local backend use
  `http://localhost:8000` (an ATS exception for `localhost` is in `Info.plist`).

Auth uses a **bearer token** (not cookies): the app calls
`POST /auth/magic-link`, and in non-production the API returns a `dev_token` so
sign-in completes instantly. In production the user gets an email and pastes the
token into the app. The token is stored in the **Keychain**, never in
UserDefaults.

## Requirements

- Xcode 15+, iOS 17+ target, a device or Simulator.
- The backend running and reachable at the configured URL (see
  `../api` / `../../infrastructure/docker-compose.yml`), with sample garments
  seeded (`python -m scripts.seed`).

## Creating the Xcode project

These are plain Swift sources (no `.xcodeproj` is committed). To build:

1. Xcode → **New Project → iOS → App**. Product name `VirtualWardrobe`,
   Interface **SwiftUI**, Language **Swift**.
2. Delete the auto-generated `ContentView.swift` and the default `App` file.
3. Drag the `VirtualWardrobe/` folder from this directory into the project
   (**Copy items if needed**, create groups). Keep the folder structure
   (`App/`, `Core/`, `Views/`, `Scan/`).
4. In the target's **Info** tab, merge the keys from
   [VirtualWardrobe/Info.plist](VirtualWardrobe/Info.plist) — especially
   `NSCameraUsageDescription` (required, or the camera prompt crashes the app).
5. Set the deployment target to **iOS 17.0**.
6. Run on a real device for camera capture (the Simulator has no camera, but the
   rest of the flow — auth, wardrobe, privacy — works there).

## What the app does (matches the backend flow)

1. **Welcome / Sign in** — email + adult attestation → magic link.
2. **Consent** — explicit body-scan consent (`POST /consents`).
3. **Guided capture** — front / left / back / right with a silhouette overlay,
   framing box, and countdown ([Scan/ScanFlowView.swift](VirtualWardrobe/Scan/ScanFlowView.swift)).
4. **Upload** — presigned POST straight to private storage per view.
5. **Processing** — polls `GET /jobs/{id}` until the avatar is ready.
6. **Avatar** — shows the thumbnail (via a short-lived signed URL) + estimated
   measurements, clearly badged **MOCK**.
7. **Wardrobe** — sample garments; tap to build and save an outfit.
8. **Privacy** — sign out, and **Delete everything** (`POST /account/deletion-request`).

## Get an `.ipa` without your own Mac (→ AppDB)

You cannot compile SwiftUI on Windows/Linux — the Swift compiler and iOS SDK are
macOS-only. But GitHub's **cloud macOS runners** can compile it for you, and
**AppDB** signs + installs the result (no paid Apple Developer account needed).

1. Push this repo to GitHub.
2. Open **Actions → "iOS build (unsigned IPA)" → Run workflow** (or just push a
   change under `apps/ios/`). It runs [`.github/workflows/ios.yml`](../../.github/workflows/ios.yml):
   generates the Xcode project with XcodeGen ([project.yml](project.yml)),
   builds with signing disabled, and packages an **unsigned** `.ipa`.
3. Download the **`VirtualWardrobe-unsigned-ipa`** artifact from the run.
4. In **AppDB**: upload the unsigned `.ipa`, let AppDB sign it (with your linked
   Apple ID or AppDB's certificate), then install to your device.

Notes:
- macOS runner minutes are **free on public repos**; private repos have a
  limited monthly free allowance (macOS counts at a higher rate).
- The build is unsigned on purpose — AppDB (or AltStore/Sideloadly) does the
  signing. Don't add signing secrets unless you switch to TestFlight later.

## Notes / roadmap

- LiDAR/depth capture and RealityKit avatar rendering are Phase 7 "advanced";
  the capture engine ([Scan/CameraController.swift](VirtualWardrobe/Scan/CameraController.swift))
  is structured so depth capture drops in behind the same interface.
- Rendering the actual GLB on-device (SceneKit/RealityKit) is a follow-up; today
  the app shows the server-rendered thumbnail. The web viewer (Phase 5) renders
  the GLB in 3D.

# Virtual Wardrobe (iOS) — Changelog

The AltStore-visible changelog lives in `altstore-source.json`
(`apps[0].versions[].localizedDescription`). Bump the `version` there to release;
CI builds the `.ipa` at that exact version so AltStore detects the update.

## 1.0.0 — first full release
- **Try on clothes in 3D** — a rotatable, measurement-based 3D avatar (SceneKit)
  built from your body dimensions. Tap garments to dress it; outfits layer live.
- **Faster scanning** — 360° frames are downscaled and uploaded in parallel.
- **Measurements editor** — edit height/chest/waist/hip/inseam; avatar updates.
- **UX polish** — 3D "Try On" tab, haptics, toasts, accessibility labels,
  clearer honesty labeling ("measurement-based 3D preview").
- Honest scope: still a stylized preview, not photogrammetry/LiDAR (next).

## 0.1.2
- **Front camera by default** (selfie) so you can see yourself during the scan.
- **Front/Back toggle** — tap to switch cameras for other framing.

## 0.1.1
- **360° multi-frame body capture** — replaces the old 4-photo flow. Turn slowly
  and the app grabs ~24 frames with a live progress ring.
- **Live backend by default** (`wardrobe-api.losthosting.com`) — no server setup.
- **New app icon.**
- Backend now accepts many frames per scan (was fixed 4 views).

## 0.1.0
- Initial sideload build: magic-link auth, consent, 4-view guided capture,
  mock avatar, wardrobe, outfits, privacy controls.

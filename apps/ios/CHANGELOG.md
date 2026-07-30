# Virtual Wardrobe (iOS) — Changelog

The AltStore-visible changelog lives in `altstore-source.json`
(`apps[0].versions[].localizedDescription`). Bump the `version` there to release;
CI builds the `.ipa` at that exact version so AltStore detects the update.

## 0.1.1
- **360° multi-frame body capture** — replaces the old 4-photo flow. Turn slowly
  and the app grabs ~24 frames with a live progress ring.
- **Live backend by default** (`wardrobe-api.losthosting.com`) — no server setup.
- **New app icon.**
- Backend now accepts many frames per scan (was fixed 4 views).

## 0.1.0
- Initial sideload build: magic-link auth, consent, 4-view guided capture,
  mock avatar, wardrobe, outfits, privacy controls.

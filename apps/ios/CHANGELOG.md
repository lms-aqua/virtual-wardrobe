# Virtual Wardrobe (iOS) — Changelog

The AltStore-visible changelog lives in `altstore-source.json`
(`apps[0].versions[].localizedDescription`). Bump the `version` there to release;
CI builds the `.ipa` at that exact version so AltStore detects the update.

## 1.4.0
- **Cross-device sync** — units, avatar skin/build customization, and favorites
  sync to the account via `/me/preferences` (`PrefsSync`, `AuthStore`).
- **Shop** now shows real prices + Buy links (backend catalog populated).
- Avatar is now a real server-generated 3D mesh; scans process in the background.

## 1.3.0
- **AR magic mirror (beta)** — garments overlaid on your live body (`MirrorView`).
- **Fabric textures** — denim/stripes/plaid/knit patterns + sleeves (`PatternTextures`).
- **Measure from a photo** — Vision body-pose proportions (`PhotoMeasureView`).
- **Shop** — prices, recommended size, buy links (`ShopView`).
- **Favorites** — star outfits, sorted first (`Favorites`).
- **Spin-video export** — share a rotating clip (`AvatarVideoExporter`).

## 1.2.0
- **AR body measure (beta)** — ARKit body tracking captures real height/shoulder/
  arm/leg measurements (`ARMeasureView`), PATCHed to the avatar.
- **Avatar realism + customization** — hair, skin tones, body-build slider
  (`CustomizeView`, `Customization`).
- **Photo-import scan** — build an avatar from library photos (`PhotoImportView`).
- **Size recommendations** — per-garment size + fit note (`SizeRecommender`).
- **Add your own clothes** — local custom garments (`AddGarmentView`, `CustomGarments`).
- **Outfit compare** — two saved looks side by side (`OutfitCompareView`).

## 1.1.0
- **Camera presets** (Front / Side / Back) + **snapshot share** in the 3D try-on.
- **Category filters** (Tops/Dresses/Bottoms/Outerwear/Shoes).
- **Saved Outfits** screen — reopen in 3D, swipe to delete.
- **Settings hub** — units (cm/in), server, data & privacy, how-it-works, about.
- **Onboarding** walkthrough on first launch.
- Unit preference applied across measurements + dashboard.

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

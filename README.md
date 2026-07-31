<div align="center">

# 👗 Virtual Wardrobe

**A private, iPhone-first virtual try-on wardrobe.**
Scan your body → get a personalized 3D avatar → try on digital clothes → save outfits.

[![CI](https://github.com/lms-aqua/virtual-wardrobe/actions/workflows/ci.yml/badge.svg)](https://github.com/lms-aqua/virtual-wardrobe/actions/workflows/ci.yml)
[![iOS build](https://github.com/lms-aqua/virtual-wardrobe/actions/workflows/ios.yml/badge.svg)](https://github.com/lms-aqua/virtual-wardrobe/actions/workflows/ios.yml)
[![License](https://img.shields.io/badge/license-Proprietary-red.svg)](LICENSE)
[![Latest](https://img.shields.io/github/v/release/lms-aqua/virtual-wardrobe?sort=semver&label=latest)](https://github.com/lms-aqua/virtual-wardrobe/releases)

</div>

---

## 📲 Install on your iPhone

> Requires iOS 17+. The app is **sideloaded** (not on the App Store).

### Option A — AltStore (one tap to add the source)

<div align="center">

[![Add to AltStore](https://img.shields.io/badge/AltStore-Add%20Source-6D5EFC?style=for-the-badge&logo=apple&logoColor=white)](altstore://source?url=https%3A%2F%2Fraw.githubusercontent.com%2Flms-aqua%2Fvirtual-wardrobe%2Fmain%2Fapps%2Fios%2Faltstore-source.json)

</div>

1. Install **AltStore** on your iPhone (see [altstore.io](https://altstore.io)).
2. **Tap the button above on your iPhone** — it opens AltStore and adds the Virtual Wardrobe source. *(If it doesn't, in AltStore go to **Browse → Sources → +** and paste:)*
   ```
   https://raw.githubusercontent.com/lms-aqua/virtual-wardrobe/main/apps/ios/altstore-source.json
   ```
3. Open the source, tap **Virtual Wardrobe → Get / Update**. Every release shows its own changelog, and updates appear automatically.

### Option B — AppDB (easiest, no computer)

Download the latest `.ipa` and install it in AppDB (My App Store → upload → sign → install):

**➡️ [Download the latest .ipa](https://github.com/lms-aqua/virtual-wardrobe/releases/download/ios-latest/VirtualWardrobe-unsigned.ipa)**

### Option C — Sideloadly / ESign / TrollStore

All take the same `.ipa` above. TrollStore installs it permanently with no Apple ID (on supported iOS versions). Full per-tool steps: [`apps/ios/README.md`](apps/ios/README.md).

### 🗂️ Every version is kept

Each release is archived permanently at **[Releases](https://github.com/lms-aqua/virtual-wardrobe/releases)** (`v1.0.0`, `v1.1.0`, …), and AltStore shows the **full changelog history** for every version.

---

## ✨ Features

- **Guided body capture** — 360° camera scan, import from photos, or AR/LiDAR measure.
- **Personalized 3D avatar** — a smooth, measurement-driven body you can rotate, zoom, and customize (skin tone, build).
- **Try on clothes in 3D** — dress your avatar, layer outfits, filter by category, and save looks.
- **Size recommendations, favorites, shop links, spin-video export, outfit compare.**
- **Cross-device sync** — units, customization, and favorites follow your account.
- **Privacy-first** — adults-only consent, private storage, short-lived signed URLs, no face recognition, and one-tap permanent deletion of everything.
- **Web viewer** — open your avatar in any browser (react-three-fiber).

## 🏗️ Tech

| Layer | Stack |
| --- | --- |
| **iOS** | SwiftUI, ARKit, Vision, SceneKit (iOS 17+) |
| **Backend** | FastAPI, PostgreSQL, Redis + Dramatiq worker, MinIO/S3, SQLAlchemy + Alembic |
| **Avatar** | Parametric SDF body → marching cubes → GLB (trimesh + scikit-image) |
| **Web** | Next.js 15, React 19, react-three-fiber |
| **Infra** | Docker Compose, Caddy + Cloudflare Tunnel, GitHub Actions CI |

```text
apps/
  ios/     SwiftUI app (+ XcodeGen project, AltStore source)
  api/     FastAPI backend + worker (wardrobe_core)
  web/     Next.js web app + 3D viewer
infrastructure/  docker-compose, backup script
docs/      architecture, ADRs, runbooks
```

## 🔒 Honest limitations

The avatar is a **stylized parametric body shaped by your measurements** — it is **not** photogrammetry, SMPL-X, a digital twin, or a likeness of the person's face. Garments render as fitted shells, not physically-simulated cloth. Avatar generation, scan-quality scoring, and garment fitting are mock/measurement-based behind swappable provider interfaces, leaving room for real CV/body-model systems later.

## 🛠️ Development

```bash
# Backend
cd apps/api && python -m venv .venv && . .venv/bin/activate
pip install ".[dev]" && pytest -q && ruff check .

# Web
cd apps/web && npm ci && npm run typecheck && npm run build && npm run dev

# Full stack
cp .env.example .env   # set secrets
docker compose -f infrastructure/docker-compose.yml up --build
```

See [`docs/architecture.md`](docs/architecture.md) and [`docs/runbook-db.md`](docs/runbook-db.md).

## ⚖️ License

**Proprietary — © 2026 Lost Media Studios. All rights reserved.** This code is
**not** open source. You may not use, copy, modify, reuse, or redistribute it
without written permission. See [LICENSE](LICENSE).

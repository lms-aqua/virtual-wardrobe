# Virtual Wardrobe

A privacy-first, iPhone-first virtual clothing try-on platform. Build a
personalized 3D avatar from a guided body scan, dress it with digital garments,
rotate and compare outfits, and sync across iPhone, iPad, and desktop browsers.

> **Privacy is the product.** Body scans are treated as highly sensitive data:
> explicit adult consent, private storage only, short-lived signed URLs, raw
> images deleted after avatar generation, no face recognition, and a one-tap
> permanent delete. Mock avatar generation is clearly labeled — this MVP makes
> **no** claim of tailoring- or medical-grade accuracy.

See [`docs/architecture.md`](docs/architecture.md) for the full design.

## Repository layout

```text
apps/
  web/      Next.js 15 + React 19 + (R3F/Three in Phase 5) — responsive PWA
  api/      FastAPI + Pydantic + SQLAlchemy async + Alembic  (wardrobe_core pkg)
  worker/   Dramatiq consumer (shares wardrobe_core with the API)
  ios/      SwiftUI + ARKit/RealityKit  (Phase 7)
packages/   shared-types, ui, three-viewer, validation, config
infrastructure/  docker-compose.yml, caddy fragment, seed data
docs/       architecture, ADRs, troubleshooting
```

## Prerequisites

- Docker + Docker Compose (primary path)
- Node 20+ and pnpm 9+ (for local web dev outside Docker)
- Python 3.12+ (for local API dev outside Docker)

## Quick start (Docker — recommended)

```bash
cp .env.example .env
# edit .env: set SECRET_KEY, POSTGRES_PASSWORD, S3 keys to real random values
cd infrastructure
docker compose up --build
```

Services:

| Service   | URL                          | Notes                          |
| --------- | ---------------------------- | ------------------------------ |
| Web       | http://localhost:3000        | landing/privacy pages          |
| API       | http://localhost:8000        | `/docs` (dev only), `/health/*`|
| MinIO     | http://localhost:9001        | console (dev only)             |
| MailHog   | http://localhost:8025        | magic-link emails in dev       |

Health checks:

```bash
curl http://localhost:8000/health/live
curl http://localhost:8000/health/ready
```

## Local API dev (without Docker)

```bash
cd apps/api
python -m venv .venv && . .venv/bin/activate    # Windows: .venv\Scripts\activate
pip install ".[dev]"
export SECRET_KEY=dev-only-change-me             # Windows: $env:SECRET_KEY="..."
pytest -q
ruff check .
mypy wardrobe_core
uvicorn wardrobe_core.main:app --reload
```

## Local web dev (without Docker)

```bash
pnpm install
pnpm --filter @vw/web dev
```

## Root scripts

```bash
pnpm dev        # turbo: run all dev servers
pnpm lint       # turbo: lint all packages
pnpm test       # turbo: test all packages
pnpm test:e2e   # Playwright end-to-end (Phase 6)
```

## Security posture (summary)

- Private object-storage buckets only; no anonymous policy is ever applied.
- Short-lived (5 min) signed URLs, minted only after an ownership check.
- Strict server-side upload validation (size cap + MIME allowlist + magic-byte
  re-check on completion). Client filenames and MIME types are never trusted.
- Ownership middleware on every resource route; cross-account access returns 404.
- Secure/httpOnly/SameSite session cookies, CSP, HSTS (prod), rate limiting.
- Structured audit logging that never records raw scans, tokens, or signed URLs.
- Account/scan hard-deletion with a test that proves assets 404 afterward.
- Secrets only via environment; `.env` is git-ignored, only `.env.example` ships.

## Roadmap

Phases 1–2 (architecture + foundation) are in place. Phase 3 adds auth, consent,
private storage, signed uploads, authorization tests, and deletion. See
`docs/architecture.md` for the full phase plan and the MVP-vs-future boundary.

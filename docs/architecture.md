# Virtual Wardrobe — Architecture

## 1. Overview

Privacy-first, iPhone-first virtual try-on. Three clients (web PWA, native iOS,
worker) share one FastAPI backend backed by Postgres, Redis, and S3-compatible
**private** object storage. Every computer-vision-heavy step is hidden behind a
swappable provider interface so the MVP runs end-to-end on deterministic mocks
and later swaps in SMPL-X / LiDAR / a commercial API without touching product
code.

```
iOS (ARKit/LiDAR) ─┐
Web (R3F/Three)  ─┼─ HTTPS ─▶ FastAPI ─▶ Postgres (source of truth)
Desktop web      ─┘             │  │
                                │  ├─ presign ─▶ MinIO/S3 (private buckets)
                                └─ enqueue ─▶ Redis ─▶ Worker (Dramatiq)
                                                        ├ ScanQualityService (mock)
                                                        ├ AvatarGenerationProvider (mock)
                                                        ├ MeshOptimizer → GLB/LOD
                                                        └ GarmentFittingEngine (measure-scale)
```

Deployment target: single `docker compose` stack on an Ubuntu host, fronted by
Caddy for TLS. This app uses its **own** auth (magic link + Sign in with Apple),
so it is not double-gated by Authelia.

## 2. Service boundaries

- **api** — auth, consent, resource CRUD, signed-URL minting, authorization.
  Owns no CV logic; delegates to providers via the worker.
- **worker** — all long-running / CV tasks (validation, avatar fit, mesh
  optimize, thumbnail, garment fit). Retryable, observable, structured errors.
- **wardrobe_core** — shared package (models, config, providers, services) used
  by both api and worker so they never drift.
- **web** — responsive UI + reusable `three-viewer` package.
- **ios** — best-in-class capture; uploads to the same backend (Phase 7).

## 3. Data model

UUID PKs; `created_at`/`updated_at`; FK constraints; ownership columns; status
enums. Tables: `users`, `user_consents`, `devices`, `sessions`, `body_scans`,
`scan_images`, `scan_jobs`, `avatars`, `avatar_measurements`, `garments`,
`garment_assets`, `garment_sizes`, `outfits`, `outfit_items`,
`processing_jobs`, `audit_events`, `deletion_requests`.

Raw `scan_images` (and their objects) are **hard-deleted**; account/avatar use
soft-delete where legally sane. Consent is append-only; scanning requires an
active `scan` consent, model-training reuse a separate `train` consent
(default off).

## 4. Job lifecycle

`created → uploading → uploaded → validating → queued → processing →
optimizing → completed | failed → deleting → deleted`. Jobs carry structured
`error_code`s (not just free text) and idempotency keys on creation endpoints.

## 5. Privacy & security decisions

See [ADR-0002](adr/0002-privacy-security-baseline.md). Highlights: private
buckets only, 5-min signed URLs minted post-ownership-check, ephemeral raw
images, no face recognition, right-to-erasure with a verifying test,
server-side upload hardening, secure cookies + CSP + HSTS + rate limiting,
audit logging that never records sensitive payloads, cross-tenant access tests
as first-class deliverables.

## 6. Mock vs. real

| Concern            | MVP (mock, labeled)                     | Future (interface ready)              |
| ------------------ | --------------------------------------- | ------------------------------------- |
| Avatar generation  | parametric template fit to measurements | SMPL-X, multi-view, LiDAR, vendor API |
| Scan quality       | deterministic image checks              | ML pose/occlusion/full-body           |
| Garment fitting    | measurement scaling + collision offsets | PBD / NVIDIA cloth / learned try-on   |

## 7. Technical risks

1. **Perceived accuracy** — users may over-trust the mock avatar. Mitigation:
   explicit labeling, confidence display, manual measurement correction.
2. **Mobile 3D performance** — high-poly meshes stall on phones. Mitigation:
   LOD, Draco, texture compression, reduced-quality mode, asset-size budgets.
3. **Sensitive-data handling** — scans are the crown jewels. Mitigation: the
   full ADR-0002 baseline plus automated authorization + deletion tests.
4. **Vendor lock-in** — avoided via `AvatarGenerationProvider` /
   `GarmentFittingEngine` / `ScanQualityService` abstractions.
5. **Apple sign-in / capture complexity** — deferred to Phase 7 behind a shared
   backend so web ships first.

## 8. Phase plan

1. Architecture (this doc). 2. Foundation. 3. Auth & privacy. 4. Mock scanning
pipeline. 5. Avatar viewer. 6. Clothing & outfits. 7. Native iOS. 8. Production
readiness. Work proceeds in order; each phase stops at a tested checkpoint.

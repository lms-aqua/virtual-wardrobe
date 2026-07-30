# ADR-0001: Swappable provider abstractions for CV-heavy steps

- Status: Accepted
- Date: 2026-07-30

## Context

Avatar reconstruction, scan-quality scoring, and garment draping are the
hardest, most vendor-specific parts of the system. Committing to one technology
(a specific SMPL-X pipeline, a cloud avatar API, a particular cloth simulator)
early would couple the whole product to it and block local end-to-end
development.

## Decision

Introduce three interfaces in `wardrobe_core.providers`:

- `AvatarGenerationProvider` — inputs: validated scan images + user
  measurements; output: mesh + measurements + confidence.
- `ScanQualityService` — inputs: images + metadata; output: quality score +
  structured reasons.
- `GarmentFittingEngine` — inputs: avatar + garment + size/fit; output: fitted
  garment transform/shape keys.

The MVP ships deterministic **mock** implementations, selected via configuration
and injected through dependency injection. Real implementations register against
the same interface later with no product-code changes.

## Consequences

- Full workflow runs locally with zero external CV cost.
- Mocks are clearly labeled in code and UI; no accuracy is claimed.
- Swapping a provider is a config + registration change, not a refactor.
- Interfaces must be versioned alongside `avatar.version` to keep garment
  compatibility coherent.

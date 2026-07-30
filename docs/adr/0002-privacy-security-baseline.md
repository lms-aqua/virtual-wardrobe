# ADR-0002: Privacy & security baseline for sensitive body data

- Status: Accepted
- Date: 2026-07-30

## Context

The platform processes highly sensitive body images and measurements. A breach
or an access-control mistake is a serious harm to real people. Security cannot
be retrofitted; it is a foundational, non-negotiable constraint.

## Decision

Adopt this baseline from Phase 2 onward (implemented in Phase 3):

1. **Consent gate** — no scan enters `validating` without an active adult
   `scan` consent. Model-training reuse requires a separate `train` consent,
   defaulting off. Consent records are append-only and versioned.
2. **Private storage only** — S3/MinIO buckets never receive an anonymous
   policy. All access is via short-lived (5 min) signed URLs, and a signed URL
   is minted only after the requester's ownership of the resource is verified.
3. **Ephemeral raw images** — after successful avatar generation, raw scan
   images and their objects are hard-deleted unless the user explicitly opts to
   retain them. A reaper enforces this.
4. **Right to erasure** — a deletion request hard-deletes scans/objects,
   tombstones avatar/measurements, revokes sessions, and writes an audit event.
   An automated test asserts assets 404 afterward.
5. **No face recognition** — never implemented. The capture UI lets users crop,
   blur, or omit the face; quality scoring treats an intentionally cropped head
   as valid.
6. **Upload hardening** — presigned PUT with enforced content-type + size cap;
   server re-validates magic bytes and a client-provided SHA-256 on completion.
   Client filenames and MIME types are never trusted.
7. **Transport + at rest** — TLS via Caddy; encrypted volumes for Postgres and
   object storage in production.
8. **App-layer defenses** — secure/httpOnly/SameSite cookies, strict CSP, HSTS
   in production, rate limiting, CSRF protection on cookie-auth mutations,
   authorization middleware returning 404 on cross-tenant access, structured
   audit logging that never records raw scans, tokens, or signed URLs.
9. **Secrets** — environment-only; `.env` is git-ignored; CI runs secret and
   dependency scanning.
10. **Cross-tenant tests are first-class** — automated proof that account A
    cannot read account B's scan, image, avatar, measurements, outfit, or
    signed URL ships with Phase 3.

## Consequences

- Slightly more up-front work per resource route (ownership checks, presign
  gating) — accepted as the cost of handling sensitive data responsibly.
- Deletion is genuinely destructive for raw scans; this is intentional and
  documented to users.

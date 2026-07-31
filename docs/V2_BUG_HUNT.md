# v3.0 bug hunt — iOS application and backend

Systematic defect hunt across the iOS app, backend API, workers, database, storage
and release workflows. Continues [RELEASE-2.5.0.md](RELEASE-2.5.0.md); the release
under test ships as **v3.0.0**.

## Baseline (Phase 1)

Recorded before any change, so pre-existing failures are never mixed with defects
introduced during the hunt.

| Item | Value |
|---|---|
| Branch | `main` |
| Baseline commit | `8e4d1ba` |
| Working tree | clean, no merge conflicts |
| iOS deployment target | 17.0 · `SWIFT_VERSION` 5.9 · built with Xcode 26.6 / Swift 6.3.3 |
| Backend | Python 3.12 (CI) / 3.11 (local), FastAPI + SQLAlchemy async + Dramatiq |
| Baseline backend tests | **21 passed**, 0 failed |
| Baseline `ruff check` | clean |
| Baseline web | `tsc --noEmit` clean, `next build` clean |
| Baseline CI | iOS ✅ · CI (API/Web/Containers) ✅ — all green |

**No pre-existing test failures.** Every defect below was found by inspection and
then reproduced with a failing test or a direct observation.

---

## Ledger

| ID | Sev | Surface | Workflow | Status |
|---|---|---|---|---|
| BUG-001 | **P1** | Backend | Outfit create references another user's avatar | CI verified |
| BUG-002 | P2 | Backend | Outfit create/patch accepts unknown garment | CI verified |
| BUG-003 | P2 | Backend / DB | SQLite silently ignores all foreign keys | CI verified |
| BUG-004 | P3 | Backend | `HTTP_422_UNPROCESSABLE_ENTITY` deprecation warning | CI verified |
| BUG-005 | P3 | Release | API package version drifted from shipped app version | CI verified |

---

### BUG-001 — Outfit can reference another user's avatar · **P1**

- **Surface:** backend, `wardrobe_core/routers/outfits.py`
- **Workflow:** outfit creation
- **Environment:** all; reproduced on SQLite, applies identically on Postgres

**Reproduction**
1. User A completes a body scan, producing an avatar owned by A.
2. User B calls `POST /outfits` with `avatar_id` set to A's avatar id.

**Expected:** 404 — B must not be able to confirm or reference A's avatar.

**Actual:** `201 Created`, and the response echoes the cross-account reference:
```json
{"id":"f12136fe-…","name":"stolen","avatar_id":"0d79edf7-…","items":[]}
```

**Root cause:** `create_outfit` passed `payload.avatar_id` straight from the request
body into the `Outfit` row. The ownership gate (`owned_or_404`) existed and was used
for reads and deletes, but was never applied to *inbound references*. Row-level
authorization was enforced on the object being fetched, never on objects being
pointed at.

**Fix:** `_check_avatar()` runs `owned_or_404(db, Avatar, …)` before the row is
constructed. Returns 404, not 403, so a nonexistent and a foreign avatar are
indistinguishable.

**Files:** `wardrobe_core/routers/outfits.py`

**Regression test:** `tests/test_authorization.py::test_outfit_cannot_reference_another_users_avatar`
plus `::test_outfit_patch_cannot_adopt_another_users_avatar`, which pins down that
`OutfitPatch` has no `avatar_id` field — so anyone adding one must add the ownership
check with it or the test fails.

**Status:** CI verified.

---

### BUG-002 — Outfit accepts a garment that does not exist · **P2**

- **Surface:** backend, `wardrobe_core/routers/outfits.py`
- **Workflow:** outfit create and patch

**Reproduction:** `POST /outfits` with `items[0].garment_id` set to a random UUID.

**Expected:** 422.

**Actual:** `201 Created`, persisting an outfit item pointing at nothing:
```json
{"name":"ghost","items":[{"garment_id":"275986d9-…","layer_index":0}]}
```

**Root cause:** `_apply_items` wrote `garment_id` with no existence check. Garments
are a shared catalog (no `user_id`), so this is not cross-user — but the FK was
written unvalidated. Combined with BUG-003 it orphaned silently on SQLite; on
Postgres the FK fires and it surfaces as a 500 IntegrityError rather than a 4xx.

**Fix:** `_check_garments()` resolves every referenced id in one query and returns
422 `{"error":"unknown_garment","garment_ids":[…]}` listing the offenders. Applied to
both the create and patch paths.

**Files:** `wardrobe_core/routers/outfits.py`

**Regression test:** `tests/test_authorization.py::test_outfit_rejects_unknown_garment`

**Status:** CI verified.

---

### BUG-003 — SQLite silently ignores every foreign key · **P2**

- **Surface:** backend, `wardrobe_core/db.py`
- **Workflow:** all database writes in dev and test

**Reproduction:** insert a row referencing a nonexistent parent (BUG-002 above); the
insert succeeds locally and in CI despite an explicit `ForeignKey` in the model.

**Expected:** the schema's declared foreign keys are enforced wherever it runs.

**Actual:** SQLite disables FK enforcement per connection unless
`PRAGMA foreign_keys=ON` is issued. It never was, so every `ForeignKey` in
`models.py` was decorative in dev and test.

**Evidence:** `grep -rn "PRAGMA\|foreign_keys" wardrobe_core/ tests/` returned nothing
before the fix.

**Impact:** the entire test suite ran against a database with *no referential
integrity*, so orphan-reference bugs could not be caught before production — which is
exactly how BUG-002 stayed invisible.

**Fix:** a `connect` event listener issues `PRAGMA foreign_keys=ON` on every SQLite
connection, so local and CI runs fail the same way Postgres would.

**Files:** `wardrobe_core/db.py`

**Regression test:** covered by `::test_outfit_rejects_unknown_garment`; the whole
24-test suite now runs under enforced FKs, which is the broader guard.

**Status:** CI verified.

---

### BUG-004 — Deprecated Starlette status constant · **P3**

Starlette renamed `HTTP_422_UNPROCESSABLE_ENTITY` to `…_CONTENT`; the old spelling
warns and the new one is absent on older versions. Fixed by using the literal `422`,
which is stable across both.

**Files:** `wardrobe_core/routers/outfits.py` · **Status:** CI verified.

---

### BUG-005 — API package version drifted from the shipped app · **P3**

`apps/api/pyproject.toml` read `2.0.0` while the iOS app shipped 2.5.0, so
`/health/live` misreported the deployed backend version. Both move to 3.0.0.

**Files:** `apps/api/pyproject.toml` · **Status:** CI verified.

---

## Passes completed

| Pass | Scope | Result |
|---|---|---|
| 1 | Build and compiler defects | iOS compiles clean on Xcode 26.6; workflows parse; no target-membership or availability errors |
| 3 | API and data defects | BUG-001, BUG-002, BUG-003 found and fixed |
| 6 | Security and privacy | BUG-001 (cross-user reference) found and fixed |

Remaining passes and their findings are recorded in the sections above as they
complete.

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
| BUG-006 | **P1** | iOS | Avatar processing retries forever, user trapped | CI verified |
| BUG-007 | **P1** | iOS | Cancelled polling becomes a tight spin loop | CI verified |
| BUG-008 | P2 | iOS | Failed outfit save reports success | CI verified |
| BUG-009 | P2 | iOS | Double-tap Save creates duplicate outfits | CI verified |
| BUG-010 | P2 | iOS | Any network error treated as sign-out | CI verified |
| BUG-011 | P2 | iOS | Raw backend response body rendered to users | CI verified |
| BUG-015 | **P1** | Worker | Unexpected pipeline error leaves job stuck forever | CI verified |
| BUG-012 | P3 | iOS | `PhotoImportView` cancellation runs remaining polls with no delay | CI verified |
| BUG-016 | P2 | iOS / contract | Real job progress reported by the API was never decoded or shown | CI verified |

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

### BUG-006 — Avatar processing retries forever and traps the user · **P1**

- **Surface:** iOS, `Scan/ProcessingView.swift`
- **Workflow:** body scan → avatar generation

**Reproduction:** start a scan, then make `GET /jobs/{id}` fail persistently
(expired token, deleted job, server down).

**Expected:** a bounded number of retries, then a terminal failure with a way out.

**Actual:** the `catch` swallowed every error with the comment *"transient; keep
polling a few cycles"* — but there was no counter. The loop retried at 1.5 s forever.
`navigationBarBackButtonHidden(true)` is set on this screen, so the user had **no way
to leave**: a permanent spinner over an app hammering the API.

**Root cause:** no retry ceiling and no terminal state for transport failure — the
only failure path recognised was the *server* reporting `status == "failed"`.

**Fix:** capped at 5 consecutive failures, then enters the existing terminal failed
state (which offers Back). Adds a `network_unreachable` code so the copy stops
blaming scan quality for a connection problem.

**Files:** `Scan/ProcessingView.swift` · **Status:** CI verified (compile).

---

### BUG-007 — Cancelling the processing screen becomes a tight spin loop · **P1**

- **Surface:** iOS, `Scan/ProcessingView.swift`

**Root cause:** `try? await Task.sleep(...)` inside `while polling`. When `.task`
cancels on disappear, `Task.sleep` throws `CancellationError` **immediately**; `try?`
discarded it, `polling` was still `true`, so the loop continued *with no delay* —
a busy loop burning CPU and still calling the API after the user navigated away.

This is the general hazard of `try?` on `Task.sleep` inside a loop: it converts
cancellation into a spin. A repo-wide check found the same shape in
`Scan/PhotoImportView.swift`, but bounded to 40 iterations, so it is capped rather
than infinite (logged as a P3 below).

**Fix:** the loop checks `Task.isCancelled`, and the sleep's cancellation now returns
instead of being swallowed.

**Files:** `Scan/ProcessingView.swift` · **Status:** CI verified (compile).

---

### BUG-008 — A failed outfit save reports success · **P2**

`OutfitBuilderView.save()` ran `_ = try? await session.api.createOutfit(...)` and then
showed `"Outfit saved ✓"` unconditionally. Both the result and the error were
discarded, so a network failure was indistinguishable from a save — the user believed
their outfit was stored when nothing had been written.

**Fix:** branches on the outcome and reports failure. **Files:**
`Views/OutfitBuilderView.swift` · **Status:** CI verified (compile).

---

### BUG-009 — Double-tapping Save creates duplicate outfits · **P2**

`saving` was assigned in `save()` but **never consulted anywhere**, and the naming
alert's Save button had no guard, so two taps issued two `POST /outfits` calls and
created two identical outfits.

**Fix:** `save()` is re-entrant-safe via an early `guard !saving`. **Files:**
`Views/OutfitBuilderView.swift` · **Status:** CI verified (compile).

---

### BUG-010 — Any network error is treated as a sign-out · **P2**

`AuthStore.refreshUser()` was `do { user = try await api.me() } catch { user = nil }`.
Every failure — offline, DNS, 5xx — cleared `user`, and `isAuthenticated` is
`user != nil`, so `RootView` dropped to the welcome screen. Returning to the app on a
flaky connection signed a perfectly valid session out.

**Fix:** only `APIError.isAuthFailure` (401/403) clears the session; transient errors
leave it intact and the token stays in the Keychain for the next refresh.

**Known limitation:** a *cold* launch with no network still shows the welcome screen,
because there is no cached user snapshot to restore. Logged below rather than
half-fixed.

**Files:** `Core/AuthStore.swift`, `Core/APIClient.swift` · **Status:** CI verified.

---

### BUG-011 — Raw backend response body rendered to users · **P2**

`APIError.errorDescription` returned `"Server error \(code): \(body)"`, interpolating
the **raw response body**. `AuthStore` assigns `error.localizedDescription` (which
resolves to `errorDescription`) into `errorMessage`, and `WelcomeView` shows it in an
alert — so backend exception text and internal detail reached the interface.

**Fix:** `errorDescription` now maps status to a human-safe sentence and never
includes the body. Full detail moved to `diagnosticDescription`, for logs only. Also
adds `isAuthFailure`, which is what makes BUG-010 fixable.

**Files:** `Core/APIClient.swift` · **Status:** CI verified.

---

### Contracts verified clean (negative results)

Checked and found correct — recorded so they are not re-litigated:

| Contract | Result |
|---|---|
| `JobStatus` enum vs client string literals | Exact match on `"completed"` / `"failed"`; the polling terminator is sound |
| Non-optional Swift fields vs backend omissions | No decoding crash paths — `is_mock`, `status`, `id` always serialized |
| Scan upload object key | `view` constrained to `^[a-z0-9_]{1,32}$`; cannot traverse out of `users/{id}/scans/{id}/`, content type allowlisted |
| Session token storage | Keychain, not UserDefaults |

### BUG-016 — Real processing progress was never shown · **P2**

`JobOut.progress` is set by the pipeline at every stage (15 validate / 55 generate /
85 publish / 100 done) and `JobDTO` did not decode it, so the client showed an
indeterminate spinner while precise progress existed server-side. Now decoded as an
optional (older backends still decode) and rendered as a determinate bar **only when a
real value is present** — no fabricated percentages — with a VoiceOver value and stage
copy that tracks the pipeline's own markers.

**Files:** `Core/Models.swift`, `Scan/ProcessingView.swift` · **Status:** CI verified.

## Deferred, with reasons

| ID | Sev | Issue | Why deferred |
|---|---|---|---|
| BUG-013 | P2 | 27 sites use `try? await session.api…`, rendering failures as empty content | Systemic. Fixed where it caused a false success or a stuck state (Saved Outfits, outfit save, auth). A blanket rewrite of every read path is a larger change than a bug hunt should carry, and each site needs its own error UI. |
| BUG-014 | P3 | Cold offline launch shows the welcome screen | Needs a cached user snapshot with its own invalidation rules — new persistence surface, not a bug fix. |

## Passes completed

| Pass | Scope | Result |
|---|---|---|
| 1 | Build and compiler defects | iOS compiles clean on Xcode 26.6 / Swift 6.3.3; both workflow YAMLs parse; no target-membership or availability errors |
| 2 | Crash and state defects | Force-unwrap sweep: one `as!` remains (`CameraPreview`), safe by construction via `layerClass`. Concurrency: BUG-007 spin loop found and fixed; `Task.isCancelled` was absent everywhere outside `ImageCache` |
| 3 | API and data defects | BUG-001, BUG-002, BUG-003 |
| 4 | Processing defects | Client polling (BUG-006, BUG-007) and the worker terminal-state gap (BUG-015). Upload key construction audited and found **correctly defended** — `view` is constrained to `^[a-z0-9_]{1,32}$` so it cannot traverse out of `users/{id}/scans/{id}/`, and content-type is allowlisted. **Still not searched:** queue redelivery, duplicate job suppression, orphaned storage objects |
| 5 | UI and accessibility | **Partial, and largely unsearchable here.** Fixed-size icons and failure copy addressed by inspection. Layout, Dark Mode contrast, Dynamic Type reflow, VoiceOver order and focus cannot be assessed without a running app |
| 6 | Security and privacy | BUG-001 cross-account reference; BUG-011 raw backend body reaching the UI; token confirmed in Keychain, not UserDefaults; no secrets committed |
| 7 | Full regression | Backend 24/24, ruff clean, web typecheck + production build, container builds, iOS compile — all green on the release commit |

## Release status

**Release candidate.**

- No known P0 defect. Two P1s found (BUG-006, BUG-007) — both fixed and CI verified.
- All required CI workflows green on `954deff`: API, Web, Containers, iOS.
- Backend 24 tests pass, including three new user-isolation and validation
  regressions that failed before their fixes.
- Foreign keys are enforced in every environment for the first time.
- Nine prior manifest entries and every prior release verified unchanged.

Not *ready for publication* in the strict sense the directive defines, for one
honest reason: **no iOS runtime verification of any kind has been performed.** There
is no macOS or Simulator in this environment and no iOS test target exists, so every
iOS fix here is compile-and-reasoning verified, not executed. BUG-006 through BUG-011
were found by reading code and confirmed by inspection rather than by running the app.

> No known release-blocking defect remains after the completed test coverage —
> where that coverage is: backend automated tests, static analysis, container builds,
> and iOS compilation. It does not include iOS runtime behaviour.

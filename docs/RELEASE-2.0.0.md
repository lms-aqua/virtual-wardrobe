# Virtual Wardrobe v2.0.0 — release record

**Release date:** 2026-07-31
**Permanent tag:** `v2.0.0` · **Moving pointer:** `ios-latest`
**Marketing version:** 2.0.0 · **iOS build number:** 19 (from `github.run_number`)

Single source of truth for the version is `apps/ios/altstore-source.json`; the iOS
workflow reads it and stamps `CFBundleShortVersionString` from it, so the manifest
and the binary cannot drift apart.

---

## What shipped

### Redesigned
- **Design system.** `DS.swift` gained semantic radius roles (compact/control/card/
  prominent), control sizes, image aspect ratios, section spacing, status typography,
  a Reduce-Motion-aware animation helper, and haptics reserved for meaningful outcomes.
- **Liquid Glass.** New `DSGlass.swift` applies glass as an *interaction* layer only —
  filter chips and the floating add control — never as a content background. Real
  `glassEffect`/`GlassEffectContainer` are gated on `#if compiler(>=6.2)` **and**
  `#available(iOS 26)`; iOS 17–18 get `.ultraThinMaterial` with a hairline edge, and
  Reduce Transparency gets an opaque surface. Deployment target stays iOS 17.0.
- **Wardrobe grid.** Skeleton grid replaces the full-screen spinner; single column at
  accessibility Dynamic Type sizes; garment names wrap to two lines instead of
  truncating; per-cell spinners replaced with a static fill; filters are one compact
  chip row with "All" as the direct reset; secondary actions moved to a long-press
  context menu; primary action floats in a bottom safe-area inset so it can never
  cover the last row.

### Improved
- **Accessibility.** Dynamic Type through to accessibility sizes, richer VoiceOver
  labels (name, category, brand or ownership, price, favorite), Reduce Motion and
  Reduce Transparency honored, and status that always carries icon + text + shape
  rather than color alone.
- **Copy.** User-facing language throughout; error states no longer surface transport
  detail.
- **Previews.** 12 `#Preview` cases covering normal, dark, accessibility XXXL, Reduce
  Transparency, long names, missing images, skeleton, empty, error, status badges and
  glass controls. All fixtures live inside `#if DEBUG` and cannot reach a release build.

### Fixed
- **Historical release metadata was being rewritten on every build.** The manifest
  size-injection step stamped the new `.ipa` size onto *every* entry in the `versions`
  array. Now only the entry being built is touched, and the step hard-fails unless the
  manifest contains exactly one entry for that version (which also catches duplicates).
- **The manifest users actually add to AltStore was never updated.** The main README
  points at the raw `main` copy, but only the release asset received the corrected size.
  The workflow now commits the corrected manifest back to `main`.
- **Six historical entries served the wrong binary.** Versions 1.3.0 and older pointed
  their `downloadURL` at the moving `ios-latest` release, so selecting "1.3.0" in
  AltStore installed 2.0.0. Each now points at its own `v<version>` tag.
- **Rebuilds could overwrite a published release.** The publish step now refuses to
  touch an existing `v<version>` release unless the workflow is dispatched with
  `republish=true`.

### Backend and infrastructure
- CI runner moved `macos-15` → `macos-26`, pinned to the newest Xcode **26.x** rather
  than newest-installed so a future Xcode 27 preview on that image cannot silently
  swap the toolchain on a release build.
- New `containers` CI job builds the API/worker and web images and validates the
  Compose config against `.env.example` — which also proves the stack does not depend
  on uncommitted local files.

---

## Verification results

| Surface | Check | Result |
|---|---|---|
| iOS | Swift compile (Xcode 26.6, Swift 6.3.3, iPhoneOS26.5 SDK) | ✅ `BUILD SUCCEEDED` |
| iOS | GitHub Actions iOS workflow | ✅ green |
| iOS | Unsigned `.ipa` export + release upload | ✅ 952,894 bytes |
| Backend | `pytest` | ✅ 18 passed |
| Backend | `ruff check` | ✅ clean |
| Backend | `ruff format --check` | ⚠️ 20 files would reformat (not CI-gated — see limitations) |
| Web | `npm ci` (locked versions) | ✅ |
| Web | `tsc --noEmit` | ✅ clean |
| Web | `next build` (production) | ✅ 4 routes generated |
| Manifest | JSON parse, 8 entries, no duplicates, all HTTPS | ✅ |
| Workflows | YAML parse (`ios.yml`, `ci.yml`) | ✅ |
| Release | `v2.0.0` download URL | ✅ HTTP 200 |
| Migrations | Schema changes required by v2.0 | ✅ none — v2.0 is UI-only |

### Verification level — stated precisely

- **Compiled:** all iOS code, against the real iOS 26 SDK.
- **Automated-test verified:** backend only (18 tests). There are no iOS unit or UI
  tests configured in this project.
- **Simulator verified:** ❌ not performed.
- **Screenshot reviewed:** ❌ not performed.
- **Physical-device verified:** ❌ not performed.

No macOS or iOS Simulator is available in the development environment, so every iOS
claim in this document is a compile/CI claim. The SwiftUI previews added in this
release can only be rendered on a Mac and have not been visually inspected.

---

## Security review summary

- No secrets, keys, certificates or provisioning profiles are committed. The only env
  file in the repository is `.env.example`, containing `change-me-*` placeholders.
- No debug output in shipped code (`print(` in Swift: 0; `console.log` in web: 0).
- One `as!` force cast exists (`Scan/CameraPreview.swift`), and it is safe by
  construction — `layerClass` is overridden to return that exact type. Left as-is;
  it is Apple's own idiom.
- `dev_token` (the magic-link auth bypass) is correctly gated: the API returns it only
  when `settings.is_production` is false. **See the deployment caveat below.**

---

## Known limitations — carried into v2.0

1. **The deployed box runs `WARDROBE_ENV=staging`, so the magic-link `dev_token` is
   returned in API responses.** Anyone can sign in as any email against that
   deployment. The code is correct; the environment is not. Fixing it requires
   `WARDROBE_ENV=production` plus working SMTP. **This is the single most important
   item before any public launch.**
2. **Two theme systems coexist.** The legacy `Theme` is still referenced by 25 files;
   the new `DS` by 7. The migration is deliberate and incremental — only the Wardrobe
   surface has moved so far. Not a bug, but it is unfinished.
3. **`ruff format` is not enforced in CI** and 20 files are unformatted. Reformatting
   them was deliberately excluded from this release so the release diff stays
   reviewable. Worth a separate formatting-only commit.
4. **The avatar remains a parametric, measurement-based 3D preview.** It is not
   photogrammetry, not SMPL-X, and has no face likeness. Labelled honestly in-app.
5. **The v1.4.0 release artifact is not the original 1.4.0 build.** It was overwritten
   before the publish gate existed, and the original binary is unrecoverable. Its
   manifest size was corrected to 901,084 bytes to match what actually downloads.
6. **Versions 1.3.0 and older have no artifact at all.** Their entries now point at
   `v<version>` tags that do not exist, so the download fails honestly rather than
   silently installing 2.0.0. Changelog text, version numbers and dates are preserved.
7. **iOS has no automated test target.** Nothing beyond compilation gates the app.

---

## Rollback plan

**Do not delete published releases.** History is preserved by policy; roll forward
instead.

| Situation | Action |
|---|---|
| v2.0.0 is broken for users | Re-point the moving pointer: download the v1.4.0 assets and `gh release create ios-latest` from them (or dispatch the workflow from the v1.4.0 commit). The permanent `v2.0.0` release stays in place. |
| A specific v2.0 defect | Bump `apps/ios/altstore-source.json` to `2.0.1`, add a new `versions[]` entry, push. The gate creates a fresh permanent release without touching v2.0.0. |
| Marking v2.0.0 problematic | Edit the `v2.0.0` release notes to state the defect and point at v2.0.1. Do not delete or re-tag it. |
| Backend regression | Redeploy the previous image from the box; `docker compose -f docker-compose.box.yml up -d --build` at the prior commit. |
| Database | **No v2.0 migration was applied**, so there is nothing to roll back. Existing v1 records are unaffected. |
| Disabling glass specifically | Glass is compile-gated. Building on a runner with Xcode < 26 (e.g. reverting `runs-on` to `macos-15`) drops every glass call back to the material fallback with no source change. |

**Previous known-good state:** app v1.4.0 · repo commit `5b9c66a`.

---

## Testing that could not be performed

- iOS runtime behavior of any kind: launch, auth, onboarding, tab navigation, wardrobe
  load, search, filtering, add garment, garment detail, avatar, body scan, try-on
  submission/processing/result, settings, sign-out, account deletion.
- Visual review in Light/Dark, Dynamic Type rendering, VoiceOver output, small vs large
  iPhone and iPad layouts.
- Network-failure, expired-auth, missing-image and processing-failure behavior on device.
- Container builds and Compose health checks locally — Docker is not installed on the
  development machine; these are covered by the new CI `containers` job instead.
- Install smoke test of the v2.0.0 `.ipa`. The download URL was verified to return
  HTTP 200; the binary was **not** installed or launched.

---

## Next planned version

**v2.1** — migrate the remaining surfaces off legacy `Theme` onto `DS` (Outfits, then
Avatar and Try-On), and add an iOS unit-test target so the app has a gate beyond
compilation. Blocking for public launch, independent of version: move the deployed
backend to `WARDROBE_ENV=production` with real SMTP.

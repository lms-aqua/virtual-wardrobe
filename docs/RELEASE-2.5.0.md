# Virtual Wardrobe v2.5.0 — release record

**Release date:** 2026-07-31
**Permanent tag:** `v2.5.0` · **Moving pointer:** `ios-latest`
**Marketing version:** 2.5.0 · **iOS build number:** 24
**IPA:** `VirtualWardrobe-unsigned.ipa`, 979,275 bytes

Continues [RELEASE-2.0.0.md](RELEASE-2.0.0.md). v2.0 rebuilt the Wardrobe surface;
v2.5 finishes the design-system migration across the rest of the app and adds the
feature work that was explicitly deferred out of v2.0.

---

## New

- **Outfit duplication.** Swipe or long-press any saved outfit to copy it. The copy
  is created server-side from the original's items so it is fully independent —
  editing it never touches the original. Names uniquify (`Look Copy`,
  `Look Copy 2`), in-flight state shows on the row, success gives a haptic and
  failure gives an alert.
- **Cached garment imagery, offline-capable.** `AsyncImage` kept no cache, so
  scrolling the wardrobe refetched and re-decoded the same thumbnails every time a
  cell returned to screen. `ImageCache` puts an `NSCache` of decoded images in front
  of a 200 MB `URLCache`; `CachedImage` resolves a hit synchronously in `init`, so a
  revisited cell paints immediately rather than flashing a placeholder. The
  `returnCacheDataElseLoad` policy means previously-seen garments still render with
  no connection.

## Redesigned

- **Light mode.** The app was hard-locked to dark via an app-wide
  `.preferredColorScheme(.dark)`. It now follows the system appearance, which also
  brings Increased Contrast and accent tinting along for free. The capture flow
  (`ScanContainer`, `PhotoImport`, `PhotoMeasure`) stays pinned dark deliberately —
  an immersive camera UI reads better that way, as Apple's own Camera does.
- **Legacy `Theme` retired to a shim.** Its tokens are now defined in terms of `DS`,
  so all 25 screens referencing it adapt without being rewritten. Every member is a
  concrete `Color` — both a `View` and a `ShapeStyle` — so existing
  `.ignoresSafeArea()`, `.stroke(_:)` and `.background(_:in:)` call sites compile
  untouched. The full-screen purple gradient resolves to a semantic surface and the
  accent→pink brand gradient resolves to the flat accent, since v2.0 bans decorative
  gradients. `.card()` and `PrimaryButtonStyle` delegate to the `DS` equivalents.
- **147 hardcoded colour call sites migrated.** `.white` foregrounds became label
  colours, `.white.opacity(n)` mapped to secondary/tertiary label by value, and
  translucent white fills became semantic surfaces. No raw white remains in view code.
- **New `DS.Color.onAccent`.** The bulk pass had wrongly turned white-on-accent text
  into a label colour, which would have rendered black-on-purple in light mode. The
  dashboard scan button, outfit toast and filter chips, the Buy pill, and the garment
  swatch glyph/ring/checkmark are on an explicit on-fill colour rather than reverted
  to raw white.

## Improved

- **Onboarding.** Added a Skip button — the only path through was previously tapping
  Next four times. The 72 pt hero symbol was fixed-size and ignored Dynamic Type; it
  now scales via `@ScaledMetric`. Page advance respects Reduce Motion, each slide is
  one VoiceOver element with a "Step N of 4" hint, and the decorative symbol is
  hidden from VoiceOver. Terminology matches the product (Body Scan, Avatar, Try On).

## Fixed

- **Saved Outfits reported network failures as an empty wardrobe.** `load()` was
  `try? … ?? []`, so a dropped connection rendered as "No saved outfits yet". It now
  has a real failed state with retry.
- **A failed outfit delete came back silently.** `remove()` deleted optimistically and
  swallowed the error, so the outfit reappeared on the next refresh with no
  explanation. It now restores the row and says what happened.
- **Fixed-size icons ignoring Dynamic Type** in the Saved Outfits empty state (44 pt)
  and onboarding (72 pt).

---

## Verification results

| Surface | Check | Result |
|---|---|---|
| iOS | Swift compile (Xcode 26.6, Swift 6.3.3, iPhoneOS26.5 SDK) | ✅ `BUILD SUCCEEDED`, clean on first attempt |
| iOS | GitHub Actions iOS workflow | ✅ green |
| iOS | `.ipa` export + release upload | ✅ 979,275 bytes, download URL HTTP 200 |
| Backend | `pytest` / `ruff check` | ✅ 21 passed / clean (unchanged this release) |
| Web | `tsc --noEmit` / `next build` | ✅ (unchanged this release) |
| Containers | image builds + Compose validate | ✅ |
| Manifest | 9 entries, no duplicates, all HTTPS | ✅ |
| Release integrity | 8 prior entries unchanged byte-for-byte | ✅ verified programmatically before commit |
| Release integrity | workflow log: "8 historical entries untouched" | ✅ |
| Release integrity | `v2.0.0` asset still 952,894 bytes, HTTP 200 | ✅ not clobbered |

### Verification level — stated precisely

- **Compiled:** all iOS code, against the iOS 26 SDK.
- **Automated-test verified:** backend only. No iOS test target exists.
- **Simulator verified:** ❌ · **Screenshot reviewed:** ❌ · **Physical-device verified:** ❌

**Light mode is the largest unverified risk in this release.** The migration is
mechanically complete and no raw white remains, but the app has never been *rendered*
in light appearance — there is no macOS or Simulator in this environment. Contrast
and legibility on every migrated screen need a visual pass on a device before this
build is promoted to anyone but testers. The on-accent regressions found and fixed
during the migration are exactly the class of defect a visual pass would catch more of.

---

## Known limitations

Carried from v2.0 unless noted.

1. **The deployed backend still runs `WARDROBE_ENV=staging`**, so the magic-link
   `dev_token` is returned and anyone can sign in as any email. Unchanged, and still
   the single most important item before a public launch.
2. **Light mode is unrendered** (above).
3. **`Theme` still exists as a shim.** It is no longer a second design system — every
   token resolves to `DS` — but the indirection remains until call sites are renamed.
4. `ruff format` is still not CI-enforced (20 files unformatted).
5. The avatar remains a parametric, measurement-based preview.
6. v1.4.0's artifact is still the pre-gate overwritten build; pre-1.4.0 versions have
   no artifact and their URLs 404 by design.
7. No iOS automated tests.

---

## Rollback

Same policy as v2.0 — roll forward, never delete a published release.

| Situation | Action |
|---|---|
| v2.5.0 broken for users | Recreate `ios-latest` from the v2.0.0 assets. `v2.5.0` stays published. |
| Light mode looks wrong on a screen | Re-adding `.preferredColorScheme(.dark)` in `VirtualWardrobeApp` restores v2.0 behaviour in one line, without reverting the colour migration. |
| A specific defect | Bump the manifest to 2.5.1, add a new `versions[]` entry, push. The publish gate creates a fresh release without touching v2.5.0. |
| Image cache misbehaving | `ImageCache.clear()` empties both tiers; deleting the app clears the disk cache. |
| Database | No migration in this release. |

**Previous known-good:** app v2.0.0 · commit `81e75d8`.

## Next planned version

Migrate the remaining call sites off the `Theme` shim so it can be deleted, add an
iOS test target, and get a real device pass on light mode.

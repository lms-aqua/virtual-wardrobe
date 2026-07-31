# Virtual Wardrobe — v2.0 Premium iOS Rebuild

_Phase 1: audit, data inventory, compatibility, and the rebuild plan._

## 0. Scope note & honest framing

The **existing app is a 3D-avatar virtual try-on app** (body scan → measurement-driven
avatar → dress it → save outfits), not a "photograph the clothes you own +
laundry/wear-tracking + calendar planner" app. The v2.0 spec describes the latter.
They overlap (garments, outfits, users, auth, images) but several concepts the spec
assumes — **user-owned wardrobe items with photos, laundry/clean state, wear count/
history, and a planner calendar** — **do not exist in the backend today**.

Per the data-preservation rule, we build the premium UI on the **real existing data**
and, where a spec feature needs data that isn't there, we either (a) derive it safely,
(b) put it behind a feature flag, or (c) list it as backend work — never fake it.

Constraint: iOS is **not compilable in this environment** (no macOS/Xcode). Every iOS
change is verified by the GitHub Actions unsigned-`.ipa` build (~5 min). The rebuild
therefore proceeds in **CI-verified increments**, not one blind pass.

---

## 1. Current architecture

- **Entry:** `App/VirtualWardrobeApp.swift` (SwiftUI `App`), `@StateObject AuthStore`,
  `.preferredColorScheme(.dark)`, `RootView` routes on auth.
- **Deployment target:** iOS 17. Swift 5.9. **100% SwiftUI**, no UIKit view controllers
  (UIKit used only for `UIImage`, haptics, `AVFoundation`, `ARKit`, `Vision`).
- **Project generation:** XcodeGen (`apps/ios/project.yml`) — no committed `.xcodeproj`.
- **Networking:** `Core/APIClient.swift` — async/await, bearer token, `JSONSerialization`
  bodies, typed Codable DTOs (`Core/Models.swift`).
- **Auth:** magic-link (dev token auto-completes in staging) + Keychain token
  (`Core/Keychain.swift`, `Core/AuthStore.swift`).
- **State:** `AuthStore` `ObservableObject`; per-screen `@State`/`@StateObject` view models
  (e.g. `ScanFlowModel`, `AvatarSceneController`).
- **Persistence (local):** `UserDefaults` for prefs (`Units`, `Customization`, `Favorites`,
  `CustomGarments`, onboarding flag) + Keychain for the token. No Core Data / SwiftData.
- **Images:** `AsyncImage` (`RemoteThumb`), `ImageUtils` downscale for uploads.
- **3D:** SceneKit (`AvatarBuilder`, `AvatarSceneController`), ARKit (`ARMeasureView`,
  `MirrorView`), Vision (`PhotoMeasureView`), AVFoundation video export.
- **Analytics / crash reporting / localization:** none. **Accessibility:** partial
  (some labels; app is dark-only, gradient-heavy — see §4).

---

## 2. Data inventory (real, from `apps/api` + iOS DTOs)

| Entity | Important fields | Relationships | Storage source | Used by |
| --- | --- | --- | --- | --- |
| **User** | id, email, is_adult, is_admin, display_unit, status | → consents, sessions, prefs | Postgres `users` | auth, /me, admin |
| **Garment** (shared catalog) | id, brand, name, category (top/dress/bottom/outerwear/footwear), gender_neutral, layering_order, price_cents, product_url, thumb_url, mesh_url, sizes[] | → GarmentSize | Postgres `garments` (private MinIO assets) | Wardrobe, Try-On, Shop |
| **GarmentSize** | size_label, measurements{} | ← Garment | `garment_sizes` | size recs |
| **Outfit** (user-owned) | id, name, avatar_id, items[] (garment_id, size_label, layer_index, visible) | → OutfitItem, Avatar | `outfits`/`outfit_items` | Outfits, Compare, sync |
| **Avatar** | id, version, status, confidence, mesh_url, thumb_url, is_mock, measurements | ← User, ← BodyScan | `avatars` | Try-On, viewer |
| **AvatarMeasurement** | height/shoulder/chest/underbust/waist/hip/inseam/torso/arm/thigh/calf/neck, shape/pose params, source | ← Avatar | `avatar_measurements` | Measurements editor, mesh |
| **BodyScan** | id, status, capture_mode, quality_score, retain_raw, height_cm, images[] | → ScanImage, ScanJob | `body_scans` | scan flow |
| **ScanJob** | status, progress, error_code, idempotency_key | ← BodyScan | `scan_jobs` | processing/progress |
| **UserPreference** | data{} (units, customization, favorites) | ← User | `user_preferences` | cross-device sync |
| **CustomGarment** (local only) | id, name, category, colorHex | — | `UserDefaults` | Try-On (render only) |

**Not present (spec assumes, would need backend):** user-owned clothing items *with
photos you took*, laundry/clean state, wear count / wear history, planner/calendar
entries, per-item purchase metadata (date/price/store), tags, archive state.

---

## 3. Compatibility requirements (do NOT break)

- Bearer-token auth + `/me/preferences` sync contract; Keychain key `vw.sessionToken`.
- DTO field names (snake_case ↔ CodingKeys) — API is the source of truth; add
  presentation models above DTOs rather than renaming.
- Local prefs keys: `vw.units`, `vw.skinTone`, `vw.build`, `vw.favOutfits`,
  `vw.customGarments`, `vw.onboarded`, `vw.apiBaseURL`, `vw.token`.
- Garments are a **shared catalog**, not user-owned — the "Wardrobe" screen shows the
  catalog + local custom garments, and "Outfits" are the user-owned combinations.
- Custom (local) garments can be tried on but **cannot** be saved into synced outfits.

---

## 4. Compatibility risks / issues to fix in the rebuild

- **Design debt:** app is dark-only + heavy brand gradients (`Theme.backgroundGradient`,
  `brandGradient`) — the v2.0 spec explicitly flags this as an anti-pattern. Move to
  **semantic system backgrounds, light/dark, content-first**.
- No adaptive light mode; `preferredColorScheme(.dark)` is forced.
- Accessibility gaps: many controls lack VoiceOver labels; image alt text is generic.
- Some views mix logic into the body; a few large view files.
- No unit/UI tests on the iOS side (backend has 18).
- Dead code: `WardrobeView`, `PrivacyControlsView` unused after tab changes.
- Missing states: several screens lack explicit loading/empty/error variants.

---

## 5. Rebuild plan (adapted, CI-verified)

**Phase 1 (this doc + foundation):** design system (tokens, semantic colors, typography,
core components), navigation map, shared `Loadable` state. ✅ starting now.

**Phase 2 — Wardrobe core:** premium `Wardrobe` grid over the garment catalog + custom
garments, with `.searchable`, category filter, sort, empty/loading/error states; item
detail (editorial) using real garment data + size recommendation.

**Phase 3 — Outfits:** polished outfit grid + detail over the real user outfits; keep the
3D try-on as the "builder" (it already composes garments on the avatar).

**Phase 4 — Today:** useful overview (your avatar, recent outfits, quick actions) from real
data only — no fake weather/analytics.

**Phase 5 — Settings/onboarding:** already substantial (`AccountView`, `OnboardingView`);
restyle to the new system, keep account/privacy behavior.

**Planner & own-clothes-with-photos & wear-tracking:** flagged as **backend work** (new
entities). Not faked. Tracked here as future.

**Phase 6 — Quality:** accessibility, Dynamic Type, light/dark, performance with large
catalogs, remove dead code.

---

## 6. Design-system rules (v2.0)

- **Content-first:** garment/avatar imagery dominates; chrome recedes.
- **Semantic system colors** (light + dark), not hardcoded RGB or gradients-everywhere.
- **System typography** via text styles → `DS.Text` roles (Dynamic Type for free).
- **SF Symbols** for icons; **spacing scale** 2–40; restrained radii; minimal shadows.
- Materials reserved for bars/sheets/floating controls, not every card.

See `apps/ios/VirtualWardrobe/DesignSystem/` for the implementation.

---

## 6a. Phase progress

**Design system (Phase 1) — implemented.** Files: `DesignSystem/DS.swift`
(spacing/radius tokens, semantic system colors for light+dark, typography roles +
`.dsText`, motion), `DesignSystem/DSComponents.swift` (`Loadable`, `DSPrimaryButton`,
`DSSecondaryButton`, `dsCard`, `DSSectionHeader`, `DSEmptyState`, `DSErrorState`).
Target membership: XcodeGen auto-discovers everything under `project.yml` `sources:
VirtualWardrobe`, so both files build with the app (no manual .pbxproj edit). Legacy
`Theme` (gradient-heavy) is retained and used by not-yet-migrated screens; it will be
deprecated screen-by-screen — no duplicate design system is kept indefinitely.

**Wardrobe (Phase 2) — first real feature, rebuilt.** Files:
`Views/WardrobeView.swift` (rebuilt), `Views/WardrobeItemCell.swift` (new reusable
cell), `Views/GarmentDetailView.swift` (new editorial detail); wired as a new
**Wardrobe** tab in `Views/DashboardView.swift`.
- **Real data:** `session.api.garments()` (catalog) + local `CustomGarments`. No fake fields.
- **Search:** garment name / brand / category (real fields only).
- **Filter:** category (top/dress/bottom/outerwear/footwear) — no laundry/wear/planner.
- **States:** loading, loaded, empty (with "Add clothing" → `AddGarmentView`), no-results,
  error (`DSErrorState` with retry); refresh keeps content visible.
- **Actions preserved:** garment detail navigation, add (custom) garment, try-on
  (detail → `OutfitBuilderView(initialGarmentIds:)`), buy link.
- **Accessibility:** per-cell VoiceOver label ("{name}, {category}, {price}"), Dynamic
  Type via system text styles, `.isButton`/`.isHeader` traits, no color-only status.
- **Performance:** `LazyVGrid` + adaptive columns, `AsyncImage` (async decode), filtering
  computed once per state (not per cell).
- **Status:** ✅ **CI verified** — iOS build passed (run 30616108650) on first compile.
  Not yet manually verified in a running app (no simulator here).
- **Next production feature:** Outfits (Phase 3) — rebuild the outfit list + detail on the
  real user outfits, then Today (Phase 4). Planner + own-clothes-photos + wear-tracking
  remain backend work (not faked).

## 7. Status / build

- Backend + web unchanged by the iOS rebuild. iOS builds via `.github/workflows/ios.yml`.
- This document is updated each phase with completed screens + decisions.

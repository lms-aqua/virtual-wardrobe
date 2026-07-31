import SwiftUI
import UIKit

/// The 3D try-on experience: your measurement-based avatar with tappable
/// garments layered on, camera presets, snapshot/share, and save-outfit.
struct OutfitBuilderView: View {
    @EnvironmentObject var session: AuthStore
    var initialGarmentIds: Set<String>? = nil

    @StateObject private var controller = AvatarSceneController()
    @State private var avatar: AvatarDTO?
    @State private var garments: [GarmentDTO] = []
    @State private var selected: Set<String> = []
    @State private var filter: String = "All"
    @State private var loading = true
    @State private var saving = false
    @State private var showNaming = false
    @State private var outfitName = "My outfit"
    @State private var toast: String?
    @State private var shareItem: ShareImage?
    @State private var shareVideo: ShareVideo?
    @State private var exportingVideo = false
    @State private var showAddGarment = false

    private let filters = ["All", "Tops", "Dresses", "Bottoms", "Outerwear", "Shoes"]

    private var recs: [(GarmentDTO, SizeRecommender.Rec)] {
        chosen.compactMap { g in
            SizeRecommender.recommend(garment: g, measurements: avatar?.measurements).map { (g, $0) }
        }
    }

    private var chosen: [GarmentDTO] { garments.filter { selected.contains($0.id) } }
    private var visibleGarments: [GarmentDTO] {
        guard filter != "All" else { return garments }
        return garments.filter { categoryMatch($0.category, filter) }
    }

    var body: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()
            if loading {
                ProgressView().tint(DS.Color.accent)
            } else if avatar == nil {
                emptyState
            } else {
                VStack(spacing: 0) {
                    stage
                    filterBar
                    picker
                }
            }
            if let toast { toastView(toast) }
            if exportingVideo {
                ZStack {
                    Color.black.opacity(0.5).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView().tint(DS.Color.accent)
                        Text("Rendering spin video…").foregroundStyle(DS.Color.primaryText)
                    }
                    .padding(24).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                }
            }
        }
        .navigationTitle("Try On")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showAddGarment = true } label: { Label("Add clothing", systemImage: "plus") }
                    Button { share() } label: { Label("Share snapshot", systemImage: "square.and.arrow.up") }
                    Button { exportVideo() } label: { Label("Share spin video (beta)", systemImage: "video") }
                    if !selected.isEmpty {
                        Button { outfitName = "My outfit"; showNaming = true } label: {
                            Label("Save outfit", systemImage: "square.and.arrow.down")
                        }
                    }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .task { await load() }
        .onChange(of: selected) { rebuild() }
        .sheet(item: $shareItem) { ShareSheet(items: [$0.image]) }
        .sheet(item: $shareVideo) { ShareSheet(items: [$0.url]) }
        .sheet(isPresented: $showAddGarment) { AddGarmentView { Task { await load() } } }
        .alert("Name your outfit", isPresented: $showNaming) {
            TextField("Outfit name", text: $outfitName)
            Button("Save") { Task { await save() } }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var stage: some View {
        ZStack(alignment: .topLeading) {
            AvatarSceneView(controller: controller)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 6) {
                Text("MEASUREMENT-BASED 3D PREVIEW")
                    .font(.caption2.bold()).foregroundStyle(DS.Color.secondaryText)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .padding(16)
            VStack {
                Spacer()
                HStack(spacing: 10) {
                    presetButton("Front", .front)
                    presetButton("Side", .side)
                    presetButton("Back", .back)
                }
                .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func presetButton(_ title: String, _ preset: CameraPreset) -> some View {
        Button { controller.setPreset(preset) } label: {
            Text(title).font(.caption.bold()).foregroundStyle(DS.Color.primaryText)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filters, id: \.self) { f in
                    Button { filter = f } label: {
                        Text(f).font(.caption.bold())
                            .foregroundStyle(filter == f ? DS.Color.onAccent : DS.Color.secondaryText)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(filter == f ? DS.Color.accent : DS.Color.fill,
                                        in: Capsule())
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.top, 10)
    }

    private var picker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Tap to dress your avatar").font(.subheadline.bold()).foregroundStyle(DS.Color.primaryText)
                Spacer()
                if !selected.isEmpty {
                    Button("Clear") { withAnimation { selected.removeAll() } }
                        .font(.caption).foregroundStyle(DS.Color.secondaryText)
                }
            }
            .padding(.horizontal)
            if !recs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(recs, id: \.0.id) { g, rec in
                            HStack(spacing: 4) {
                                Text(g.name).font(.caption2).foregroundStyle(DS.Color.primaryText)
                                Text("Size \(rec.label)").font(.caption2.bold()).foregroundStyle(Theme.accent2)
                                Text("· \(rec.note)").font(.caption2).foregroundStyle(DS.Color.secondaryText)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(DS.Color.raised, in: Capsule())
                        }
                    }
                    .padding(.horizontal)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(visibleGarments) { g in
                        GarmentChip(garment: g, selected: selected.contains(g.id)) { toggle(g.id) }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 10)
        }
        .padding(.top, 12)
        .background(.ultraThinMaterial)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.stand").font(.largeTitle).foregroundStyle(Theme.accent)
            Text("No avatar yet").font(.headline).foregroundStyle(DS.Color.primaryText)
            Text("Run a body scan first, then come back to try on clothes in 3D.")
                .multilineTextAlignment(.center).foregroundStyle(DS.Color.secondaryText)
        }
        .padding(30)
    }

    private func toastView(_ text: String) -> some View {
        VStack {
            Spacer()
            Text(text).font(.subheadline.bold()).foregroundStyle(DS.Color.onAccent)
                .padding(.horizontal, 18).padding(.vertical, 12)
                .background(DS.Color.accent, in: Capsule())
                .padding(.bottom, 130)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func categoryMatch(_ category: String, _ filter: String) -> Bool {
        switch filter {
        case "Tops": return category == "top"
        case "Dresses": return category == "dress"
        case "Bottoms": return category == "bottom"
        case "Outerwear": return category == "outerwear"
        case "Shoes": return category == "footwear"
        default: return true
        }
    }

    private func toggle(_ id: String) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeInOut(duration: 0.2)) {
            if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
        }
    }

    private func rebuild() { controller.update(measurements: avatar?.measurements, garments: chosen) }

    private func share() {
        controller.setPreset(.front)
        shareItem = ShareImage(image: controller.snapshot())
    }

    private func exportVideo() {
        exportingVideo = true
        AvatarVideoExporter.exportSpin(measurements: avatar?.measurements, garments: chosen) { url in
            exportingVideo = false
            if let url { shareVideo = ShareVideo(url: url) }
        }
    }

    private func load() async {
        loading = true
        avatar = (try? await session.api.avatars())?.first
        let catalog = (try? await session.api.garments()) ?? []
        garments = catalog + CustomGarments.all.map { CustomGarments.asGarment($0) }
        if let ids = initialGarmentIds { selected = ids }
        loading = false
        rebuild()
    }

    private func save() async {
        // Re-entrancy guard: `saving` was tracked but never actually consulted,
        // so a double tap fired two creates and produced duplicate outfits.
        guard !saving else { return }
        saving = true
        defer { saving = false }

        // Custom (local) garments can't be part of a synced outfit.
        let items = chosen.filter { !CustomGarments.isCustom($0.id) }.map {
            OutfitItemIn(garmentId: $0.id, sizeLabel: "M", layerIndex: $0.layeringOrder)
        }

        do {
            // The result and the error were both discarded here, then a success
            // toast was shown unconditionally — a failed save reported "saved".
            _ = try await session.api.createOutfit(
                name: outfitName, avatarId: avatar?.id, items: items
            )
            DS.Haptic.success()
            await flash("Outfit saved ✓")
        } catch {
            DS.Haptic.warning()
            await flash("Couldn’t save outfit — try again")
        }
    }

    private func flash(_ text: String) async {
        withAnimation { toast = text }
        try? await Task.sleep(nanoseconds: 1_600_000_000)
        withAnimation { toast = nil }
    }
}

struct GarmentChip: View {
    let garment: GarmentDTO
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(GarmentAppearance.of(garment).color)
                    .frame(width: 64, height: 64)
                    // The swatch is filled with the garment's own saturated colour,
                    // so its glyph and selection ring stay on-fill colours rather
                    // than label colours in either appearance.
                    .overlay(Image(systemName: symbol).font(.title3).foregroundStyle(DS.Color.onAccent))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.compact, style: .continuous)
                        .stroke(selected ? DS.Color.onAccent : .clear, lineWidth: 2.5))
                    .overlay(alignment: .topTrailing) {
                        if selected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(DS.Color.onAccent, DS.Color.accent).padding(4)
                        }
                    }
                Text(garment.name).font(.caption2).lineLimit(1)
                    .foregroundStyle(selected ? DS.Color.primaryText : DS.Color.secondaryText)
                    .frame(width: 70)
            }
        }
        .buttonStyle(.plain)
    }

    private var symbol: String {
        switch garment.category.lowercased() {
        case "dress": return "figure.dress.line.vertical.figure"
        case "bottom": return "figure.walk"
        case "outerwear": return "wind"
        case "footwear": return "shoe.2"
        default: return "tshirt.fill"
        }
    }
}

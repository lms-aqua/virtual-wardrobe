import SwiftUI
import UIKit

/// The 3D try-on experience: your measurement-based avatar with tappable
/// garments layered on, plus save-outfit.
struct OutfitBuilderView: View {
    @EnvironmentObject var session: AuthStore
    @State private var avatar: AvatarDTO?
    @State private var garments: [GarmentDTO] = []
    @State private var selected: Set<String> = []
    @State private var loading = true
    @State private var saving = false
    @State private var showNaming = false
    @State private var outfitName = "My outfit"
    @State private var toast: String?

    private var chosen: [GarmentDTO] { garments.filter { selected.contains($0.id) } }

    var body: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()
            if loading {
                ProgressView().tint(.white)
            } else if avatar == nil {
                emptyState
            } else {
                VStack(spacing: 0) {
                    stage
                    picker
                }
            }
            if let toast { toastView(toast) }
        }
        .navigationTitle("Try On")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !selected.isEmpty {
                    Button("Save") { outfitName = "My outfit"; showNaming = true }
                        .disabled(saving)
                }
            }
        }
        .task { await load() }
        .alert("Name your outfit", isPresented: $showNaming) {
            TextField("Outfit name", text: $outfitName)
            Button("Save") { Task { await save() } }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var stage: some View {
        ZStack(alignment: .topLeading) {
            AvatarSceneView(measurements: avatar?.measurements, garments: chosen)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 6) {
                Text("MEASUREMENT-BASED 3D PREVIEW")
                    .font(.caption2.bold()).foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                Text("Drag to rotate · pinch to zoom")
                    .font(.caption2).foregroundStyle(.white.opacity(0.5))
            }
            .padding(16)
        }
    }

    private var picker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Tap to dress your avatar").font(.subheadline.bold())
                    .foregroundStyle(.white)
                Spacer()
                if !selected.isEmpty {
                    Button("Clear") { withAnimation { selected.removeAll() } }
                        .font(.caption).foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(garments) { g in
                        GarmentChip(garment: g, selected: selected.contains(g.id)) {
                            toggle(g.id)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 8)
        }
        .padding(.top, 12)
        .background(.ultraThinMaterial)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.stand").font(.system(size: 46)).foregroundStyle(Theme.accent)
            Text("No avatar yet").font(.headline).foregroundStyle(.white)
            Text("Run a body scan first, then come back to try on clothes in 3D.")
                .multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.7))
        }
        .padding(30)
    }

    private func toastView(_ text: String) -> some View {
        VStack {
            Spacer()
            Text(text).font(.subheadline.bold()).foregroundStyle(.white)
                .padding(.horizontal, 18).padding(.vertical, 12)
                .background(Theme.accent, in: Capsule())
                .padding(.bottom, 120)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func toggle(_ id: String) {
        let gen = UIImpactFeedbackGenerator(style: .light); gen.impactOccurred()
        withAnimation(.easeInOut(duration: 0.2)) {
            if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
        }
    }

    private func load() async {
        loading = true
        avatar = (try? await session.api.avatars())?.first
        garments = (try? await session.api.garments()) ?? []
        loading = false
    }

    private func save() async {
        saving = true; defer { saving = false }
        let items = chosen.map {
            OutfitItemIn(garmentId: $0.id, sizeLabel: "M", layerIndex: $0.layeringOrder)
        }
        _ = try? await session.api.createOutfit(
            name: outfitName, avatarId: avatar?.id, items: items)
        await flash("Outfit saved ✓")
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
                    .overlay(
                        Image(systemName: symbol)
                            .font(.title3).foregroundStyle(.white.opacity(0.9))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selected ? .white : .clear, lineWidth: 2.5))
                    .overlay(alignment: .topTrailing) {
                        if selected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.white, Theme.accent)
                                .padding(4)
                        }
                    }
                Text(garment.name).font(.caption2).lineLimit(1)
                    .foregroundStyle(.white.opacity(selected ? 1 : 0.7))
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

import SwiftUI

struct WardrobeView: View {
    @EnvironmentObject var session: AuthStore
    @State private var garments: [GarmentDTO] = []
    @State private var outfits: [OutfitDTO] = []
    @State private var selected: Set<String> = []
    @State private var loading = true
    @State private var saving = false
    @State private var showNaming = false
    @State private var outfitName = "My outfit"

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 14)]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Tap garments to build an outfit")
                            .foregroundStyle(.white.opacity(0.7))
                        if loading {
                            ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.top, 40)
                        } else {
                            grid
                            if !outfits.isEmpty { savedOutfits }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Wardrobe")
            .safeAreaInset(edge: .bottom) { if !selected.isEmpty { saveBar } }
            .task { await load() }
            .refreshable { await load() }
            .alert("Name your outfit", isPresented: $showNaming) {
                TextField("Outfit name", text: $outfitName)
                Button("Save") { Task { await save() } }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(garments) { g in
                Button { toggle(g.id) } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        RemoteThumb(urlString: g.thumbUrl)
                            .frame(height: 130).frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
                        Text(g.name).font(.subheadline.bold()).foregroundStyle(.white)
                        Text(g.category.capitalized).font(.caption).foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(10)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(selected.contains(g.id) ? Theme.accent : Theme.stroke,
                                    lineWidth: selected.contains(g.id) ? 2 : 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var savedOutfits: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Saved outfits").font(.headline).foregroundStyle(.white)
            ForEach(outfits) { o in
                HStack {
                    Image(systemName: "square.stack.3d.up.fill").foregroundStyle(Theme.accent)
                    Text(o.name).foregroundStyle(.white)
                    Spacer()
                }
                .card()
            }
        }
    }

    private var saveBar: some View {
        Button {
            showNaming = true
        } label: {
            if saving { ProgressView().tint(.white) }
            else { Label("Save \(selected.count) as outfit", systemImage: "square.and.arrow.down.fill") }
        }
        .buttonStyle(PrimaryButtonStyle())
        .padding()
        .background(.ultraThinMaterial)
    }

    private func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    private func load() async {
        loading = true
        garments = (try? await session.api.garments()) ?? []
        outfits = (try? await session.api.outfits()) ?? []
        loading = false
    }

    private func save() async {
        saving = true; defer { saving = false }
        let avatarId = (try? await session.api.avatars())?.first?.id
        let items = Array(selected).enumerated().map { idx, gid in
            OutfitItemIn(garmentId: gid, sizeLabel: "M", layerIndex: idx * 10)
        }
        _ = try? await session.api.createOutfit(name: outfitName, avatarId: avatarId, items: items)
        selected.removeAll()
        await load()
    }
}

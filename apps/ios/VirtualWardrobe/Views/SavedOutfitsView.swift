import SwiftUI

/// Lists saved outfits; tap to open in the 3D try-on, swipe to delete.
struct SavedOutfitsView: View {
    @EnvironmentObject var session: AuthStore
    @State private var outfits: [OutfitDTO] = []
    @State private var loading = true
    @State private var favTick = 0   // forces re-render on favorite toggle

    private var sorted: [OutfitDTO] {
        _ = favTick
        return outfits.sorted { Favorites.contains($0.id) && !Favorites.contains($1.id) }
    }

    var body: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()
            if loading {
                ProgressView().tint(.white)
            } else if outfits.isEmpty {
                empty
            } else {
                List {
                    ForEach(sorted) { o in
                        NavigationLink {
                            OutfitBuilderView(initialGarmentIds: Set(o.items.map { $0.garmentId }))
                        } label: {
                            HStack {
                                Image(systemName: "square.stack.3d.up.fill").foregroundStyle(Theme.accent)
                                VStack(alignment: .leading) {
                                    Text(o.name).foregroundStyle(.white)
                                    Text("\(o.items.count) item\(o.items.count == 1 ? "" : "s")")
                                        .font(.caption).foregroundStyle(.white.opacity(0.6))
                                }
                                Spacer()
                                if Favorites.contains(o.id) {
                                    Image(systemName: "star.fill").foregroundStyle(.yellow)
                                }
                            }
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                        .swipeActions(edge: .leading) {
                            Button {
                                Favorites.toggle(o.id); favTick += 1
                            } label: { Label("Favorite", systemImage: "star") }.tint(.yellow)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { remove(o) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Saved Outfits")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private var empty: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.stack.3d.up.slash").font(.system(size: 44))
                .foregroundStyle(Theme.accent)
            Text("No saved outfits yet").font(.headline).foregroundStyle(.white)
            Text("Build a look in Try On and tap Save.")
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(30)
    }

    private func load() async {
        loading = true
        outfits = (try? await session.api.outfits()) ?? []
        loading = false
    }

    private func remove(_ o: OutfitDTO) {
        outfits.removeAll { $0.id == o.id }
        Task { try? await session.api.deleteOutfit(o.id) }
    }
}

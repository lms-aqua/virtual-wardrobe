import SwiftUI

/// Lists saved outfits; tap to open in the 3D try-on, swipe to delete.
struct SavedOutfitsView: View {
    @EnvironmentObject var session: AuthStore
    @State private var outfits: [OutfitDTO] = []
    @State private var loading = true

    var body: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()
            if loading {
                ProgressView().tint(.white)
            } else if outfits.isEmpty {
                empty
            } else {
                List {
                    ForEach(outfits) { o in
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
                            }
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                    }
                    .onDelete(perform: delete)
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

    private func delete(at offsets: IndexSet) {
        let toDelete = offsets.map { outfits[$0] }
        outfits.remove(atOffsets: offsets)
        Task {
            for o in toDelete { try? await session.api.deleteOutfit(o.id) }
        }
    }
}

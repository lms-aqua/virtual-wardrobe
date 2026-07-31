import SwiftUI

/// Lists saved outfits; tap to open in the 3D try-on, swipe to favorite,
/// duplicate or delete.
struct SavedOutfitsView: View {
    @EnvironmentObject var session: AuthStore

    @State private var state: Loadable<[OutfitDTO]> = .idle
    @State private var favTick = 0            // forces re-render on favorite toggle
    @State private var busyOutfitId: String?  // duplication in flight
    @State private var failure: String?

    var body: some View {
        ZStack {
            DS.Color.grouped.ignoresSafeArea()
            content
        }
        .navigationTitle("Saved Outfits")
        .navigationBarTitleDisplayMode(.inline)
        .task { if case .idle = state { await load() } }
        .refreshable { await load() }
        .alert(
            "Couldn’t Complete That",
            isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })
        ) {
            Button("OK") { failure = nil }
        } message: {
            Text(failure ?? "")
        }
    }

    @ViewBuilder private var content: some View {
        switch state {
        case .idle, .loading:
            ProgressView().tint(DS.Color.accent)
        case .failed(let message):
            DSErrorState(
                title: "Outfits Couldn’t Load",
                message: message,
                systemImage: "wifi.exclamationmark",
                retry: { Task { await load() } }
            )
        case .empty:
            empty
        case .loaded(let outfits):
            list(sorted(outfits))
        }
    }

    private func list(_ outfits: [OutfitDTO]) -> some View {
        List {
            ForEach(outfits) { o in
                NavigationLink {
                    OutfitBuilderView(initialGarmentIds: Set(o.items.map { $0.garmentId }))
                } label: {
                    row(o)
                }
                .listRowBackground(DS.Color.raisedGrouped)
                .swipeActions(edge: .leading) {
                    Button {
                        Favorites.toggle(o.id)
                        favTick += 1
                        session.pushPreferences()
                        DS.Haptic.selection()
                    } label: { Label("Favorite", systemImage: "star") }
                        .tint(DS.Color.favorite)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { Task { await remove(o) } } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button { Task { await duplicate(o) } } label: {
                        Label("Duplicate", systemImage: "plus.square.on.square")
                    }
                    .tint(DS.Color.accent)
                }
                .contextMenu {
                    Button { Task { await duplicate(o) } } label: {
                        Label("Duplicate", systemImage: "plus.square.on.square")
                    }
                    Button(role: .destructive) { Task { await remove(o) } } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func row(_ o: OutfitDTO) -> some View {
        HStack {
            Image(systemName: "square.stack.3d.up.fill").foregroundStyle(DS.Color.accent)
            VStack(alignment: .leading) {
                Text(o.name).dsText(.itemTitle)
                Text("\(o.items.count) item\(o.items.count == 1 ? "" : "s")")
                    .dsText(.caption)
            }
            Spacer()
            if busyOutfitId == o.id {
                ProgressView()
            } else if Favorites.contains(o.id) {
                Image(systemName: "star.fill").foregroundStyle(DS.Color.favorite)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(o.name), \(o.items.count) item\(o.items.count == 1 ? "" : "s")"
                + (Favorites.contains(o.id) ? ", favorite" : "")
        )
    }

    private var empty: some View {
        DSEmptyState(
            title: "No Saved Outfits Yet",
            systemImage: "square.stack.3d.up.slash",
            message: "Build a look in Try On and tap Save."
        )
    }

    private func sorted(_ outfits: [OutfitDTO]) -> [OutfitDTO] {
        _ = favTick
        return outfits.sorted { Favorites.contains($0.id) && !Favorites.contains($1.id) }
    }

    // MARK: actions

    /// Copies an outfit's items into a new outfit. The server assigns the id, so
    /// the copy is independent — editing it never touches the original.
    private func duplicate(_ o: OutfitDTO) async {
        guard case .loaded(let current) = state, busyOutfitId == nil else { return }
        busyOutfitId = o.id
        defer { busyOutfitId = nil }

        let items = o.items.map {
            OutfitItemIn(garmentId: $0.garmentId, sizeLabel: nil, layerIndex: $0.layerIndex)
        }
        do {
            let copy = try await session.api.createOutfit(
                name: copyName(for: o.name, existing: current.map(\.name)),
                avatarId: nil,
                items: items
            )
            state = .loaded(current + [copy])
            DS.Haptic.success()
        } catch {
            failure = "That outfit couldn’t be duplicated. Check your connection and try again."
            DS.Haptic.warning()
        }
    }

    /// "Look" → "Look Copy" → "Look Copy 2" … so duplicating twice never leaves
    /// two identically-named outfits in the list.
    private func copyName(for name: String, existing: [String]) -> String {
        let base = "\(name) Copy"
        if !existing.contains(base) { return base }
        var n = 2
        while existing.contains("\(base) \(n)") { n += 1 }
        return "\(base) \(n)"
    }

    private func remove(_ o: OutfitDTO) async {
        guard case .loaded(let current) = state else { return }
        // Optimistic, but restored if the server rejects it. This previously
        // swallowed the error, so a failed delete silently reappeared on the
        // next refresh with no explanation.
        state = .loaded(current.filter { $0.id != o.id })
        do {
            try await session.api.deleteOutfit(o.id)
        } catch {
            state = .loaded(current)
            failure = "That outfit couldn’t be deleted. Check your connection and try again."
            DS.Haptic.warning()
        }
    }

    private func load() async {
        if case .loaded = state {} else { state = .loading }
        do {
            let outfits = try await session.api.outfits()
            state = outfits.isEmpty ? .empty : .loaded(outfits)
        } catch {
            // Previously `try? ... ?? []`, which rendered a real network failure
            // as "No saved outfits yet".
            state = .failed("Your outfits are still safe. Check your connection and try again.")
        }
    }
}

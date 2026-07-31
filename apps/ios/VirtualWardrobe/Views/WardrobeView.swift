import SwiftUI

/// Production Wardrobe screen — the garments available to your 3D try-on.
///
/// Real data from the garment API plus your local custom garments. The grid is
/// the subject: filters are a single compact row and Add lives in the navigation
/// toolbar. A floating capsule was tried first, but this screen sits inside a
/// TabView, so it stacked a second floating element in the same corner as the
/// tab bar and covered the last row.
struct WardrobeView: View {
    @EnvironmentObject var session: AuthStore

    @State private var state: Loadable<[GarmentDTO]> = .idle
    @State private var query = ""
    @State private var category: String? = nil          // nil = All
    @State private var showAdd = false
    @State private var favorites: Set<String> = Favorites.ids

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let categories = ["top", "dress", "bottom", "outerwear", "footwear"]

    /// Two columns normally; a single column once text is at accessibility
    /// sizes, where a side-by-side grid would crush garment names.
    private var columns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible(), spacing: DS.Space.l)]
            : [GridItem(.adaptive(minimum: 150, maximum: 240), spacing: DS.Space.l)]
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Wardrobe")
                .background(DS.Color.grouped)
                .searchable(text: $query, prompt: "Search garments")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showAdd = true } label: {
                            Label("Add Garment", systemImage: "plus")
                        }
                        .accessibilityLabel("Add Garment")
                    }
                }
                .task { if case .idle = state { await load() } }
                .refreshable { await load() }
                .sheet(isPresented: $showAdd) {
                    AddGarmentView {
                        Task {
                            await load()
                            DS.Haptic.success()
                        }
                    }
                }
        }
    }

    // MARK: content by state

    @ViewBuilder private var content: some View {
        switch state {
        case .idle, .loading:
            skeleton
        case .failed(let message):
            DSErrorState(
                title: "Garments Couldn’t Load",
                message: message,
                systemImage: "wifi.exclamationmark",
                retry: { Task { await load() } }
            )
        case .empty:
            emptyWardrobe
        case .loaded(let all):
            let items = filtered(all)
            VStack(spacing: 0) {
                filterRow
                if items.isEmpty { noResults } else { grid(items) }
            }
        }
    }

    /// Initial load keeps the screen's structure instead of blanking to a
    /// spinner, so the layout doesn't jump when real garments arrive.
    private var skeleton: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: DS.Space.xl) {
                ForEach(0..<6, id: \.self) { _ in DSGarmentSkeletonCell() }
            }
            .padding(DS.Space.screenMargin)
        }
        .disabled(true)
        .accessibilityLabel("Loading your wardrobe")
    }

    private func grid(_ items: [GarmentDTO]) -> some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: DS.Space.xl) {
                ForEach(items) { g in
                    NavigationLink { GarmentDetailView(garment: g) } label: {
                        WardrobeItemCell(garment: g, isFavorite: favorites.contains(g.id))
                    }
                    .buttonStyle(.plain)
                    .contextMenu { menu(for: g) }
                }
            }
            .padding(DS.Space.screenMargin)
            .animation(DS.Motion.adaptive(DS.Motion.content, reduceMotion: reduceMotion),
                       value: items.count)
        }
    }

    /// Secondary actions live in the long-press menu, keeping the cells clean.
    @ViewBuilder private func menu(for g: GarmentDTO) -> some View {
        Button {
            Favorites.toggle(g.id)
            favorites = Favorites.ids
            DS.Haptic.selection()
        } label: {
            Label(favorites.contains(g.id) ? "Remove from Favorites" : "Favorite",
                  systemImage: favorites.contains(g.id) ? "heart.slash" : "heart")
        }

        if CustomGarments.isCustom(g.id) {
            Button(role: .destructive) {
                CustomGarments.remove(id: g.id)
                Task { await load() }
            } label: {
                Label("Delete Garment", systemImage: "trash")
            }
        }
    }

    // MARK: filters — one compact row, with "All" as the direct reset

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Space.s) {
                DSFilterChip(title: "All", isActive: category == nil) {
                    setCategory(nil)
                }
                ForEach(categories, id: \.self) { c in
                    DSFilterChip(title: c.capitalized, isActive: category == c) {
                        setCategory(category == c ? nil : c)
                    }
                }
            }
            .padding(.horizontal, DS.Space.screenMargin)
            .padding(.vertical, DS.Space.s)
        }
        // No .scrollClipDisabled() here. It let the chips render outside their
        // bounds: their layout slot stayed empty under the search bar while the
        // chips themselves drew down over the first grid row, behind the
        // garment tiles.
    }

    private func setCategory(_ c: String?) {
        withAnimation(DS.Motion.adaptive(DS.Motion.quick, reduceMotion: reduceMotion)) {
            category = c
        }
        DS.Haptic.selection()
    }

    // MARK: states

    private var emptyWardrobe: some View {
        DSEmptyState(
            title: "Your Wardrobe Is Ready",
            systemImage: "tshirt",
            message: "Add your first garment to begin creating outfits and virtual try-ons.",
            actionTitle: "Add Garment",
            action: { showAdd = true }
        )
    }

    private var noResults: some View {
        DSEmptyState(
            title: "No Matches",
            systemImage: "magnifyingglass",
            message: query.isEmpty
                ? "No garments in this category yet."
                : "No garments match “\(query)”.",
            actionTitle: resetTitle,
            action: resetAction
        )
        .frame(maxHeight: .infinity)
    }

    // Split out so the optionals have an unambiguous type for the compiler.
    private var resetTitle: String? {
        category == nil ? nil : "Reset Filters"
    }

    private var resetAction: (() -> Void)? {
        guard category != nil else { return nil }
        return { setCategory(nil) }
    }

    // MARK: data

    private func filtered(_ all: [GarmentDTO]) -> [GarmentDTO] {
        all.filter { g in
            (category == nil || g.category.lowercased() == category) && matchesQuery(g)
        }
    }

    private func matchesQuery(_ g: GarmentDTO) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return true }
        return g.name.lowercased().contains(q)
            || g.brand.lowercased().contains(q)
            || g.category.lowercased().contains(q)
    }

    private func load() async {
        if case .loaded = state {} else { state = .loading }
        do {
            let catalog = try await session.api.garments()
            let combined = catalog + CustomGarments.all.map { CustomGarments.asGarment($0) }
            state = combined.isEmpty ? .empty : .loaded(combined)
            favorites = Favorites.ids
        } catch {
            state = .failed("Your wardrobe is still safe. Check your connection and try again.")
        }
    }
}

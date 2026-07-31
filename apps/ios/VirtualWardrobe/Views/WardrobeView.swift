import SwiftUI

/// Production Wardrobe screen — the garments available to your 3D try-on. Real
/// data from the garment API + your local custom garments. Image-focused grid
/// with native search, category filtering, and full loading/empty/error states.
struct WardrobeView: View {
    @EnvironmentObject var session: AuthStore

    @State private var state: Loadable<[GarmentDTO]> = .idle
    @State private var query = ""
    @State private var category: String? = nil          // nil = All
    @State private var showAdd = false

    private let categories = ["top", "dress", "bottom", "outerwear", "footwear"]
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: DS.Space.l)]

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Wardrobe")
                .background(DS.Color.grouped)
                .toolbar { toolbar }
                .searchable(text: $query, prompt: "Search garments")
                .task { if case .idle = state { await load() } }
                .refreshable { await load() }
                .sheet(isPresented: $showAdd) { AddGarmentView { Task { await load() } } }
        }
    }

    // MARK: content by state
    @ViewBuilder private var content: some View {
        switch state {
        case .idle, .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            DSErrorState(message: message, retry: { Task { await load() } })
        case .empty:
            emptyWardrobe
        case .loaded(let all):
            let items = filtered(all)
            if items.isEmpty {
                noResults
            } else {
                grid(items)
            }
        }
    }

    private func grid(_ items: [GarmentDTO]) -> some View {
        ScrollView {
            if category != nil { activeFilterBar }
            LazyVGrid(columns: columns, spacing: DS.Space.xl) {
                ForEach(items) { g in
                    NavigationLink { GarmentDetailView(garment: g) } label: {
                        WardrobeItemCell(garment: g)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(DS.Space.l)
        }
    }

    private var activeFilterBar: some View {
        HStack {
            Text("\(category?.capitalized ?? "")").dsText(.itemMeta)
            Spacer()
            Button("Clear") { category = nil }.font(.subheadline).foregroundStyle(DS.Color.accent)
        }
        .padding(.horizontal, DS.Space.l).padding(.top, DS.Space.m)
    }

    private var emptyWardrobe: some View {
        DSEmptyState(
            title: "Your wardrobe is empty",
            systemImage: "tshirt",
            message: "Add a garment to start building outfits on your avatar.",
            actionTitle: "Add clothing",
            action: { showAdd = true }
        )
    }

    private var noResults: some View {
        DSEmptyState(
            title: "No matches",
            systemImage: "magnifyingglass",
            message: query.isEmpty ? "No garments in this category." : "No garments match “\(query)”."
        )
    }

    // MARK: toolbar
    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Category", selection: $category) {
                    Text("All Categories").tag(String?.none)
                    ForEach(categories, id: \.self) { c in
                        Text(c.capitalized).tag(String?.some(c))
                    }
                }
            } label: {
                Label("Filter", systemImage: category == nil
                      ? "line.3.horizontal.decrease.circle"
                      : "line.3.horizontal.decrease.circle.fill")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { showAdd = true } label: { Label("Add", systemImage: "plus") }
        }
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
        } catch {
            state = .failed("We couldn't load your wardrobe. Pull to refresh to try again.")
        }
    }
}

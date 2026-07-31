import SwiftUI

/// Account, preferences, data controls, and about — the app's settings hub.
struct AccountView: View {
    @EnvironmentObject var session: AuthStore
    @AppStorage("vw.units") private var unitsRaw = "metric"
    @State private var showDelete = false
    @State private var deleting = false

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()
                List {
                    profileSection
                    preferencesSection
                    dataSection
                    aboutSection
                    dangerSection
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .alert("Delete everything?", isPresented: $showDelete) {
                Button("Delete", role: .destructive) { Task { await del() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your scans, avatar, measurements, outfits, and account will be permanently erased.")
            }
        }
    }

    // MARK: Sections
    private var profileSection: some View {
        Section {
            row("Email", value: session.user?.email ?? "—")
            row("Account", value: session.user?.isAdult == true ? "Adult ✓" : "—")
        } header: { header("Profile") }
        .listRowBackground(DS.Color.raisedGrouped)
    }

    private var preferencesSection: some View {
        Section {
            Picker(selection: $unitsRaw) {
                ForEach(Units.System.allCases) { Text($0.label).tag($0.rawValue) }
            } label: { label("Units", "ruler") }
            .tint(DS.Color.accent)
            .onChange(of: unitsRaw) { session.pushPreferences() }
            NavigationLink { SettingsView() } label: { label("Server", "network") }
        } header: { header("Preferences") }
        .listRowBackground(DS.Color.raisedGrouped)
    }

    private var dataSection: some View {
        Section {
            NavigationLink { ShopView() } label: { label("Shop", "bag.fill") }
            NavigationLink { MeasurementsView() } label: { label("Measurements", "ruler.fill") }
            NavigationLink { SavedOutfitsView() } label: { label("Saved outfits", "square.stack.3d.up.fill") }
            NavigationLink { InfoView.howScanningWorks } label: { label("How scanning works", "camera.viewfinder") }
            NavigationLink { InfoView.privacyPromise } label: { label("Privacy promise", "lock.shield.fill") }
        } header: { header("Your data") }
        .listRowBackground(DS.Color.raisedGrouped)
    }

    private var aboutSection: some View {
        Section {
            row("Version", value: version)
            Link(destination: URL(string: "https://github.com/lms-aqua/virtual-wardrobe")!) {
                label("Source on GitHub", "chevron.left.forwardslash.chevron.right")
            }
        } header: { header("About") }
        .listRowBackground(DS.Color.raisedGrouped)
    }

    private var dangerSection: some View {
        Section {
            Button { session.signOut() } label: { label("Sign out", "arrow.right.square") }
            Button(role: .destructive) { showDelete = true } label: {
                if deleting { ProgressView() }
                else { label("Delete everything", "trash.fill").foregroundStyle(.red) }
            }
        }
        .listRowBackground(DS.Color.raisedGrouped)
    }

    // MARK: helpers
    private func header(_ t: String) -> some View {
        Text(t).foregroundStyle(DS.Color.secondaryText)
    }
    private func label(_ t: String, _ symbol: String) -> some View {
        Label(t, systemImage: symbol).foregroundStyle(DS.Color.primaryText)
    }
    private func row(_ t: String, value: String) -> some View {
        HStack { Text(t).foregroundStyle(DS.Color.primaryText); Spacer()
            Text(value).foregroundStyle(DS.Color.secondaryText) }
    }

    private func del() async {
        deleting = true
        await session.deleteEverything()
        deleting = false
    }
}

/// Simple scrollable text info screen.
struct InfoView: View {
    let title: String
    let points: [String]

    var body: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(points, id: \.self) { p in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                            Text(p).foregroundStyle(DS.Color.primaryText)
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    static let howScanningWorks = InfoView(title: "How scanning works", points: [
        "Give consent — you can only scan your own body, as an adult.",
        "Wear close-fitting clothes for better measurement accuracy. Never nudity.",
        "Stand back so your whole body fits the frame; front camera by default.",
        "Tap Start and slowly turn a full circle — the app captures ~24 frames.",
        "Frames upload privately, then a 3D avatar is built from your proportions.",
        "Raw photos are deleted after the avatar is generated.",
    ])

    static let privacyPromise = InfoView(title: "Privacy promise", points: [
        "Adults only, explicit consent before any scan.",
        "Scans upload to private storage — never a public link.",
        "Assets load through short-lived signed URLs.",
        "No face recognition, ever.",
        "Raw photos deleted after your avatar is built.",
        "One tap deletes your scans, avatar, measurements, and account.",
    ])
}

import SwiftUI

struct DashboardView: View {
    @AppStorage("vw.onboarded") private var onboarded = false

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
            WardrobeView()
                .tabItem { Label("Wardrobe", systemImage: "tshirt.fill") }
            NavigationStack { OutfitBuilderView() }
                .tabItem { Label("Try On", systemImage: "cube.transparent.fill") }
            AccountView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .sheet(isPresented: Binding(get: { !onboarded }, set: { if !$0 { onboarded = true } })) {
            OnboardingView()
        }
    }
}

struct HomeView: View {
    @EnvironmentObject var session: AuthStore
    @State private var avatars: [AvatarDTO] = []
    @State private var loading = true
    @State private var startScan = false
    @State private var showPhotoImport = false
    @State private var showAR = false
    @State private var showMirror = false
    @State private var showPhotoMeasure = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        greeting
                        if loading {
                            ProgressView().tint(DS.Color.accent).frame(maxWidth: .infinity).padding(.top, 40)
                        } else if let avatar = avatars.first {
                            AvatarCard(avatar: avatar)
                            NavigationLink {
                                OutfitBuilderView()
                            } label: {
                                Label("Try on in 3D", systemImage: "cube.transparent.fill")
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            HStack(spacing: 12) {
                                NavigationLink {
                                    MeasurementsView()
                                } label: {
                                    Label("Measurements", systemImage: "ruler.fill")
                                        .frame(maxWidth: .infinity, minHeight: 50)
                                }
                                NavigationLink {
                                    SavedOutfitsView()
                                } label: {
                                    Label("Outfits", systemImage: "square.stack.3d.up.fill")
                                        .frame(maxWidth: .infinity, minHeight: 50)
                                }
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DS.Color.primaryText)
                            .background(DS.Color.raised,
                                        in: RoundedRectangle(cornerRadius: 16))
                            HStack(spacing: 12) {
                                NavigationLink { CustomizeView() } label: {
                                    Label("Customize", systemImage: "paintpalette.fill")
                                        .frame(maxWidth: .infinity, minHeight: 50)
                                }
                                NavigationLink { OutfitCompareView() } label: {
                                    Label("Compare", systemImage: "square.on.square")
                                        .frame(maxWidth: .infinity, minHeight: 50)
                                }
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DS.Color.primaryText)
                            .background(DS.Color.raised,
                                        in: RoundedRectangle(cornerRadius: 16))
                        } else {
                            emptyState
                        }
                        startScanButton
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Home")
            .fullScreenCover(isPresented: $startScan, onDismiss: { Task { await load() } }) {
                ScanContainer { startScan = false }
            }
            .fullScreenCover(isPresented: $showPhotoImport, onDismiss: { Task { await load() } }) {
                PhotoImportView { showPhotoImport = false }
            }
            .fullScreenCover(isPresented: $showAR, onDismiss: { Task { await load() } }) {
                ARMeasureView { showAR = false }
            }
            .fullScreenCover(isPresented: $showMirror) {
                MirrorView { showMirror = false }
            }
            .fullScreenCover(isPresented: $showPhotoMeasure, onDismiss: { Task { await load() } }) {
                PhotoMeasureView { showPhotoMeasure = false }
            }
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Welcome back").foregroundStyle(DS.Color.secondaryText)
            Text(session.user?.email ?? "")
                .font(.title2.bold()).foregroundStyle(DS.Color.primaryText)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.stand")
                .font(.system(size: 48)).foregroundStyle(Theme.accent)
            Text("No avatar yet").font(.headline).foregroundStyle(DS.Color.primaryText)
            Text("Do a quick guided body scan to build your personalized 3D avatar.")
                .multilineTextAlignment(.center)
                .foregroundStyle(DS.Color.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .card()
    }

    private var startScanButton: some View {
        Menu {
            Button { startScan = true } label: { Label("Camera 360° scan", systemImage: "camera.viewfinder") }
            Button { showPhotoImport = true } label: { Label("Import photos", systemImage: "photo.on.rectangle.angled") }
            Button { showPhotoMeasure = true } label: { Label("Measure from a photo", systemImage: "ruler") }
            Button { showAR = true } label: { Label("AR body measure (beta)", systemImage: "arkit") }
            Button { showMirror = true } label: { Label("AR magic mirror (beta)", systemImage: "sparkles.tv") }
        } label: {
            Label(avatars.isEmpty ? "Start body scan" : "New scan / measure",
                  systemImage: "camera.viewfinder")
                .frame(maxWidth: .infinity, minHeight: 54)
                .foregroundStyle(DS.Color.onAccent)
                .background(DS.Color.accent, in: RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous))
        }
    }

    private func load() async {
        loading = true
        avatars = (try? await session.api.avatars()) ?? []
        loading = false
    }
}

struct AvatarCard: View {
    let avatar: AvatarDTO
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Your avatar").font(.headline).foregroundStyle(DS.Color.primaryText)
                Spacer()
                if avatar.isMock {
                    Text("MOCK").font(.caption2.bold())
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Theme.accent.opacity(0.3), in: Capsule())
                        .foregroundStyle(DS.Color.primaryText)
                }
            }
            RemoteThumb(urlString: avatar.thumbUrl)
                .frame(height: 220)
                .frame(maxWidth: .infinity)
                .background(DS.Color.raised, in: RoundedRectangle(cornerRadius: 16))
            if let m = avatar.measurements {
                HStack(spacing: 18) {
                    stat("Height", m.heightCm)
                    stat("Chest", m.chestCm)
                    stat("Waist", m.waistCm)
                    stat("Hip", m.hipCm)
                }
                Text("Units: \(Units.system.suffix)")
                    .font(.caption2).foregroundStyle(DS.Color.tertiaryText)
            }
            if let c = avatar.confidence {
                Text("Estimated confidence: \(Int(c * 100))% — measurements are editable.")
                    .font(.footnote).foregroundStyle(DS.Color.secondaryText)
            }
        }
        .card()
    }

    private func stat(_ label: String, _ value: Double?) -> some View {
        VStack {
            Text(Units.value(cm: value))
                .font(.headline).foregroundStyle(DS.Color.primaryText)
            Text(label).font(.caption2).foregroundStyle(DS.Color.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Loads a thumbnail from a short-lived signed URL.
struct RemoteThumb: View {
    let urlString: String?
    var body: some View {
        if let s = urlString, let url = URL(string: s) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFit()
                case .failure: placeholder
                default: ProgressView().tint(DS.Color.accent)
                }
            }
        } else { placeholder }
    }
    private var placeholder: some View {
        Image(systemName: "figure.stand")
            .font(.system(size: 60)).foregroundStyle(DS.Color.tertiaryText)
    }
}

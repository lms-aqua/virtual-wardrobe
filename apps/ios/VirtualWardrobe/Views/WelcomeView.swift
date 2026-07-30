import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var session: AuthStore
    @State private var email = ""
    @State private var isAdult = false
    @State private var showTokenEntry = false
    @State private var pastedToken = ""
    @State private var showSettings = false

    private var canSend: Bool {
        email.contains("@") && isAdult && !session.isLoading
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                privacyCard
                signInCard
                Text("Avatar generation uses a clearly-labeled mock in this build. No claims of tailoring- or medical-grade accuracy.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(20)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .top) { toolbar }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .alert("Something went wrong", isPresented: .constant(session.errorMessage != nil)) {
            Button("OK") { session.errorMessage = nil }
        } message: { Text(session.errorMessage ?? "") }
    }

    private var toolbar: some View {
        HStack {
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape").foregroundStyle(.white.opacity(0.7))
            }
            .padding(.trailing, 20).padding(.top, 8)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Virtual Wardrobe")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent2)
                .textCase(.uppercase)
                .kerning(2)
            Text("Your body.\nYour avatar.\nYour privacy.")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Build a personalized 3D avatar from a guided body scan, then try on digital clothing — private by design.")
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(.top, 8)
    }

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Privacy you can verify", systemImage: "lock.shield.fill")
                .font(.headline).foregroundStyle(.white)
            ForEach(Self.privacyPoints, id: \.self) { point in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                    Text(point).foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .card()
    }

    private var signInCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Get started").font(.headline).foregroundStyle(.white)
            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .padding(14)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)

            Toggle(isOn: $isAdult) {
                Text("I confirm I am 18 or older and consent to creating an account.")
                    .font(.footnote).foregroundStyle(.white.opacity(0.8))
            }
            .tint(Theme.accent)

            if showTokenEntry {
                Text("We emailed you a sign-in code. Paste it here:")
                    .font(.footnote).foregroundStyle(.white.opacity(0.7))
                TextField("Sign-in token", text: $pastedToken)
                    .autocapitalization(.none)
                    .padding(14)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
                Button("Verify & continue") {
                    Task { _ = await session.verify(token: pastedToken) }
                }
                .buttonStyle(PrimaryButtonStyle())
            } else {
                Button {
                    Task {
                        let ok = await session.signIn(email: email, isAdult: isAdult)
                        if ok && !session.isAuthenticated { showTokenEntry = true }
                    }
                } label: {
                    if session.isLoading { ProgressView().tint(.white) }
                    else { Text("Continue with email") }
                }
                .buttonStyle(PrimaryButtonStyle(enabled: canSend))
                .disabled(!canSend)
            }
        }
        .card()
    }

    static let privacyPoints = [
        "Adults only, explicit consent before any scan.",
        "Scans upload to private storage — never a public link.",
        "Raw photos are deleted after your avatar is built.",
        "No face recognition. Crop or blur your face anytime.",
        "One tap deletes everything, permanently.",
    ]
}

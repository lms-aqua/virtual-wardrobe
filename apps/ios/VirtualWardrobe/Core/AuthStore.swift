import Foundation

@MainActor
final class AuthStore: ObservableObject {
    @Published var user: UserDTO?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let tokenKey = "vw.sessionToken"

    var token: String? { Keychain.get(tokenKey) }
    var api: APIClient { APIClient(token: token) }
    var isAuthenticated: Bool { user != nil }

    func bootstrap() async {
        guard token != nil else { return }
        await refreshUser()
        await pullPreferences()
    }

    /// Pull account-synced preferences and apply them locally.
    func pullPreferences() async {
        guard user != nil else { return }
        if let p = try? await api.getPreferences() { PrefsSync.apply(p) }
    }

    /// Push current local preferences to the account (fire-and-forget).
    func pushPreferences() {
        guard user != nil else { return }
        Task { try? await api.putPreferences(PrefsSync.snapshot()) }
    }

    func refreshUser() async {
        do {
            user = try await api.me()
        } catch let e as APIError where e.isAuthFailure {
            // The session really is gone.
            user = nil
        } catch {
            // Transient (offline, DNS, 5xx). This used to clear `user` for ANY
            // error, so returning to the app on a flaky connection signed a
            // perfectly valid session out and bounced it to the welcome screen.
            // The token stays in the Keychain and the next refresh recovers.
        }
    }

    func signIn(email: String, isAdult: Bool) async -> Bool {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            let resp = try await api.requestMagicLink(email: email, isAdult: isAdult)
            // Dev convenience: if the backend returns the token (non-production),
            // complete sign-in automatically. In production the user taps the
            // link in their email and pastes/opens the token.
            if let dev = resp.devToken {
                return await verify(token: dev)
            }
            return true  // link "sent"; caller shows the paste-token screen
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func verify(token magicToken: String) async -> Bool {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            let auth = try await api.verifyMagicLink(token: magicToken)
            Keychain.set(auth.accessToken, for: tokenKey)
            await refreshUser()
            await pullPreferences()
            return user != nil
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func signOut() {
        Keychain.delete(tokenKey)
        user = nil
    }

    func deleteEverything() async {
        do {
            try await api.deleteAccount()
        } catch { /* even on error, sign out locally */ }
        signOut()
    }
}

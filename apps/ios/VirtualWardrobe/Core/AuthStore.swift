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
    }

    func refreshUser() async {
        do { user = try await api.me() }
        catch { user = nil }  // token invalid/expired → treat as signed out
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

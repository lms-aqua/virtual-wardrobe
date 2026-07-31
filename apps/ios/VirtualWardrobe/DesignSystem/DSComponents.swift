import SwiftUI

/// Generic async state for feature screens (loading/empty/error are first-class).
enum Loadable<Value> {
    case idle
    case loading
    case loaded(Value)
    case empty
    case failed(String)
}

// MARK: - Buttons (calm, Apple-native; no gradients)

struct DSPrimaryButton: ButtonStyle {
    var enabled: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .dsText(.button)
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(.white)
            .background(DS.Color.accent.opacity(enabled ? 1 : 0.4),
                        in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(DS.Motion.quick, value: configuration.isPressed)
    }
}

struct DSSecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .dsText(.button)
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(DS.Color.accent)
            .background(DS.Color.accent.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(DS.Motion.quick, value: configuration.isPressed)
    }
}

// MARK: - Card

struct DSCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(DS.Space.l)
            .background(DS.Color.raised,
                        in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
    }
}

extension View {
    func dsCard() -> some View { modifier(DSCard()) }
}

// MARK: - Section header

struct DSSectionHeader: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).dsText(.sectionTitle)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline).foregroundStyle(DS.Color.accent)
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Empty / error states (native ContentUnavailableView)

struct DSEmptyState: View {
    let title: String
    let systemImage: String
    var message: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            if let message { Text(message) }
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action).buttonStyle(.borderedProminent).tint(DS.Color.accent)
            }
        }
    }
}

struct DSErrorState: View {
    let message: String
    var retry: (() -> Void)?
    var body: some View {
        DSEmptyState(
            title: "Something went wrong",
            systemImage: "exclamationmark.triangle",
            message: message,
            actionTitle: retry != nil ? "Try again" : nil,
            action: retry
        )
    }
}

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
//
// One primary action per screen. Secondary and tertiary carry everything else.

struct DSPrimaryButton: ButtonStyle {
    var enabled: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .dsText(.button)
            .frame(maxWidth: .infinity, minHeight: DS.Size.controlProminent)
            .foregroundStyle(SwiftUI.Color.white)
            .background(DS.Color.accent.opacity(enabled ? 1 : 0.4),
                        in: RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(DS.Motion.quick, value: configuration.isPressed)
    }
}

struct DSSecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .dsText(.button)
            .frame(maxWidth: .infinity, minHeight: DS.Size.controlProminent)
            .foregroundStyle(DS.Color.accent)
            .background(DS.Color.accent.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(DS.Motion.quick, value: configuration.isPressed)
    }
}

/// Low-emphasis action — "Learn More", "Skip", "Reset Filters".
struct DSTertiaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .dsText(.button)
            .frame(minHeight: DS.Size.minTouch)
            .foregroundStyle(DS.Color.accent)
            .opacity(configuration.isPressed ? 0.6 : 1)
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

// MARK: - Studio background
//
// The neutral stage behind garments and avatars. A restrained vertical fade —
// the only sanctioned gradient, and it exists to seat the subject rather than
// to decorate.

struct DSStudioBackground: View {
    var body: some View {
        LinearGradient(
            colors: [DS.Color.raised, DS.Color.imageBackdrop.opacity(0.4)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
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

// MARK: - Status badge
//
// Colour is never the only signal: every status carries a symbol, a label, and
// a distinct shape, and exposes an explicit accessibility description.

struct DSProcessingBadge: View {
    enum Status {
        case processing, ready, failed, custom

        var label: String {
            switch self {
            case .processing: return "Processing"
            case .ready: return "Ready"
            case .failed: return "Failed"
            case .custom: return "Yours"
            }
        }

        var systemImage: String {
            switch self {
            case .processing: return "clock"
            case .ready: return "checkmark.circle"
            case .failed: return "exclamationmark.triangle"
            case .custom: return "person.crop.circle"
            }
        }

        var tint: SwiftUI.Color {
            switch self {
            case .processing: return DS.Color.warning
            case .ready: return DS.Color.success
            case .failed: return DS.Color.destructive
            case .custom: return DS.Color.accent
            }
        }

        var accessibilityDescription: String {
            switch self {
            case .processing: return "still processing"
            case .ready: return "ready to try on"
            case .failed: return "processing failed"
            case .custom: return "your own garment"
            }
        }
    }

    let status: Status

    var body: some View {
        Label(status.label, systemImage: status.systemImage)
            .dsText(.status)
            .foregroundStyle(SwiftUI.Color.white)
            .padding(.horizontal, DS.Space.s)
            .padding(.vertical, DS.Space.xs)
            .background(status.tint, in: Capsule())
            .accessibilityLabel(status.accessibilityDescription)
    }
}

// MARK: - Filter chip

struct DSFilterChip: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .dsText(.itemMeta)
                .foregroundStyle(isActive ? DS.Color.accent : DS.Color.secondaryText)
                .padding(.horizontal, DS.Space.m)
                .frame(minHeight: DS.Size.controlCompact)
        }
        .dsGlassCapsule(active: isActive)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Skeleton loading
//
// Initial loads preserve screen structure instead of blanking to a spinner.
// Deliberately static — a dozen independently-shimmering placeholders is
// visual noise, not polish.

struct DSGarmentSkeletonCell: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .fill(DS.Color.skeleton)
                .aspectRatio(DS.Ratio.garment, contentMode: .fit)
            RoundedRectangle(cornerRadius: DS.Radius.compact / 2, style: .continuous)
                .fill(DS.Color.skeleton)
                .frame(height: 14)
                .frame(maxWidth: .infinity, alignment: .leading)
            RoundedRectangle(cornerRadius: DS.Radius.compact / 2, style: .continuous)
                .fill(DS.Color.skeleton)
                .frame(width: 64, height: 12)
        }
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
    var title: String = "Something Went Wrong"
    let message: String
    var systemImage: String = "exclamationmark.triangle"
    var retry: (() -> Void)?
    var body: some View {
        DSEmptyState(
            title: title,
            systemImage: systemImage,
            message: message,
            actionTitle: retry != nil ? "Try Again" : nil,
            action: retry
        )
    }
}

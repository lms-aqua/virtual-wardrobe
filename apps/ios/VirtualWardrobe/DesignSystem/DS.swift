import SwiftUI
import UIKit

/// The v2.0 design system: semantic tokens for spacing, radius, typography,
/// color, control sizing, and motion. Content-first and Apple-native — colors
/// map to system colors so the app adapts to Light/Dark, Increased Contrast,
/// and tinting automatically.
///
/// Glass lives in `DSGlass.swift`; reusable components in `DSComponents.swift`.
/// (The legacy `Theme` remains until each screen is migrated onto `DS`.)
enum DS {

    // MARK: Spacing scale (2, 4, 8, 12, 16, 20, 24, 32, 40)
    enum Space {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
        static let huge: CGFloat = 40

        /// Standard screen horizontal margin.
        static let screenMargin: CGFloat = 16
        /// Separation between major sections.
        static let section: CGFloat = 28
    }

    // MARK: Corner radius — semantic roles, continuous shapes throughout
    enum Radius {
        /// Dense controls: chips, small badges.
        static let compact: CGFloat = 10
        /// Buttons, toolbars, compact glass controls.
        static let control: CGFloat = 14
        /// Content cards and garment thumbnails.
        static let card: CGFloat = 18
        /// Large hero containers (garment detail stage, avatar stage).
        static let prominent: CGFloat = 24

        // Legacy aliases retained so unmigrated screens keep compiling.
        static let thumb: CGFloat = 18
        static let container: CGFloat = 24
    }

    // MARK: Control sizing
    enum Size {
        /// Apple's minimum comfortable touch target.
        static let minTouch: CGFloat = 44
        /// Compact icon-only control (still padded to `minTouch` when tappable).
        static let controlCompact: CGFloat = 36
        static let controlRegular: CGFloat = 44
        static let controlProminent: CGFloat = 50
        /// Icon-only circular floating control.
        static let floating: CGFloat = 56
    }

    // MARK: Image aspect ratios
    enum Ratio {
        /// Garment grid cells — square keeps the grid rhythm even.
        static let garment: CGFloat = 1.0
        /// Hero garment / avatar stage — portrait suits clothing and bodies.
        static let hero: CGFloat = 0.78
    }

    // MARK: Semantic colors (auto light/dark via system colors)
    enum Color {
        static let appBackground = SwiftUI.Color(uiColor: .systemBackground)
        static let grouped = SwiftUI.Color(uiColor: .systemGroupedBackground)
        static let raised = SwiftUI.Color(uiColor: .secondarySystemBackground)
        static let raisedGrouped = SwiftUI.Color(uiColor: .secondarySystemGroupedBackground)
        static let fill = SwiftUI.Color(uiColor: .tertiarySystemFill)
        static let primaryText = SwiftUI.Color(uiColor: .label)
        static let secondaryText = SwiftUI.Color(uiColor: .secondaryLabel)
        static let tertiaryText = SwiftUI.Color(uiColor: .tertiaryLabel)
        static let separator = SwiftUI.Color(uiColor: .separator)
        static let accent = SwiftUI.Color(red: 0.43, green: 0.37, blue: 0.99)
        static let success = SwiftUI.Color(uiColor: .systemGreen)
        static let warning = SwiftUI.Color(uiColor: .systemOrange)
        static let destructive = SwiftUI.Color(uiColor: .systemRed)
        static let favorite = SwiftUI.Color(uiColor: .systemPink)
        /// Neutral backdrop behind garment/avatar imagery.
        static let imageBackdrop = SwiftUI.Color(uiColor: .secondarySystemBackground)
        /// Skeleton placeholder fill while content loads.
        static let skeleton = SwiftUI.Color(uiColor: .quaternarySystemFill)
    }

    // MARK: Typography roles (system text styles → Dynamic Type for free)
    enum Text {
        case largeScreenTitle, screenTitle, sectionTitle, itemTitle
        case itemMeta, supporting, status, caption, button

        var font: Font {
            switch self {
            case .largeScreenTitle: return .largeTitle.bold()
            case .screenTitle: return .title2.weight(.semibold)
            case .sectionTitle: return .title3.weight(.semibold)
            case .itemTitle: return .headline
            case .itemMeta: return .subheadline
            case .supporting: return .subheadline
            case .status: return .caption.weight(.semibold)
            case .caption: return .caption
            case .button: return .body.weight(.semibold)
            }
        }

        var color: SwiftUI.Color {
            switch self {
            case .itemMeta, .supporting, .caption: return DS.Color.secondaryText
            default: return DS.Color.primaryText
            }
        }
    }

    // MARK: Motion
    enum Motion {
        static let quick = Animation.easeOut(duration: 0.18)
        static let standard = Animation.spring(response: 0.34, dampingFraction: 0.86)
        /// Content appearing/disappearing in a grid.
        static let content = Animation.easeInOut(duration: 0.24)

        /// Returns `nil` when Reduce Motion is on so SwiftUI applies the change
        /// immediately instead of animating movement.
        static func adaptive(_ animation: Animation, reduceMotion: Bool) -> Animation? {
            reduceMotion ? nil : animation
        }
    }

    // MARK: Haptics — used only for meaningful, user-initiated outcomes.
    enum Haptic {
        static func success() {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        static func warning() {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
        static func selection() {
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
}

extension View {
    /// Apply a semantic typography role (font + default color).
    func dsText(_ role: DS.Text) -> some View {
        font(role.font).foregroundStyle(role.color)
    }
}

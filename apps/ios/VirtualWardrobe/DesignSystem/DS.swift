import SwiftUI
import UIKit

/// The v2.0 design system: semantic tokens for spacing, radius, typography, and
/// colors. Content-first and Apple-native — colors map to system colors so the
/// app adapts to Light/Dark, Increased Contrast, and tinting automatically.
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
    }

    // MARK: Corner radius
    enum Radius {
        static let thumb: CGFloat = 12
        static let card: CGFloat = 16
        static let container: CGFloat = 22
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
    }

    // MARK: Typography roles (system text styles → Dynamic Type for free)
    enum Text {
        case screenTitle, sectionTitle, itemTitle, itemMeta, supporting, caption, button

        var font: Font {
            switch self {
            case .screenTitle: return .largeTitle.bold()
            case .sectionTitle: return .title3.weight(.semibold)
            case .itemTitle: return .headline
            case .itemMeta: return .subheadline
            case .supporting: return .subheadline
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

    // MARK: Animation
    enum Motion {
        static let quick = Animation.easeOut(duration: 0.18)
        static let standard = Animation.spring(response: 0.34, dampingFraction: 0.86)
    }
}

extension View {
    /// Apply a semantic typography role (font + default color).
    func dsText(_ role: DS.Text) -> some View {
        font(role.font).foregroundStyle(role.color)
    }
}

import ClueEngine
import SwiftUI
import UIKit

/// The look of the app: a detective's notebook. Warm paper, deep red ink for
/// pencil marks and highlights, serif type, and a tight ruled grid. Every
/// colour has a light and a dark version.
enum Theme {
    /// The page behind everything.
    static let paper = dynamic(light: 0xF5EFE3, dark: 0x1A1816)
    /// Panels that sit on the page: the solution and each part of the grid.
    static let card = dynamic(light: 0xFFFCF6, dark: 0x25221F)
    /// Every other row of the grid, to help the eye along a line.
    static let stripe = dynamic(light: 0xF8F2E7, dark: 0x2B2825)
    /// Grid lines.
    static let rule = dynamic(light: 0xDDD3C2, dark: 0x3D3934)
    /// Ink for card names and marks.
    static let ink = dynamic(light: 0x2B2622, dark: 0xEDE6DA)
    static let fadedInk = dynamic(light: 0x9A9084, dark: 0x847B70)
    /// Deep red, from the classic board game box.
    static let accent = dynamic(light: 0xA3262A, dark: 0xE0575A)
    /// "Has it": a confident green that still reads on paper.
    static let has = dynamic(light: 0x2F7D4F, dark: 0x5CC48A)

    static func tint(for category: ClueEngine.Category) -> Color {
        switch category {
        case .suspect: return accent
        case .weapon: return dynamic(light: 0x3D5A80, dark: 0x8AAAD6)
        case .room: return dynamic(light: 0xA86B12, dark: 0xE0A64A)
        }
    }

    static func icon(for category: ClueEngine.Category) -> String {
        switch category {
        case .suspect: return "person.fill"
        case .weapon: return "hammer.fill"
        case .room: return "house.fill"
        }
    }

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            rgb(traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    private static func rgb(_ hex: UInt32) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1)
    }
}

extension View {
    /// Puts a form or list on the notebook's paper instead of system grey.
    func paperBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(Theme.paper)
    }
}

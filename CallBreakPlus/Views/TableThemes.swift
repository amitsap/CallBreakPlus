import SwiftUI

extension TableThemeChoice {
    var theme: TableTheme {
        switch self {
        case .classic: .classic
        case .royal: .royal
        case .maroon: .maroon
        case .midnight: .midnight
        }
    }
}

extension TableTheme {
    /// Deep blue felt, walnut.
    static let royal = TableTheme(
        felt: [
            Color(red: 0.12, green: 0.29, blue: 0.52),
            Color(red: 0.06, green: 0.17, blue: 0.34),
            Color(red: 0.03, green: 0.09, blue: 0.20),
        ],
        wood: [
            Color(red: 0.22, green: 0.12, blue: 0.08),
            Color(red: 0.43, green: 0.27, blue: 0.16),
            Color(red: 0.28, green: 0.15, blue: 0.09),
        ],
        rim: [
            Color(red: 0.91, green: 0.74, blue: 0.43).opacity(0.55),
            Color(red: 0.31, green: 0.20, blue: 0.10).opacity(0.7),
        ]
    )
    /// Burgundy felt, teak.
    static let maroon = TableTheme(
        felt: [
            Color(red: 0.46, green: 0.14, blue: 0.23),
            Color(red: 0.30, green: 0.07, blue: 0.14),
            Color(red: 0.18, green: 0.03, blue: 0.08),
        ],
        wood: [
            Color(red: 0.39, green: 0.22, blue: 0.10),
            Color(red: 0.62, green: 0.42, blue: 0.21),
            Color(red: 0.43, green: 0.25, blue: 0.11),
        ],
        rim: [
            Color(red: 0.98, green: 0.77, blue: 0.37).opacity(0.55),
            Color(red: 0.40, green: 0.22, blue: 0.09).opacity(0.7),
        ]
    )
    /// Charcoal-green felt, ebony.
    static let midnight = TableTheme(
        felt: [
            Color(red: 0.16, green: 0.25, blue: 0.23),
            Color(red: 0.08, green: 0.15, blue: 0.14),
            Color(red: 0.035, green: 0.075, blue: 0.065),
        ],
        wood: [
            Color(red: 0.07, green: 0.065, blue: 0.06),
            Color(red: 0.19, green: 0.17, blue: 0.14),
            Color(red: 0.095, green: 0.08, blue: 0.065),
        ],
        rim: [
            Color(red: 0.76, green: 0.71, blue: 0.49).opacity(0.55),
            Color(red: 0.23, green: 0.22, blue: 0.16).opacity(0.7),
        ]
    )
}

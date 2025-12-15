import SwiftUI

enum AppTypography {
    case titleLarge      // 28pt Bold - SF Pro Display
    case titleMedium     // 22pt Semibold - SF Pro Display
    case titleSmall      // 17pt Semibold - SF Pro Text
    case body            // 15pt Regular - SF Pro Text
    case caption         // 13pt Regular - SF Pro Text
    case label           // 11pt Medium - SF Pro Text

    var font: Font {
        switch self {
        case .titleLarge:
            return .system(size: 28, weight: .bold, design: .default)
        case .titleMedium:
            return .system(size: 22, weight: .semibold, design: .default)
        case .titleSmall:
            return .system(size: 17, weight: .semibold, design: .default)
        case .body:
            return .system(size: 15, weight: .regular, design: .default)
        case .caption:
            return .system(size: 13, weight: .regular, design: .default)
        case .label:
            return .system(size: 11, weight: .medium, design: .default)
        }
    }
}

// MARK: - View Extension for Typography
extension View {
    func appFont(_ style: AppTypography) -> some View {
        self.font(style.font)
    }
}

// MARK: - Text Extension for Typography
extension Text {
    func appStyle(_ style: AppTypography, color: Color = .textPrimary) -> Text {
        self.font(style.font).foregroundColor(color)
    }
}

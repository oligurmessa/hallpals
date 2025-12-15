import SwiftUI

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.appPrimary)
                .cornerRadius(AppRadius.button)
        }
    }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.appPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.button)
                        .stroke(Color.appPrimary, lineWidth: 1)
                )
        }
    }
}

#Preview {
    VStack(spacing: AppSpacing.md) {
        PrimaryButton(title: "Primary Action") {
            print("Primary tapped")
        }

        SecondaryButton(title: "Secondary Action") {
            print("Secondary tapped")
        }
    }
    .padding(AppSpacing.lg)
    .background(Color.appBackground)
}

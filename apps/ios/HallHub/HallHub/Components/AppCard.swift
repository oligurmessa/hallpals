import SwiftUI

struct AppCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(AppSpacing.md)
            .background(Color.appSurface)
            .cornerRadius(AppRadius.card)
            .shadow(
                color: Color.black.opacity(0.05),
                radius: 8,
                x: 0,
                y: 2
            )
    }
}

#Preview {
    VStack(spacing: AppSpacing.md) {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Card Title")
                    .appStyle(.titleSmall)
                Text("This is a sample card with some content.")
                    .appStyle(.body, color: .textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        AppCard {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.appSecondary)
                Text("Highlighted Content")
                    .appStyle(.body)
            }
        }
    }
    .padding(AppSpacing.md)
    .background(Color.appBackground)
}

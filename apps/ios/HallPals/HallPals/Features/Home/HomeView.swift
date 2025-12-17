import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var roleManager: RoleManager

    var body: some View {
        Group {
            switch roleManager.selectedRole {
            case .ra:
                RAHomeView()
            case .resident:
                ResidentHomeView()
            case .none:
                // Brief loading while role syncs from AppState
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

#Preview("RA Home") {
    HomeView()
        .environmentObject({
            let rm = RoleManager()
            rm.selectRole(.ra)
            return rm
        }())
}

#Preview("Resident Home") {
    HomeView()
        .environmentObject({
            let rm = RoleManager()
            rm.selectRole(.resident)
            return rm
        }())
}

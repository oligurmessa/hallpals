import SwiftUI

@MainActor
final class RoleManager: ObservableObject {
    @Published var selectedRole: UserRole?
    @Published var hasCompletedRoleSelection: Bool = false

    // Dev mode flag - set to false for production
    static let devMode = true

    // Dev codes for role verification
    private static let devCodes: [UserRole: String] = [
        .resident: "DEV-RES",
        .ra: "DEV-RA"
    ]

    /// Validates the entered code against the dev code for the selected role
    func validateCode(_ code: String, for role: UserRole) -> Bool {
        guard RoleManager.devMode else {
            // In production mode, skip code verification
            return true
        }
        return Self.devCodes[role]?.uppercased() == code.uppercased()
    }

    /// Select role after code verification
    func selectRole(_ role: UserRole, withCode code: String) -> Bool {
        if validateCode(code, for: role) {
            selectedRole = role
            hasCompletedRoleSelection = true
            return true
        }
        return false
    }

    func selectRole(_ role: UserRole) {
        selectedRole = role
        hasCompletedRoleSelection = true
    }

    func resetRole() {
        selectedRole = nil
        hasCompletedRoleSelection = false
    }
}

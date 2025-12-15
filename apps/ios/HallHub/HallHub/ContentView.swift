import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var roleManager: RoleManager
    @State private var isFetchingRole = false

    var body: some View {
        Group {
            switch appState.authState {
            case .loading:
                // Brief loading state while checking auth
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.appBackground)

            case .needsRoleCode:
                // Step 1: Role selection with code gate
                OnboardingRoleView()

            case .needsAuth:
                // Step 2: Sign in / Sign up
                OnboardingAuthView()

            case .needsVerification:
                // Step 3: Email Verification
                EmailVerificationView()

            case .authenticated:
                // User is signed in and onboarding complete
                if roleManager.selectedRole != nil {
                    MainTabView()
                } else {
                    // Still loading role from Firestore
                    ProgressView("Loading profile...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.appBackground)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.authState)
        // Sync role from AppState to RoleManager when authenticated
        .onChange(of: appState.authState) { _, newState in
            if newState == .authenticated {
                Task {
                    await syncRole()
                }
            } else if newState == .needsRoleCode {
                roleManager.resetRole()
            }
        }
        // Also sync on initial appear if already authenticated
        .onAppear {
            if appState.authState == .authenticated {
                Task {
                    await syncRole()
                }
            }
        }
    }

    /// Syncs role from AppState.savedRole or fetches from Firestore
    private func syncRole() async {
        // If we already have a role, use it
        if let role = appState.savedRole {
            roleManager.selectRole(role)
            return
        }

        // Otherwise, fetch from Firestore
        guard let uid = appState.currentUserId else {
            #if DEBUG
            print("🔄 SYNC: No user ID available to fetch role")
            #endif
            // Default to resident if we can't fetch
            roleManager.selectRole(.resident)
            return
        }

        guard !isFetchingRole else { return }
        isFetchingRole = true

        do {
            if let fetchedRole = try await FirestoreService.shared.fetchUserRole(uid: uid) {
                appState.savedRole = fetchedRole
                roleManager.selectRole(fetchedRole)
                #if DEBUG
                print("🔄 SYNC: Role fetched from Firestore: \(fetchedRole.displayName)")
                #endif
            } else {
                // No role in Firestore, default to resident
                roleManager.selectRole(.resident)
                #if DEBUG
                print("🔄 SYNC: No role in Firestore, defaulting to resident")
                #endif
            }
        } catch {
            #if DEBUG
            print("🔄 SYNC: Error fetching role: \(error.localizedDescription), defaulting to resident")
            #endif
            // Default to resident on error
            roleManager.selectRole(.resident)
        }

        isFetchingRole = false
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState.shared)
        .environmentObject(RoleManager())
        .environmentObject(ResourceStore())
        .environmentObject(FirebaseAuthManager.shared)
}

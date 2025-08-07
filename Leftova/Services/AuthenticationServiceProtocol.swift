import Foundation
import Supabase

protocol AuthenticationServiceProtocol {
    var currentUser: AuthUser? { get }
    var isAuthenticated: Bool { get }
    
    func signUp(email: String, password: String) async throws -> AuthUser
    func signIn(email: String, password: String) async throws -> AuthUser
    func signOut() async throws
    func getCurrentUser() async throws -> AuthUser?
    func resetPassword(email: String) async throws
}

class AuthenticationService: AuthenticationServiceProtocol, ObservableObject {
    static let shared = AuthenticationService()
    
    private let client = SupabaseService.shared.client
    @Published var currentUser: AuthUser?
    @Published var isAuthenticated = false
    
    private init() {
        // Check session on init
        Task {
            await checkCurrentSession()
        }
    }
    
    // MARK: - Authentication Methods
    
    func signUp(email: String, password: String) async throws -> AuthUser {
        let response = try await client.auth.signUp(
            email: email,
            password: password
        )
        
        // No optional binding needed if response.user is non-optional
        let user = response.user
        let authUser = createAuthUser(from: user)
        
        await MainActor.run {
            self.currentUser = authUser
            self.isAuthenticated = true
        }
        
        return authUser
    }
    
    func signIn(email: String, password: String) async throws -> AuthUser {
        let response = try await client.auth.signIn(
            email: email,
            password: password
        )
        
        // No optional binding needed if response.user is non-optional
        let user = response.user
        let authUser = createAuthUser(from: user)
        
        await MainActor.run {
            self.currentUser = authUser
            self.isAuthenticated = true
        }
        
        return authUser
    }
    
    func signOut() async throws {
        try await client.auth.signOut()
        
        await MainActor.run {
            self.currentUser = nil
            self.isAuthenticated = false
        }
    }
    
    func getCurrentUser() async throws -> AuthUser? {
        do {
            // Try to get the current session
            let session = try await client.auth.session
            let user = session.user
            
            let authUser = createAuthUser(from: user)
            
            await MainActor.run {
                self.currentUser = authUser
                self.isAuthenticated = true
            }
            
            return authUser
        } catch {
            // If there's no session or an error occurs
            await MainActor.run {
                self.currentUser = nil
                self.isAuthenticated = false
            }
            return nil
        }
    }
    
    func resetPassword(email: String) async throws {
        try await client.auth.resetPasswordForEmail(email)
    }
    
    // MARK: - Session Management
    
    @MainActor
    private func checkCurrentSession() async {
        do {
            _ = try await getCurrentUser()
        } catch {
            print("Session check failed: \(error)")
            currentUser = nil
            isAuthenticated = false
        }
    }
    
    // MARK: - Helper Methods
    
    private func createAuthUser(from user: Supabase.User) -> AuthUser {
        return AuthUser(
            id: user.id.uuidString,
            email: user.email,
            emailConfirmedAt: user.emailConfirmedAt,
            lastSignInAt: user.lastSignInAt
        )
    }
    
    var currentUserId: String? {
        return currentUser?.id
    }
    
    func requireAuthentication() throws {
        guard isAuthenticated, currentUser != nil else {
            throw AuthError.notAuthenticated
        }
    }
}

// MARK: - Auth Errors
enum AuthError: LocalizedError {
    case notAuthenticated
    case userCreationFailed
    case signInFailed
    case invalidCredentials
    case emailAlreadyRegistered
    case weakPassword
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be logged in to perform this action"
        case .userCreationFailed:
            return "Failed to create user account"
        case .signInFailed:
            return "Failed to sign in"
        case .invalidCredentials:
            return "Invalid email or password"
        case .emailAlreadyRegistered:
            return "This email is already registered"
        case .weakPassword:
            return "Password must be at least 6 characters long"
        case .networkError:
            return "Network connection error"
        }
    }
}

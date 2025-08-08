//
//  AuthenticationService.swift
//  Leftova
//
//  Modern authentication service with clean architecture
//

import Foundation
import SwiftUI
import Supabase

// MARK: - Authentication Service Protocol
protocol AuthenticationServiceProtocol {
    var currentUser: AuthUser? { get }
    var currentUserId: String? { get }
    var isAuthenticated: Bool { get }
    
    func signUp(email: String, password: String) async throws -> AuthUser
    func signIn(email: String, password: String) async throws -> AuthUser
    func signOut() async throws
    func getCurrentUser() async throws -> AuthUser?
    func resetPassword(email: String) async throws
}

// MARK: - Authentication Service Implementation
@MainActor
final class AuthenticationService: AuthenticationServiceProtocol, ObservableObject {
    static let shared = AuthenticationService()
    
    // MARK: - Published Properties
    @Published var currentUser: AuthUser?
    @Published var isAuthenticated = false
    
    // MARK: - Dependencies
    private let client = SupabaseService.shared.client
    
    // MARK: - Computed Properties
    var currentUserId: String? {
        currentUser?.id
    }
    
    // MARK: - Initialization
    private init() {
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
        
        let user = response.user
        let authUser = createAuthUser(from: user)
        
        updateAuthState(with: authUser, isAuthenticated: true)
        return authUser
    }
    
    func signIn(email: String, password: String) async throws -> AuthUser {
        let response = try await client.auth.signIn(
            email: email,
            password: password
        )
        
        let user = response.user
        let authUser = createAuthUser(from: user)
        
        updateAuthState(with: authUser, isAuthenticated: true)
        return authUser
    }
    
    func signOut() async throws {
        try await client.auth.signOut()
        updateAuthState(with: nil, isAuthenticated: false)
    }
    
    func getCurrentUser() async throws -> AuthUser? {
        do {
            let session = try await client.auth.session
            let user = session.user
            let authUser = createAuthUser(from: user)
            
            updateAuthState(with: authUser, isAuthenticated: true)
            return authUser
        } catch {
            updateAuthState(with: nil, isAuthenticated: false)
            return nil
        }
    }
    
    func resetPassword(email: String) async throws {
        // This sends a password reset email with a link
        // The user must click the link in the email to reset their password
        // The link will take them to a web page where they can enter a new password
        try await client.auth.resetPasswordForEmail(email)
        
        // Note: If you want to handle password reset in-app with deep linking,
        // you would need to configure redirectTo URL and handle the incoming link
    }
    
    func requireAuthentication() throws {
        guard isAuthenticated, currentUser != nil else {
            throw AuthError.notAuthenticated
        }
    }
    
    // MARK: - Private Methods
    private func checkCurrentSession() async {
        do {
            _ = try await getCurrentUser()
        } catch {
            updateAuthState(with: nil, isAuthenticated: false)
        }
    }
    
    private func createAuthUser(from user: Supabase.User) -> AuthUser {
        AuthUser(
            id: user.id.uuidString,
            email: user.email,
            emailConfirmedAt: user.emailConfirmedAt,
            lastSignInAt: user.lastSignInAt
        )
    }
    
    private func updateAuthState(with user: AuthUser?, isAuthenticated: Bool) {
        self.currentUser = user
        self.isAuthenticated = isAuthenticated
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
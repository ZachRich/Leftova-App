//
//  AuthenticationViewModel.swift
//  Leftova
//
//  Created by Zach Rich on 8/6/25.
//


import Foundation
import SwiftUI

@MainActor
class AuthenticationViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingResetPassword = false
    @Published var resetPasswordEmail = ""
    @Published var resetPasswordSent = false
    
    private let authService: AuthenticationServiceProtocol
    
    init(authService: AuthenticationServiceProtocol = AuthenticationService.shared) {
        self.authService = authService
    }
    
    // MARK: - Authentication Actions
    
    func signIn() async {
        guard validateSignInInputs() else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await authService.signIn(email: email, password: password)
            clearFields()
        } catch {
            errorMessage = handleAuthError(error)
        }
        
        isLoading = false
    }
    
    func signUp() async {
        guard validateSignUpInputs() else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await authService.signUp(email: email, password: password)
            clearFields()
        } catch {
            errorMessage = handleAuthError(error)
        }
        
        isLoading = false
    }
    
    func signOut() async {
        isLoading = true
        
        do {
            try await authService.signOut()
        } catch {
            errorMessage = "Failed to sign out: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func resetPassword() async {
        guard !resetPasswordEmail.isEmpty else {
            errorMessage = "Please enter your email address"
            return
        }
        
        guard isValidEmail(resetPasswordEmail) else {
            errorMessage = "Please enter a valid email address"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.resetPassword(email: resetPasswordEmail)
            resetPasswordSent = true
            showingResetPassword = false
            resetPasswordEmail = ""
        } catch {
            errorMessage = "Failed to send reset email: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Validation
    
    private func validateSignInInputs() -> Bool {
        if email.isEmpty {
            errorMessage = "Email is required"
            return false
        }
        
        if password.isEmpty {
            errorMessage = "Password is required"
            return false
        }
        
        if !isValidEmail(email) {
            errorMessage = "Please enter a valid email address"
            return false
        }
        
        return true
    }
    
    private func validateSignUpInputs() -> Bool {
        if email.isEmpty {
            errorMessage = "Email is required"
            return false
        }
        
        if password.isEmpty {
            errorMessage = "Password is required"
            return false
        }
        
        if confirmPassword.isEmpty {
            errorMessage = "Please confirm your password"
            return false
        }
        
        if !isValidEmail(email) {
            errorMessage = "Please enter a valid email address"
            return false
        }
        
        if password.count < 6 {
            errorMessage = "Password must be at least 6 characters long"
            return false
        }
        
        if password != confirmPassword {
            errorMessage = "Passwords do not match"
            return false
        }
        
        return true
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    // MARK: - Helper Methods
    
    private func clearFields() {
        email = ""
        password = ""
        confirmPassword = ""
        errorMessage = nil
    }
    
    private func handleAuthError(_ error: Error) -> String {
        if let authError = error as? AuthError {
            return authError.localizedDescription
        }
        
        let errorString = error.localizedDescription.lowercased()
        
        if errorString.contains("invalid") || errorString.contains("wrong") {
            return "Invalid email or password"
        } else if errorString.contains("email") && errorString.contains("taken") {
            return "This email is already registered"
        } else if errorString.contains("password") && errorString.contains("weak") {
            return "Password is too weak"
        } else if errorString.contains("network") || errorString.contains("connection") {
            return "Network connection error"
        } else {
            return "Authentication failed: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Computed Properties
    
    var isSignInButtonDisabled: Bool {
        return email.isEmpty || password.isEmpty || isLoading
    }
    
    var isSignUpButtonDisabled: Bool {
        return email.isEmpty || password.isEmpty || confirmPassword.isEmpty || isLoading
    }
}
//
//  ProfileView.swift
//  Leftova
//
//  Created by Zach Rich on 8/6/25.
//


import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authService: AuthenticationService
    @StateObject private var viewModel = ProfileViewModel()
    
    var body: some View {
        NavigationView {
            List {
                // User Info Section
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text(authService.currentUser?.email ?? "Unknown")
                                .font(.headline)
                            
                            Text("Member since \(formatDate(authService.currentUser?.emailConfirmedAt))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
                // Stats Section
                Section("Statistics") {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                        Text("Saved Recipes")
                        Spacer()
                        Text("\(viewModel.savedRecipesCount)")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Settings Section
                Section("Settings") {
                    NavigationLink(destination: ChangePasswordView()) {
                        HStack {
                            Image(systemName: "key.fill")
                                .foregroundColor(.blue)
                            Text("Change Password")
                        }
                    }
                    
                    Button(action: {
                        viewModel.showingDeleteAccount = true
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.red)
                            Text("Delete Account")
                                .foregroundColor(.red)
                        }
                    }
                }
                
                // Sign Out Section
                Section {
                    Button(action: {
                        Task {
                            await viewModel.signOut()
                        }
                    }) {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .foregroundColor(.red)
                            }
                            
                            Text("Sign Out")
                                .foregroundColor(.red)
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .navigationTitle("Profile")
            .task {
                await viewModel.loadStats()
            }
            .alert("Delete Account", isPresented: $viewModel.showingDeleteAccount) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        await viewModel.deleteAccount()
                    }
                }
            } message: {
                Text("Are you sure you want to delete your account? This action cannot be undone and will remove all your saved recipes.")
            }
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage ?? "An unknown error occurred")
            }
        }
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var savedRecipesCount = 0
    @Published var isLoading = false
    @Published var showingDeleteAccount = false
    @Published var showingError = false
    @Published var errorMessage: String?
    
    private let authService = AuthenticationService.shared
    private let repository: RecipeRepositoryProtocol = RecipeRepository()
    
    func loadStats() async {
        do {
            let savedIds = try await repository.getSavedRecipeIds()
            savedRecipesCount = savedIds.count
        } catch {
            print("Failed to load stats: \(error)")
        }
    }
    
    func signOut() async {
        isLoading = true
        
        do {
            try await authService.signOut()
        } catch {
            errorMessage = "Failed to sign out: \(error.localizedDescription)"
            showingError = true
        }
        
        isLoading = false
    }
    
    func deleteAccount() async {
        isLoading = true
        
        do {
            // In a real implementation, you would call a delete account API
            // For now, we'll just sign out
            try await authService.signOut()
        } catch {
            errorMessage = "Failed to delete account: \(error.localizedDescription)"
            showingError = true
        }
        
        isLoading = false
    }
}

struct ChangePasswordView: View {
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var showingSuccess = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Form {
            Section("Current Password") {
                SecureField("Enter current password", text: $currentPassword)
            }
            
            Section("New Password") {
                SecureField("Enter new password", text: $newPassword)
                SecureField("Confirm new password", text: $confirmPassword)
            }
            
            if let errorMessage = errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            
            Section {
                Button("Change Password") {
                    Task {
                        await changePassword()
                    }
                }
                .disabled(isFormInvalid || isLoading)
            }
        }
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Success", isPresented: $showingSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your password has been changed successfully.")
        }
    }
    
    private var isFormInvalid: Bool {
        currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty || newPassword != confirmPassword || newPassword.count < 6
    }
    
    private func changePassword() async {
        guard newPassword == confirmPassword else {
            errorMessage = "New passwords do not match"
            return
        }
        
        guard newPassword.count >= 6 else {
            errorMessage = "Password must be at least 6 characters long"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // In a real implementation, you would call the Supabase change password API
        // For now, we'll simulate success
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        showingSuccess = true
        isLoading = false
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthenticationService.shared)
}
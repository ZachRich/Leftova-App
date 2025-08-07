import SwiftUI

struct AuthenticationView: View {
    @StateObject private var viewModel = AuthenticationViewModel()
    @State private var authMode: AuthMode = .signIn
    @FocusState private var focusedField: Field?
    
    enum AuthMode {
        case signIn, signUp
        
        var title: String {
            switch self {
            case .signIn: return "Welcome Back"
            case .signUp: return "Create Account"
            }
        }
        
        var buttonTitle: String {
            switch self {
            case .signIn: return "Sign In"
            case .signUp: return "Sign Up"
            }
        }
        
        var switchPrompt: String {
            switch self {
            case .signIn: return "Don't have an account?"
            case .signUp: return "Already have an account?"
            }
        }
        
        var switchAction: String {
            switch self {
            case .signIn: return "Sign Up"
            case .signUp: return "Sign In"
            }
        }
    }
    
    enum Field: Hashable {
        case email, password, confirmPassword
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background tap to dismiss keyboard
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        focusedField = nil
                    }
                
                ScrollView {
                    VStack(spacing: 24) {
                        // App Logo/Header
                        VStack(spacing: 8) {
                            Image(systemName: "fork.knife")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            
                            Text("Leftova")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Text("Find recipes with what you have")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 40)
                        
                        // Auth Form
                        VStack(spacing: 20) {
                            Text(authMode.title)
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            VStack(spacing: 16) {
                                // Email Field
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Email")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    TextField("Enter your email", text: $viewModel.email)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .keyboardType(.emailAddress)
                                        .autocapitalization(.none)
                                        .autocorrectionDisabled()
                                        .textContentType(.emailAddress)
                                        .focused($focusedField, equals: .email)
                                        .disabled(viewModel.isLoading)
                                        .onSubmit {
                                            focusedField = .password
                                        }
                                }
                                
                                // Password Field
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Password")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    SecureField("Enter your password", text: $viewModel.password)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .textContentType(authMode == .signUp ? .newPassword : .password)
                                        .focused($focusedField, equals: .password)
                                        .disabled(viewModel.isLoading)
                                        .onSubmit {
                                            if authMode == .signUp {
                                                focusedField = .confirmPassword
                                            } else {
                                                focusedField = nil
                                                Task {
                                                    await viewModel.signIn()
                                                }
                                            }
                                        }
                                }
                                
                                // Confirm Password (Sign Up only)
                                if authMode == .signUp {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Confirm Password")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        SecureField("Confirm your password", text: $viewModel.confirmPassword)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .textContentType(.newPassword)
                                            .focused($focusedField, equals: .confirmPassword)
                                            .disabled(viewModel.isLoading)
                                            .onSubmit {
                                                focusedField = nil
                                                Task {
                                                    await viewModel.signUp()
                                                }
                                            }
                                    }
                                    .transition(.move(edge: .top).combined(with: .opacity))
                                }
                            }
                            
                            // Error Message
                            if let errorMessage = viewModel.errorMessage {
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            
                            // Reset Password Success Message
                            if viewModel.resetPasswordSent {
                                Text("Password reset email sent! Check your inbox.")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            
                            // Auth Button
                            Button(action: {
                                focusedField = nil
                                Task {
                                    switch authMode {
                                    case .signIn:
                                        await viewModel.signIn()
                                    case .signUp:
                                        await viewModel.signUp()
                                    }
                                }
                            }) {
                                HStack {
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    }
                                    
                                    Text(authMode.buttonTitle)
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    (authMode == .signIn ? viewModel.isSignInButtonDisabled : viewModel.isSignUpButtonDisabled) ?
                                    Color.gray.opacity(0.3) : Color.blue
                                )
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .disabled(authMode == .signIn ? viewModel.isSignInButtonDisabled : viewModel.isSignUpButtonDisabled)
                            
                            // Forgot Password (Sign In only)
                            if authMode == .signIn {
                                Button("Forgot Password?") {
                                    focusedField = nil
                                    viewModel.showingResetPassword = true
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                            
                            // Switch Auth Mode
                            HStack {
                                Text(authMode.switchPrompt)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Button(authMode.switchAction) {
                                    focusedField = nil
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        authMode = authMode == .signIn ? .signUp : .signIn
                                        viewModel.errorMessage = nil
                                    }
                                }
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                            }
                            .padding(.top, 8)
                        }
                        .padding(.horizontal, 32)
                        
                        // Extra spacing for keyboard
                        Spacer(minLength: 100)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $viewModel.showingResetPassword) {
            ResetPasswordView(viewModel: viewModel)
        }
    }
}

struct ResetPasswordView: View {
    @ObservedObject var viewModel: AuthenticationViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isEmailFocused: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Reset Password")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.top)
                    
                    Text("Enter your email address and we'll send you a link to reset your password.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Email")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("Enter your email", text: $viewModel.resetPasswordEmail)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .textContentType(.emailAddress)
                            .focused($isEmailFocused)
                            .onSubmit {
                                Task {
                                    await viewModel.resetPassword()
                                }
                            }
                    }
                    .padding(.horizontal)
                    
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    Button(action: {
                        isEmailFocused = false
                        Task {
                            await viewModel.resetPassword()
                        }
                    }) {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            
                            Text("Send Reset Email")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.resetPasswordEmail.isEmpty || viewModel.isLoading ? Color.gray.opacity(0.3) : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(viewModel.resetPasswordEmail.isEmpty || viewModel.isLoading)
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            isEmailFocused = true
        }
    }
}

#Preview {
    AuthenticationView()
}

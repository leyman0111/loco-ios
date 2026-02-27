//
//  LoginView.swift
//  loco-ios
//
//  Login screen with OAuth integration
//

import SwiftUI

struct LoginView: View {
    
    @StateObject private var viewModel = AuthViewModel()
    @State private var email = ""
    @State private var password = ""
    
    var body: some View {
        ZStack {
            // Background with decorative shapes
            backgroundShapes
            
            VStack(spacing: LocoTheme.Spacing.lg) {
                
                Spacer()
                
                // Logo
                logoView
                
                Spacer()
                
                // Input fields
                VStack(spacing: LocoTheme.Spacing.md) {
                    inputField(placeholder: "Email or Username", text: $email)
                    inputField(placeholder: "Password", text: $password, isSecure: true)
                }
                .padding(.horizontal, LocoTheme.Spacing.lg)
                
                // Login button
                Button(action: {
                    viewModel.login(email: email, password: password)
                }) {
                    Text("Login")
                        .font(LocoTheme.Typography.button())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(LocoTheme.Colors.buttonPrimary)
                        .cornerRadius(LocoTheme.Radius.button)
                }
                .padding(.horizontal, LocoTheme.Spacing.lg)
                .padding(.top, LocoTheme.Spacing.sm)
                
                // Sign up link
                HStack(spacing: 4) {
                    Text("Don't have an account?")
                        .font(LocoTheme.Typography.body(15))
                        .foregroundColor(LocoTheme.Colors.textPrimary)
                    
                    Button(action: {}) {
                        Text("Sign up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(LocoTheme.Colors.textPrimary)
                    }
                }
                .padding(.top, LocoTheme.Spacing.sm)
                
                // Divider with text
                HStack(spacing: LocoTheme.Spacing.md) {
                    Rectangle()
                        .fill(LocoTheme.Colors.textSecondary.opacity(0.3))
                        .frame(height: 1)
                    
                    Text("Or continue with")
                        .font(LocoTheme.Typography.body(15))
                        .foregroundColor(LocoTheme.Colors.textPrimary)
                    
                    Rectangle()
                        .fill(LocoTheme.Colors.textSecondary.opacity(0.3))
                        .frame(height: 1)
                }
                .padding(.horizontal, LocoTheme.Spacing.xl)
                .padding(.top, LocoTheme.Spacing.md)
                
                // OAuth buttons
                HStack(spacing: LocoTheme.Spacing.lg) {
                    // Google
                    oauthButton(bgColor: .white, action: viewModel.loginWithGoogle) {
                        Text("G")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.red, .blue, .green, .yellow],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    // Yandex
                    oauthButton(bgColor: Color(hex: "FFCC00"), action: viewModel.loginWithYandex) {
                        Text("Я")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.red)
                    }
                    
                    // VK
                    oauthButton(bgColor: Color(hex: "4680C2"), action: viewModel.loginWithVK) {
                        Text("ВК")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.top, LocoTheme.Spacing.md)
                
                Spacer()
            }
        }
        .alert(isPresented: $viewModel.showAlert) {
            Alert(
                title: Text("Уведомление"),
                message: Text(viewModel.alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .fullScreenCover(isPresented: $viewModel.isAuthenticated) {
            MapScreenView()
        }
    }
    
    // MARK: - Background Shapes
    
    private var backgroundShapes: some View {
        ZStack {
            LocoTheme.Colors.cream
                .ignoresSafeArea()
            
            // Blue circle top-left
            Circle()
                .fill(LocoTheme.Colors.softBlue)
                .frame(width: 280, height: 280)
                .offset(x: -100, y: -300)
            
            // Golden circle bottom-right
            Circle()
                .fill(LocoTheme.Colors.goldenSand)
                .frame(width: 320, height: 320)
                .offset(x: 150, y: 300)
            
            // Blue circle bottom-left
            Circle()
                .fill(LocoTheme.Colors.softBlue.opacity(0.6))
                .frame(width: 200, height: 200)
                .offset(x: -120, y: 420)
        }
    }
    
    // MARK: - Logo View
    
    private var logoView: some View {
        LocoLogoView(fontSize: 56)
    }
    
    // MARK: - Input Field
    
    private func inputField(placeholder: String, text: Binding<String>, isSecure: Bool = false) -> some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } else {
                TextField(placeholder, text: text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
        .font(LocoTheme.Typography.body())
        .padding(.horizontal, LocoTheme.Spacing.lg)
        .padding(.vertical, LocoTheme.Spacing.md)
        .background(LocoTheme.Colors.inputBackground)
        .cornerRadius(LocoTheme.Radius.input)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - OAuth Button
    
    private func oauthButton<Content: View>(bgColor: Color, action: @escaping () -> Void, @ViewBuilder label: () -> Content) -> some View {
        Button(action: action) {
            label()
                .frame(width: 70, height: 70)
                .background(bgColor)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
    }
}

#Preview {
    LoginView()
}

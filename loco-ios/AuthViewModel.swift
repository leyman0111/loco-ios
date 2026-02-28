//
//  AuthViewModel.swift
//  loco-ios
//
//  Authentication flow:
//  1. YandexOAuthService opens browser → user logs in → returns authorization code
//  2. Code is sent to backend: GET /auth/yandex?authCode={code}
//  3. Backend exchanges code for Yandex token (server-to-server),
//     creates/finds user, returns own JWT
//  4. JWT is stored and used for all subsequent API requests
//

import Foundation
import SwiftUI

@MainActor
class AuthViewModel: ObservableObject {
    
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var showAlert = false
    @Published var alertMessage = ""
    
    private let yandexOAuth = YandexOAuthService()
    
    // MARK: - Login with Yandex
    
    func loginWithYandex() {
        yandexOAuth.authenticate { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let authCode):
                    // Got authorization code — now exchange it for backend JWT
                    Task {
                        await self?.exchangeYandexCode(authCode)
                    }
                case .failure(let error):
                    self?.alertMessage = "Ошибка авторизации: \(error.localizedDescription)"
                    self?.showAlert = true
                }
            }
        }
    }
    
    // MARK: - Exchange Yandex code for backend JWT
    
    private func exchangeYandexCode(_ code: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let jwt = try await APIService.shared.loginWithYandex(authCode: code)
            APIService.shared.authToken = jwt
            isAuthenticated = true
        } catch {
            alertMessage = "Ошибка получения токена: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    // MARK: - Login with Google (Coming Soon)
    
    func loginWithGoogle() {
        alertMessage = "Этот функционал в стадии разработки. Подождите немного, пожалуйста))"
        showAlert = true
    }
    
    // MARK: - Login with VK (Coming Soon)
    
    func loginWithVK() {
        alertMessage = "Этот функционал в стадии разработки. Подождите немного, пожалуйста))"
        showAlert = true
    }
    
    // MARK: - Login with Email (Coming Soon)
    
    func login(email: String, password: String) {
        alertMessage = "Email авторизация в разработке"
        showAlert = true
    }
}

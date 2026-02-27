//
//  AuthViewModel.swift
//  loco-ios
//
//  ViewModel for authentication logic
//

import Foundation
import SwiftUI

@MainActor
class AuthViewModel: ObservableObject {
    
    @Published var isAuthenticated = false
    @Published var accessToken: String?
    @Published var errorMessage: String?
    @Published var showAlert = false
    @Published var alertMessage = ""
    
    private let yandexOAuth = YandexOAuthService()
    
    // MARK: - Login with Yandex
    
    func loginWithYandex() {
        yandexOAuth.authenticate { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let token):
                    self?.accessToken = token
                    APIService.shared.authToken = token
                    self?.isAuthenticated = true
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    self?.alertMessage = "Ошибка авторизации: \(error.localizedDescription)"
                    self?.showAlert = true
                }
            }
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
    
    // MARK: - Login with Email
    
    func login(email: String, password: String) {
        // TODO: Implement email/password login with backend API
        alertMessage = "Email авторизация в разработке"
        showAlert = true
    }
}

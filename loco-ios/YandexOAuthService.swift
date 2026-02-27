//
//  YandexOAuthService.swift
//  loco-ios
//
//  Service for Yandex OAuth authentication
//

import Foundation
import AuthenticationServices

class YandexOAuthService: NSObject, ObservableObject {
    
    // MARK: - Configuration
    
    private let clientId = "YOUR_YANDEX_CLIENT_ID" // Замените на ваш Client ID
    private let redirectUri = "loco://oauth/yandex"
    private let authURL = "https://oauth.yandex.ru/authorize"
    
    // MARK: - Completion Handler
    
    private var completionHandler: ((Result<String, Error>) -> Void)?
    
    // MARK: - Authenticate
    
    func authenticate(completion: @escaping (Result<String, Error>) -> Void) {
        self.completionHandler = completion
        
        // Build authorization URL
        var components = URLComponents(string: authURL)
        components?.queryItems = [
            URLQueryItem(name: "response_type", value: "token"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "force_confirm", value: "yes")
        ]
        
        guard let url = components?.url else {
            completion(.failure(NSError(domain: "YandexOAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        // Start authentication session
        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "loco") { [weak self] callbackURL, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let callbackURL = callbackURL else {
                completion(.failure(NSError(domain: "YandexOAuth", code: -2, userInfo: [NSLocalizedDescriptionKey: "No callback URL"])))
                return
            }
            
            // Extract access token from fragment
            if let fragment = callbackURL.fragment,
               let token = self?.extractToken(from: fragment) {
                completion(.success(token))
            } else {
                completion(.failure(NSError(domain: "YandexOAuth", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to extract token"])))
            }
        }
        
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        session.start()
    }
    
    // MARK: - Extract Token
    
    private func extractToken(from fragment: String) -> String? {
        let components = fragment.components(separatedBy: "&")
        for component in components {
            let pair = component.components(separatedBy: "=")
            if pair.count == 2, pair[0] == "access_token" {
                return pair[1]
            }
        }
        return nil
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension YandexOAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
}

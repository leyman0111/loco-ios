//
//  YandexOAuthService.swift
//  loco-ios
//
//  Yandex OAuth 2.0 Authorization Code Flow:
//  1. Open browser → Yandex authorize (response_type=code)
//  2. Yandex redirects to loco://oauth/yandex?code=XXXX
//  3. Extract authorization code from callback URL query params
//  4. Send code to backend: GET /auth/yandex?authCode={code}
//  5. Backend exchanges code for Yandex token server-to-server,
//     creates/finds user, returns own JWT
//  6. Store JWT and use for all subsequent API requests
//

import Foundation
import AuthenticationServices

class YandexOAuthService: NSObject, ObservableObject {
    
    // MARK: - Configuration
    
    private let clientId = "00770f54e5694f6287ed2ee95349a837"
    private let redirectUri = "loco://oauth/yandex"
    private let authURL = "https://oauth.yandex.ru/authorize"
    
    // MARK: - Authenticate
    // Returns authorization code (not token) to be exchanged by backend
    
    func authenticate(completion: @escaping (Result<String, Error>) -> Void) {
        
        // Build authorization URL with response_type=code
        var components = URLComponents(string: authURL)
        components?.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "force_confirm", value: "yes")
        ]
        
        guard let url = components?.url else {
            completion(.failure(OAuthError.invalidURL))
            return
        }
        
        // Open Yandex login in browser
        let session = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: "loco"
        ) { [weak self] callbackURL, error in
            
            if let error = error {
                // User cancelled or other error
                completion(.failure(error))
                return
            }
            
            guard let callbackURL = callbackURL else {
                completion(.failure(OAuthError.noCallbackURL))
                return
            }
            
            // Extract authorization code from query params
            // Yandex redirects to: loco://oauth/yandex?code=XXXX
            guard let code = self?.extractCode(from: callbackURL) else {
                completion(.failure(OAuthError.noAuthorizationCode))
                return
            }
            
            completion(.success(code))
        }
        
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        session.start()
    }
    
    // MARK: - Extract Authorization Code from callback URL
    
    private func extractCode(from url: URL) -> String? {
        // Yandex returns code in query parameters: ?code=XXXX
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }
        return queryItems.first(where: { $0.name == "code" })?.value
    }
}

// MARK: - OAuth Errors

enum OAuthError: LocalizedError {
    case invalidURL
    case noCallbackURL
    case noAuthorizationCode
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Некорректный URL авторизации"
        case .noCallbackURL: return "Не получен ответ от сервера авторизации"
        case .noAuthorizationCode: return "Код авторизации не найден в ответе"
        }
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension YandexOAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
}

//
//  APIService.swift
//  loco-ios
//
//  Network layer for Loco backend API
//

import Foundation

// MARK: - API Configuration

enum APIConfig {
    static let baseURL = "http://194.67.202.103:8080"
    
    enum Map {
        static let defaultLatitude: Double = 55.7558
        static let defaultLongitude: Double = 37.6173
        static let defaultRadiusMeters: Int = 1000 // 1 km
    }
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case serverError(Int)
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .noData: return "No data received"
        case .decodingError(let e): return "Decoding error: \(e.localizedDescription)"
        case .serverError(let code): return "Server error: \(code)"
        case .unauthorized: return "Unauthorized. Please log in again."
        }
    }
}

// MARK: - API Service

class APIService {
    
    static let shared = APIService()
    private init() {}
    
    // Token storage (in-memory for now)
    var authToken: String?
    
    // MARK: - Generic Request
    
    private func request<T: Decodable>(
        path: String,
        method: String = "GET",
        body: Encodable? = nil
    ) async throws -> T {
        guard let url = URL(string: APIConfig.baseURL + path) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.noData
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
    
    // MARK: - Posts
    
    /// POST /posts/scope — get post markers in area
    func getPostMarks(scope: Scope) async throws -> [PostMark] {
        return try await request(path: "/posts/scope", method: "POST", body: scope)
    }
    
    /// GET /posts/previews/{id} — get post preview for bottom sheet
    func getPostPreview(id: Int64) async throws -> PostPreview {
        return try await request(path: "/posts/previews/\(id)")
    }
    
    // MARK: - Content
    
    /// Returns URL for downloading content by ID
    func contentURL(id: Int64) -> URL? {
        return URL(string: APIConfig.baseURL + "/contents/\(id)")
    }
}

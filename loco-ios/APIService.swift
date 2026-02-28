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
    
    // MARK: - Generic Request (returns Decodable)
    
    private func request<T: Decodable>(
        path: String,
        method: String = "GET",
        body: Encodable? = nil
    ) async throws -> T {
        guard let url = URL(string: APIConfig.baseURL + path) else {
            throw APIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = authToken {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            urlRequest.httpBody = try JSONEncoder().encode(body)
        }
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
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
    
    // MARK: - Generic Void Request (no response body expected)
    
    private func voidRequest(
        path: String,
        method: String = "DELETE",
        body: Encodable? = nil
    ) async throws {
        guard let url = URL(string: APIConfig.baseURL + path) else {
            throw APIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = authToken {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            urlRequest.httpBody = try JSONEncoder().encode(body)
        }
        
        let (_, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.noData
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
    
    // MARK: - Auth
    
    /// GET /auth/yandex?authCode={code}
    /// Backend exchanges Yandex authorization code for its own JWT token
    /// Returns the JWT string to be used as Bearer token in subsequent requests
    func loginWithYandex(authCode: String) async throws -> String {
        guard var components = URLComponents(string: APIConfig.baseURL + "/auth/yandex") else {
            throw APIError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "authCode", value: authCode)]
        
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.noData
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            // Backend returns JWT as plain string or wrapped in JSON
            // Try plain string first, then try JSON {"token": "..."}
            if let jwt = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !jwt.isEmpty {
                // Remove surrounding quotes if backend returns quoted string
                return jwt.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
            throw APIError.noData
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
    
    /// POST /posts — create draft post (called when CreatePostView opens)
    func createDraftPost() async throws -> PostDto {
        return try await request(path: "/posts", method: "POST")
    }
    
    /// PUT /posts — save changes and publish post (PUBLISHED status)
    func publishPost(postDto: PostDto) async throws -> PostDto {
        return try await request(path: "/posts", method: "PUT", body: postDto)
    }
    
    // MARK: - Content
    
    /// GET /contents/{id}?size=MEDIUM — download content image data
    func getContentData(id: Int64, size: String = "MEDIUM") async throws -> Data {
        guard let url = URL(string: APIConfig.baseURL + "/contents/\(id)?size=\(size)") else {
            throw APIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        
        if let token = authToken {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        
        return data
    }
    
    /// Returns URL for downloading content by ID (for AsyncImage)
    func contentURL(id: Int64, size: String = "MEDIUM") -> URL? {
        return URL(string: APIConfig.baseURL + "/contents/\(id)?size=\(size)")
    }
    
    /// DELETE /contents/{id} — delete content item
    func deleteContent(id: Int64) async throws {
        try await voidRequest(path: "/contents/\(id)", method: "DELETE")
    }
    
    /// POST /contents?postId=&type= — upload image for a post
    func uploadContent(postId: Int64, imageData: Data, type: String = "IMAGE") async throws {
        guard let url = URL(string: APIConfig.baseURL + "/contents?postId=\(postId)&type=\(type)") else {
            throw APIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        
        if let token = authToken {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let boundary = UUID().uuidString
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        urlRequest.httpBody = body
        
        let (_, response) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }
}

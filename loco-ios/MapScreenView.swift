//
//  MapScreenView.swift
//  loco-ios
//
//  Main map screen with category filters and post markers
//

import SwiftUI
import MapKit

// MARK: - Map Annotation Item

struct PostAnnotation: Identifiable {
    let id: Int64
    let coordinate: CLLocationCoordinate2D
}

// MARK: - MapScreenViewModel

@MainActor
class MapScreenViewModel: ObservableObject {
    
    @Published var annotations: [PostAnnotation] = []
    @Published var selectedPreview: PostPreview?
    @Published var selectedPostId: Int64?
    @Published var isLoadingPreview = false
    @Published var errorMessage: String?
    @Published var activeCategories: Set<PostCategory> = Set(PostCategory.allCases)
    
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(
            latitude: APIConfig.Map.defaultLatitude,
            longitude: APIConfig.Map.defaultLongitude
        ),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    private let api = APIService.shared
    
    // MARK: - Load Markers
    
    func loadMarkers() async {
        let scope = Scope(
            latitude: Float(region.center.latitude),
            longitude: Float(region.center.longitude),
            distance: APIConfig.Map.defaultRadiusMeters,
            categories: activeCategories.isEmpty ? nil : activeCategories.map { $0.rawValue }
        )
        
        do {
            let marks = try await api.getPostMarks(scope: scope)
            annotations = marks.compactMap { mark in
                guard let id = mark.id,
                      let lat = mark.latitude,
                      let lng = mark.longitude else { return nil }
                return PostAnnotation(
                    id: id,
                    coordinate: CLLocationCoordinate2D(latitude: Double(lat), longitude: Double(lng))
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Load Post Preview
    
    func loadPreview(for postId: Int64) async {
        selectedPostId = postId
        isLoadingPreview = true
        selectedPreview = nil
        
        do {
            let preview = try await api.getPostPreview(id: postId)
            selectedPreview = preview
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoadingPreview = false
    }
    
    // MARK: - Toggle Category
    
    func toggleCategory(_ category: PostCategory) {
        if activeCategories.contains(category) {
            activeCategories.remove(category)
        } else {
            activeCategories.insert(category)
        }
        Task { await loadMarkers() }
    }
    
    // MARK: - Dismiss Preview
    
    func dismissPreview() {
        selectedPreview = nil
        selectedPostId = nil
    }
}

// MARK: - MapScreenView

struct MapScreenView: View {
    
    @StateObject private var viewModel = MapScreenViewModel()
    
    var body: some View {
        ZStack(alignment: .bottom) {
            
            // Map
            Map(coordinateRegion: $viewModel.region,
                annotationItems: viewModel.annotations) { annotation in
                MapAnnotation(coordinate: annotation.coordinate) {
                    MapPinView()
                        .onTapGesture {
                            Task { await viewModel.loadPreview(for: annotation.id) }
                        }
                }
            }
            .ignoresSafeArea()
            
            // Top overlay: Logo + Category filters
            VStack(spacing: 0) {
                topBar
                categoryFilters
                Spacer()
            }
            
            // FAB: Create post button
            HStack {
                Spacer()
                createButton
            }
            .padding(.trailing, 20)
            .padding(.bottom, viewModel.selectedPreview != nil || viewModel.isLoadingPreview ? 200 : 40)
            
            // Bottom sheet: Post preview
            if viewModel.isLoadingPreview {
                loadingBottomSheet
            } else if let preview = viewModel.selectedPreview {
                PostPreviewSheet(preview: preview, onDismiss: viewModel.dismissPreview)
                    .transition(.move(edge: .bottom))
            }
        }
        .animation(.spring(response: 0.4), value: viewModel.selectedPreview != nil)
        .task {
            await viewModel.loadMarkers()
        }
    }
    
    // MARK: - Top Bar (Logo)
    
    private var topBar: some View {
        HStack {
            Spacer()
            // Logo
            HStack(spacing: 0) {
                Text("Loc")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(LocoTheme.Colors.navy)
                
                ZStack {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(LocoTheme.Colors.navy)
                    
                    Circle()
                        .fill(LocoTheme.Colors.coral)
                        .frame(width: 8, height: 8)
                        .offset(y: -2)
                }
                .frame(width: 26, height: 28)
            }
            Spacer()
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
    
    // MARK: - Category Filters
    
    private var categoryFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PostCategory.allCases, id: \.rawValue) { category in
                    CategoryPill(
                        category: category,
                        isActive: viewModel.activeCategories.contains(category)
                    ) {
                        viewModel.toggleCategory(category)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Create Button (FAB)
    
    private var createButton: some View {
        Button(action: {
            // TODO: Navigate to create post
        }) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(LocoTheme.Colors.coral)
                .clipShape(Circle())
                .shadow(color: LocoTheme.Colors.coral.opacity(0.4), radius: 12, x: 0, y: 6)
        }
    }
    
    // MARK: - Loading Bottom Sheet
    
    private var loadingBottomSheet: some View {
        VStack {
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 12)
            
            ProgressView()
                .padding(.vertical, 24)
        }
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(20, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: -4)
    }
}

// MARK: - Category Pill

struct CategoryPill: View {
    let category: PostCategory
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(category.emoji)
                    .font(.system(size: 13))
                Text(category.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isActive ? LocoTheme.Colors.textPrimary : LocoTheme.Colors.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                isActive
                    ? Color(hex: category.color).opacity(0.35)
                    : Color.white.opacity(0.85)
            )
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isActive ? Color(hex: category.color) : Color.gray.opacity(0.2),
                        lineWidth: 1
                    )
            )
        }
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Map Pin View

struct MapPinView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(LocoTheme.Colors.coral)
                .frame(width: 16, height: 16)
                .shadow(color: LocoTheme.Colors.coral.opacity(0.5), radius: 4, x: 0, y: 2)
            
            Circle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: 16, height: 16)
        }
    }
}

// MARK: - Post Preview Sheet

struct PostPreviewSheet: View {
    let preview: PostPreview
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Handle
            HStack {
                Spacer()
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 4)
                Spacer()
            }
            .padding(.top, 12)
            .padding(.bottom, 16)
            
            HStack(alignment: .top, spacing: 12) {
                // Thumbnail (first content image)
                if let contentId = preview.contents?.first,
                   let url = APIService.shared.contentURL(id: contentId) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Color(hex: "F0F0F0")
                    }
                    .frame(width: 80, height: 80)
                    .cornerRadius(12)
                    .clipped()
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    // Post text
                    if let text = preview.text {
                        Text(text)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(LocoTheme.Colors.textPrimary)
                            .lineLimit(3)
                    }
                    
                    // Reactions
                    if let reactions = preview.reactions, !reactions.isEmpty {
                        let grouped = Dictionary(grouping: reactions) { $0.type }
                        HStack(spacing: 6) {
                            ForEach(ReactionType.allCases, id: \.rawValue) { type in
                                if let count = grouped[type]?.count, count > 0 {
                                    Text("\(type.emoji) \(count)")
                                        .font(.system(size: 14))
                                }
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(20, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: -4)
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height > 50 {
                        onDismiss()
                    }
                }
        )
    }
}

// MARK: - Corner Radius Helper

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    MapScreenView()
}

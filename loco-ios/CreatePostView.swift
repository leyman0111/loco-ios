//
//  CreatePostView.swift
//  loco-ios
//
//  Create Post screen with correct flow:
//  1. On open: POST /posts → get draft (may already have contents)
//  2. If draft has contents: GET /contents/{id} for each → display them
//  3. User can delete content: DELETE /contents/{id}
//  4. User can add new content: POST /contents
//  5. On Publish: PUT /posts → saves changes, sets status PUBLISHED
//

import SwiftUI
import MapKit

// MARK: - ContentItem (loaded content for display)

struct ContentItem: Identifiable {
    let id: Int64
    var imageData: Data?
    var uiImage: UIImage? {
        guard let data = imageData else { return nil }
        return UIImage(data: data)
    }
}

// MARK: - CreatePostViewModel

@MainActor
class CreatePostViewModel: ObservableObject {
    
    let maxCharacters = 130
    
    // Draft post returned from POST /posts
    @Published var draftPost: PostDto?
    
    // Content items loaded from server
    @Published var contentItems: [ContentItem] = []
    
    // Newly picked images (not yet uploaded)
    @Published var pendingImages: [UIImage] = []
    
    @Published var text = ""
    @Published var selectedCategory: PostCategory?
    
    @Published var isLoading = false
    @Published var isPublishing = false
    @Published var showAlert = false
    @Published var alertMessage = ""
    @Published var publishedSuccessfully = false
    
    @Published var showExpandedMap = false
    
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(
            latitude: APIConfig.Map.defaultLatitude,
            longitude: APIConfig.Map.defaultLongitude
        ),
        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    )
    
    var latitude: Float { Float(region.center.latitude) }
    var longitude: Float { Float(region.center.longitude) }
    
    var characterCount: Int { text.count }
    
    var isValid: Bool {
        !text.trimmingCharacters(in: .whitespaces).isEmpty &&
        text.count <= maxCharacters &&
        selectedCategory != nil
    }
    
    private let api = APIService.shared
    
    // MARK: - Step 1: Create draft on open
    
    func createDraft() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let draft = try await api.createDraftPost()
            draftPost = draft
            
            // Pre-fill text and category if draft already has them
            if let existingText = draft.text { text = existingText }
            if let cat = draft.category,
               let category = PostCategory(rawValue: cat) {
                selectedCategory = category
            }
            
            // Step 2: Load existing content if any
            if let contentIds = draft.contents, !contentIds.isEmpty {
                await loadExistingContent(ids: contentIds)
            }
        } catch {
            alertMessage = "Не удалось создать черновик: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    // MARK: - Step 2: Load existing content images
    
    private func loadExistingContent(ids: [Int64]) async {
        await withTaskGroup(of: ContentItem?.self) { group in
            for id in ids {
                group.addTask {
                    do {
                        let data = try await APIService.shared.getContentData(id: id, size: "MEDIUM")
                        return ContentItem(id: id, imageData: data)
                    } catch {
                        return ContentItem(id: id, imageData: nil)
                    }
                }
            }
            for await item in group {
                if let item = item {
                    contentItems.append(item)
                }
            }
        }
    }
    
    // MARK: - Delete existing content
    
    func deleteContent(item: ContentItem) async {
        do {
            try await api.deleteContent(id: item.id)
            contentItems.removeAll { $0.id == item.id }
        } catch {
            alertMessage = "Не удалось удалить контент: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    // MARK: - Remove pending image (not yet uploaded)
    
    func removePendingImage(at index: Int) {
        guard index < pendingImages.count else { return }
        pendingImages.remove(at: index)
    }
    
    // MARK: - Step 3: Publish
    
    func publish() async {
        guard isValid, let draft = draftPost, let postId = draft.id else {
            alertMessage = "Заполните текст и выберите категорию"
            showAlert = true
            return
        }
        
        isPublishing = true
        defer { isPublishing = false }
        
        do {
            // Upload any pending images first
            for image in pendingImages {
                if let data = image.jpegData(compressionQuality: 0.8) {
                    try await api.uploadContent(postId: postId, imageData: data, type: "IMAGE")
                }
            }
            
            // Build updated PostDto and PUT to publish
            let postDto = PostDto(
                id: postId,
                author: draft.author,
                created: draft.created,
                text: text,
                category: selectedCategory?.rawValue,
                contents: nil, // server manages content list
                latitude: latitude,
                longitude: longitude
            )
            _ = try await api.publishPost(postDto: postDto)
            
            publishedSuccessfully = true
            
        } catch {
            alertMessage = "Ошибка публикации: \(error.localizedDescription)"
            showAlert = true
        }
    }
}

// MARK: - CreatePostView

struct CreatePostView: View {
    
    @Binding var isPresented: Bool
    @StateObject private var viewModel = CreatePostViewModel()
    @State private var showImagePicker = false
    @State private var imagePickerSource: UIImagePickerController.SourceType = .photoLibrary
    
    var body: some View {
        ZStack {
            backgroundShapes
            
            if viewModel.isLoading {
                // Loading state while creating draft
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.4)
                    Text("Подготовка...")
                        .font(.system(size: 15))
                        .foregroundColor(LocoTheme.Colors.textSecondary)
                }
            } else {
                VStack(spacing: 0) {
                    navBar
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            textArea
                            mediaSection
                            categorySection
                            locationSection
                            Spacer(minLength: 100)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    }
                    
                    publishButton
                }
            }
        }
        .task {
            await viewModel.createDraft()
        }
        .alert(isPresented: $viewModel.showAlert) {
            Alert(
                title: Text("Уведомление"),
                message: Text(viewModel.alertMessage),
                dismissButton: .default(Text("OK")) {
                    if viewModel.publishedSuccessfully {
                        isPresented = false
                    }
                }
            )
        }
        .onChange(of: viewModel.publishedSuccessfully) { success in
            if success { isPresented = false }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePickerView(sourceType: imagePickerSource) { image in
                viewModel.pendingImages.append(image)
            }
        }
        .fullScreenCover(isPresented: $viewModel.showExpandedMap) {
            ExpandedMapView(region: $viewModel.region, isPresented: $viewModel.showExpandedMap)
        }
    }
    
    // MARK: - Background Shapes
    
    private var backgroundShapes: some View {
        ZStack {
            LocoTheme.Colors.cream.ignoresSafeArea()
            Circle()
                .fill(LocoTheme.Colors.softBlue)
                .frame(width: 240, height: 240)
                .offset(x: -100, y: -320)
            Circle()
                .fill(LocoTheme.Colors.goldenSand)
                .frame(width: 300, height: 300)
                .offset(x: 140, y: 100)
            Circle()
                .fill(LocoTheme.Colors.softBlue.opacity(0.5))
                .frame(width: 180, height: 180)
                .offset(x: -110, y: 460)
        }
    }
    
    // MARK: - Navigation Bar
    
    private var navBar: some View {
        HStack {
            Button(action: { isPresented = false }) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(LocoTheme.Colors.navy)
            }
            Spacer()
            Text("Create Post")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(LocoTheme.Colors.navy)
            Spacer()
            LocoLogoView(fontSize: 22)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
    
    // MARK: - Text Area
    
    private var textArea: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack(alignment: .topLeading) {
                if viewModel.text.isEmpty {
                    Text("What's happening here?")
                        .font(.system(size: 16))
                        .foregroundColor(LocoTheme.Colors.textSecondary)
                        .padding(.top, 14)
                        .padding(.leading, 16)
                }
                TextEditor(text: $viewModel.text)
                    .font(.system(size: 16))
                    .foregroundColor(LocoTheme.Colors.textPrimary)
                    .frame(minHeight: 130)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .onChange(of: viewModel.text) { newValue in
                        if newValue.count > viewModel.maxCharacters {
                            viewModel.text = String(newValue.prefix(viewModel.maxCharacters))
                        }
                    }
            }
            Text("\(viewModel.characterCount)/\(viewModel.maxCharacters)")
                .font(.system(size: 13))
                .foregroundColor(viewModel.characterCount >= viewModel.maxCharacters
                    ? .red : LocoTheme.Colors.textSecondary)
                .padding(.trailing, 14)
                .padding(.bottom, 10)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - Media Section (existing + pending images + add buttons)
    
    private var mediaSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Camera button
                Button(action: {
                    imagePickerSource = .camera
                    showImagePicker = true
                }) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 22))
                        .foregroundColor(LocoTheme.Colors.navy)
                        .frame(width: 56, height: 56)
                        .background(LocoTheme.Colors.goldenSand)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
                }
                
                // Gallery button
                Button(action: {
                    imagePickerSource = .photoLibrary
                    showImagePicker = true
                }) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 22))
                        .foregroundColor(LocoTheme.Colors.navy)
                        .frame(width: 56, height: 56)
                        .background(LocoTheme.Colors.goldenSand)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
                }
                
                // Existing content from server (with delete)
                ForEach(viewModel.contentItems) { item in
                    ZStack(alignment: .topTrailing) {
                        if let uiImage = item.uiImage {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        } else {
                            // Placeholder while loading or if failed
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 56, height: 56)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                )
                        }
                        
                        // Delete button
                        Button(action: {
                            Task { await viewModel.deleteContent(item: item) }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(LocoTheme.Colors.coral)
                                .background(Color.white)
                                .clipShape(Circle())
                        }
                        .offset(x: 6, y: -6)
                    }
                }
                
                // Pending images (not yet uploaded, with remove)
                ForEach(viewModel.pendingImages.indices, id: \.self) { index in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: viewModel.pendingImages[index])
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        
                        Button(action: { viewModel.removePendingImage(at: index) }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(LocoTheme.Colors.coral)
                                .background(Color.white)
                                .clipShape(Circle())
                        }
                        .offset(x: 6, y: -6)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Category Section
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Category")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(LocoTheme.Colors.navy)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PostCategory.allCases, id: \.rawValue) { category in
                        CategoryPill(
                            category: category,
                            isActive: viewModel.selectedCategory == category
                        ) {
                            viewModel.selectedCategory = viewModel.selectedCategory == category ? nil : category
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    // MARK: - Location Section
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Location")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(LocoTheme.Colors.navy)
            
            ZStack {
                Map(coordinateRegion: $viewModel.region,
                    interactionModes: [],
                    annotationItems: [MapPin(coordinate: viewModel.region.center)]) { pin in
                    MapAnnotation(coordinate: pin.coordinate) {
                        Image(systemName: "mappin.fill")
                            .font(.system(size: 28))
                            .foregroundColor(LocoTheme.Colors.navy)
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                }
                .frame(height: 180)
                .cornerRadius(16)
                .allowsHitTesting(false)
                
                Button(action: { viewModel.showExpandedMap = true }) {
                    Text("Expand Map")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(LocoTheme.Colors.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.92))
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 2)
                }
                .offset(y: 60)
            }
            .frame(height: 200)
        }
    }
    
    // MARK: - Publish Button
    
    private var publishButton: some View {
        Button(action: {
            Task { await viewModel.publish() }
        }) {
            ZStack {
                if viewModel.isPublishing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Publish")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(viewModel.isValid
                ? LocoTheme.Colors.buttonPrimary
                : LocoTheme.Colors.buttonPrimary.opacity(0.5))
            .cornerRadius(28)
        }
        .disabled(!viewModel.isValid || viewModel.isPublishing)
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
        .padding(.top, 12)
        .background(
            LocoTheme.Colors.cream
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: -4)
        )
    }
}

// MARK: - Helper: Map Pin for annotation

struct MapPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Expanded Map View

struct ExpandedMapView: View {
    @Binding var region: MKCoordinateRegion
    @Binding var isPresented: Bool
    @State private var pinCoordinate: CLLocationCoordinate2D
    
    init(region: Binding<MKCoordinateRegion>, isPresented: Binding<Bool>) {
        self._region = region
        self._isPresented = isPresented
        self._pinCoordinate = State(initialValue: region.wrappedValue.center)
    }
    
    var body: some View {
        ZStack {
            Map(coordinateRegion: $region,
                annotationItems: [MapPin(coordinate: pinCoordinate)]) { pin in
                MapAnnotation(coordinate: pin.coordinate) {
                    Image(systemName: "mappin.fill")
                        .font(.system(size: 32))
                        .foregroundColor(LocoTheme.Colors.navy)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                }
            }
            .ignoresSafeArea()
            .onChange(of: region.center.latitude) { _ in
                pinCoordinate = region.center
            }
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        pinCoordinate = region.center
                        isPresented = false
                    }) {
                        Text("Готово")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(LocoTheme.Colors.coral)
                            .cornerRadius(20)
                            .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 60)
                }
                Spacer()
                
                Text("Переместите карту, чтобы выбрать место")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(12)
                    .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Image Picker

struct ImagePickerView: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage) -> Void
    
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView
        init(_ parent: ImagePickerView) { self.parent = parent }
        
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

#Preview {
    CreatePostView(isPresented: .constant(true))
}

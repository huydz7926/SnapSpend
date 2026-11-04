import SwiftUI
import PhotosUI

// MARK: - UserAvatarView (Thành phần Avatar Tròn Thông Minh SnapSpend)

struct UserAvatarView: View {

    var size: CGFloat = 44
    var showActions: Bool = true
    var showCameraBadge: Bool = false

    @ObservedObject private var avatarService = ProfileAvatarService.shared
    private let authService = AuthService.shared
    private let theme = ThemeManager.shared
    private let locManager = LocalizationManager.shared

    // Sheets & Dialogs
    @State private var showActionDialog = false
    @State private var showPhotosPicker = false
    @State private var selectedPickerItem: PhotosPickerItem? = nil
    @State private var pickedImageForCrop: UIImage? = nil
    @State private var showCropSheet = false
    @State private var showImageViewer = false

    private var isVN: Bool {
        locManager.currentLanguage == .vietnamese
    }

    private var effectiveUserName: String {
        if let name = authService.currentUser?.displayName, !name.isEmpty {
            return name
        }
        return isVN ? "Bạn" : "You"
    }

    private var initialLetter: String {
        guard let first = effectiveUserName.trimmingCharacters(in: .whitespaces).first else {
            return "S"
        }
        return String(first).uppercased()
    }

    var body: some View {
        Button {
            guard showActions else { return }
            HapticManager.shared.selectionChanged()
            showActionDialog = true
        } label: {
            ZStack(alignment: .bottomTrailing) {
                // Avatar chính
                if let avatar = avatarService.currentAvatarImage {
                    Image(uiImage: avatar)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                        .overlay {
                            Circle()
                                .stroke(theme.primaryAction.opacity(0.35), lineWidth: 1.5)
                        }
                        .shadow(color: Color.black.opacity(0.06), radius: 4, y: 2)
                } else {
                    // Placeholder Initials trên nền Pastel tinh tế
                    ZStack {
                        Circle()
                            .fill(
                                theme.isDarkModeEffective
                                    ? Color(hex: "#3D2635") ?? Color.purple.opacity(0.3)
                                    : Color(hex: "#FCE4EC") ?? Color.pink.opacity(0.18)
                            )
                            .frame(width: size, height: size)
                            .overlay {
                                Circle()
                                    .stroke(
                                        theme.isDarkModeEffective
                                            ? Color(hex: "#880E4F") ?? Color.purple.opacity(0.4)
                                            : Color(hex: "#F8BBD0") ?? Color.pink.opacity(0.45),
                                        lineWidth: 1.5
                                    )
                            }

                        Text(initialLetter)
                            .font(.system(size: size * 0.44, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                theme.isDarkModeEffective
                                    ? Color(hex: "#F48FB1") ?? Color.pink
                                    : Color(hex: "#C2185B") ?? Color.pink
                            )
                    }
                    .shadow(color: Color.black.opacity(0.04), radius: 3, y: 1)
                }

                // Huy hiệu máy ảnh nhỏ (nếu bật)
                if showCameraBadge {
                    Circle()
                        .fill(theme.primaryAction)
                        .frame(width: size * 0.35, height: size * 0.35)
                        .overlay {
                            Image(systemName: "camera.fill")
                                .font(.system(size: size * 0.18, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .overlay {
                            Circle()
                                .stroke(theme.surface, lineWidth: 1.5)
                        }
                        .offset(x: 2, y: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!showActions)
        .accessibilityLabel(isVN ? "Ảnh đại diện của \(effectiveUserName)" : "\(effectiveUserName)'s profile photo")
        .accessibilityHint(showActions ? (isVN ? "Chạm để xem hoặc thay đổi ảnh đại diện" : "Tap to view or change profile photo") : "")
        // Action Sheet / Confirmation Dialog
        .confirmationDialog(
            isVN ? "Ảnh đại diện" : "Profile Photo",
            isPresented: $showActionDialog,
            titleVisibility: .visible
        ) {
            // 1. Xem ảnh (chỉ hiện khi đã có ảnh)
            if avatarService.hasAvatar {
                Button(isVN ? "Xem ảnh đại diện" : "View Photo") {
                    showImageViewer = true
                }
            }

            // 2. Chọn ảnh từ thư viện
            Button(isVN ? "Chọn ảnh từ thư viện" : "Choose from Library") {
                showPhotosPicker = true
            }

            // 3. Xóa ảnh đại diện (chỉ hiện khi đã có ảnh)
            if avatarService.hasAvatar {
                Button(isVN ? "Xóa ảnh đại diện" : "Remove Photo", role: .destructive) {
                    avatarService.deleteAvatar()
                }
            }

            Button(locManager.t("action_cancel"), role: .cancel) {}
        }
        // PhotosPicker tích hợp
        .photosPicker(
            isPresented: $showPhotosPicker,
            selection: $selectedPickerItem,
            matching: .images
        )
        .onChange(of: selectedPickerItem) { _, newItem in
            guard let newItem = newItem else { return }
            loadPickedImage(item: newItem)
        }
        // Sheet Crop ảnh
        .sheet(isPresented: $showCropSheet) {
            if let imageToCrop = pickedImageForCrop {
                AvatarCropView(
                    originalImage: imageToCrop,
                    onSave: { croppedImage in
                        Task {
                            _ = await avatarService.saveAvatar(image: croppedImage)
                        }
                    },
                    onCancel: {
                        // Giữ nguyên ảnh cũ
                        pickedImageForCrop = nil
                    }
                )
            }
        }
        // Sheet Xem ảnh phóng to
        .sheet(isPresented: $showImageViewer) {
            if let avatar = avatarService.currentAvatarImage {
                AvatarDetailViewer(image: avatar, userName: effectiveUserName)
            }
        }
    }

    // MARK: - Tải ảnh từ PhotosPicker ra UIImage ngoài luồng giao diện

    private func loadPickedImage(item: PhotosPickerItem) {
        Task.detached(priority: .userInitiated) {
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                let fixed = uiImage.normalized()
                await MainActor.run {
                    self.pickedImageForCrop = fixed
                    self.showCropSheet = true
                    self.selectedPickerItem = nil
                }
            } else {
                await MainActor.run {
                    self.selectedPickerItem = nil
                }
            }
        }
    }
}

// MARK: - AvatarDetailViewer (Xem ảnh đại diện toàn màn hình)

private struct AvatarDetailViewer: View {
    let image: UIImage
    let userName: String

    @Environment(\.dismiss) private var dismiss
    private let locManager = LocalizationManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack {
                    Spacer()

                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(Circle())
                        .overlay {
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        }
                        .shadow(color: Color.black.opacity(0.8), radius: 24)
                        .padding(.horizontal, 32)

                    Spacer()
                }
            }
            .navigationTitle(userName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.85), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(locManager.t("action_done")) {
                        dismiss()
                    }
                    .font(.body.weight(.bold))
                    .foregroundStyle(.white)
                }
            }
        }
    }
}

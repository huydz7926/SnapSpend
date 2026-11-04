import UIKit
import SwiftUI
import Combine

// MARK: - ProfileAvatarService (Quản lý Ảnh đại diện Người dùng SnapSpend)

@MainActor
final class ProfileAvatarService: ObservableObject {

    static let shared = ProfileAvatarService()

    @Published private(set) var currentAvatarImage: UIImage?
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?

    // Mã người dùng đang hoạt động được gán từ ngoài vào, KHÔNG gọi lại AuthService.shared
    @Published private(set) var activeUserKey: String = "guest_default"

    private let fileManager = FileManager.default
    private let avatarsDirectoryURL: URL

    // Token chống race condition khi đổi tài khoản
    private var currentLoadTask: Task<Void, Never>?
    private var currentLoadToken: UUID = UUID()

    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("ViAnh/Avatars", isDirectory: true)

        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            var url = dir
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try? url.setResourceValues(resourceValues)
        }
        self.avatarsDirectoryURL = dir
        // KHÔNG gọi reloadAvatar() và KHÔNG truy cập AuthService.shared ở đây để tránh deadlock!
    }

    // MARK: - Key định danh theo Tài khoản

    func userKey(for user: AuthUser?) -> String {
        if let uid = user?.firebaseUID, !uid.isEmpty {
            return "firebase_\(uid)"
        }
        if let id = user?.id, !id.isEmpty {
            return "user_\(id)"
        }
        return "guest_default"
    }

    private func avatarFileURL(for key: String) -> URL {
        avatarsDirectoryURL.appendingPathComponent("avatar_\(key).jpg")
    }

    /// Kiểm tra người dùng hiện tại đã có ảnh đại diện hay chưa
    var hasAvatar: Bool {
        currentAvatarImage != nil
    }

    // MARK: - Nạp & Tải Avatar (Nhận user được truyền từ ngoài)

    /// Nạp ảnh đại diện cho tài khoản xác định
    func reloadAvatar(for user: AuthUser?) {
        // Hủy tác vụ tải ảnh remote trước đó nếu có
        currentLoadTask?.cancel()
        let token = UUID()
        self.currentLoadToken = token

        // 1. Khi đổi tài khoản, xóa ngay ảnh đang hiển thị của tài khoản cũ
        self.currentAvatarImage = nil
        self.isLoading = false
        self.errorMessage = nil

        let key = userKey(for: user)
        self.activeUserKey = key

        let fileURL = avatarFileURL(for: key)
        if fileManager.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            self.currentAvatarImage = image
            return
        }

        // 2. Nếu chưa có ảnh chọn từ máy, thử nạp từ Google photoURL
        if let photoURLString = user?.photoURL,
           let photoURL = URL(string: photoURLString) {
            loadRemotePhoto(from: photoURL, expectedKey: key, token: token)
        }
    }

    private func loadRemotePhoto(from url: URL, expectedKey: String, token: UUID) {
        isLoading = true
        currentLoadTask = Task { [weak self] in
            let downloadedImage = await Task.detached(priority: .background) { () -> UIImage? in
                guard let (data, response) = try? await URLSession.shared.data(from: url),
                      let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                      let image = UIImage(data: data) else {
                    return nil
                }
                return image.normalized()
            }.value

            guard !Task.isCancelled, let self = self else { return }
            if self.currentLoadToken == token && self.activeUserKey == expectedKey {
                self.currentAvatarImage = downloadedImage
                self.isLoading = false
            }
        }
    }

    // MARK: - Lưu & Xóa Avatar

    /// Lưu ảnh đã được crop và tối ưu vào bộ nhớ máy theo UID
    func saveAvatar(image: UIImage) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let targetKey = activeUserKey.isEmpty ? "guest_default" : activeUserKey
        let targetURL = avatarFileURL(for: targetKey)

        // Xử lý nén, chỉnh hướng và resize ngoài luồng giao diện
        let processedImage = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            let fixed = image.normalized()
            let resized = fixed.resizedToAvatarSize(targetPixelSize: 512)
            guard let jpegData = resized.jpegData(compressionQuality: 0.85) else {
                return nil
            }
            do {
                try jpegData.write(to: targetURL, options: .atomic)
                return resized
            } catch {
                print("[Avatar] Lỗi ghi tệp: \(error.localizedDescription)")
                return nil
            }
        }.value

        if let processedImage = processedImage {
            self.currentAvatarImage = processedImage
            HapticManager.shared.notifySuccess()
            return true
        } else {
            let isVN = LocalizationManager.shared.currentLanguage == .vietnamese
            self.errorMessage = isVN ? "Không thể lưu ảnh đại diện. Vui lòng thử lại." : "Could not save avatar. Please try again."
            HapticManager.shared.notifyWarning()
            return false
        }
    }

    /// Xóa ảnh đại diện của tài khoản hiện tại
    func deleteAvatar() {
        let targetKey = activeUserKey.isEmpty ? "guest_default" : activeUserKey
        let fileURL = avatarFileURL(for: targetKey)
        try? fileManager.removeItem(at: fileURL)
        self.currentAvatarImage = nil
        HapticManager.shared.notifyWarning()
    }
}

// MARK: - UIImage Extensions (Chuẩn hóa Hướng & Thu phóng Avatar)

extension UIImage {

    /// Chuẩn hóa hướng ảnh (loại bỏ EXIF rotation)
    func normalized() -> UIImage {
        if imageOrientation == .up { return self }

        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext() ?? self
    }

    /// Resize ảnh về kích thước avatar chuẩn (ví dụ 512x512) giữ độ nét cao
    func resizedToAvatarSize(targetPixelSize: CGFloat = 512) -> UIImage {
        let currentSize = self.size
        let ratio = max(targetPixelSize / currentSize.width, targetPixelSize / currentSize.height)
        let newSize = CGSize(width: currentSize.width * ratio, height: currentSize.height * ratio)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: targetPixelSize, height: targetPixelSize))
        return renderer.image { _ in
            let originX = (targetPixelSize - newSize.width) / 2.0
            let originY = (targetPixelSize - newSize.height) / 2.0
            self.draw(in: CGRect(x: originX, y: originY, width: newSize.width, height: newSize.height))
        }
    }
}

import XCTest
import UIKit
@testable import ViAnh

@MainActor
final class ProfileAvatarTests: XCTestCase {

    override func setUp() async throws {
        // Đảm bảo trạng thái sạch trước mỗi testcase
    }

    // MARK: - Testcase 1: Không deadlock lúc khởi tạo AuthService & ProfileAvatarService

    func testServiceInitializationHasNoDeadlock() {
        // Kiểm tra hai singleton khởi tạo an toàn
        let auth = AuthService.shared
        let avatar = ProfileAvatarService.shared
        XCTAssertNotNil(auth)
        XCTAssertNotNil(avatar)
    }

    // MARK: - Testcase 2: Ánh xạ mã UserKey chính xác theo UID

    func testUserKeyMapping() {
        let avatarService = ProfileAvatarService.shared

        // 1. Firebase User có UID
        let firebaseUser = AuthUser(
            id: "local_id",
            provider: .google,
            displayName: "Test User",
            email: "test@example.com",
            phoneNumber: nil,
            photoURL: nil,
            createdAt: .now,
            firebaseUID: "firebase_uid_999"
        )
        XCTAssertEqual(avatarService.userKey(for: firebaseUser), "firebase_firebase_uid_999")

        // 2. Local User không có Firebase UID
        let localUser = AuthUser(
            id: "local_custom_id",
            provider: .email,
            displayName: "Local User",
            email: "local@example.com",
            phoneNumber: nil,
            photoURL: nil,
            createdAt: .now,
            firebaseUID: nil
        )
        XCTAssertEqual(avatarService.userKey(for: localUser), "user_local_custom_id")

        // 3. Guest / Nil
        XCTAssertEqual(avatarService.userKey(for: nil), "guest_default")
    }

    // MARK: - Testcase 3: Lưu, nạp và xóa ảnh đại diện cục bộ

    func testSaveLoadAndDeleteAvatar() async {
        let avatarService = ProfileAvatarService.shared

        let testUser = AuthUser(
            id: "test_user_unit",
            provider: .email,
            displayName: "Tester",
            email: "test@example.com",
            phoneNumber: nil,
            photoURL: nil,
            createdAt: .now,
            firebaseUID: "test_uid_save_load"
        )

        // Nạp user
        avatarService.reloadAvatar(for: testUser)
        XCTAssertFalse(avatarService.hasAvatar)

        // Tạo ảnh mẫu 100x100
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        let sampleImage = renderer.image { ctx in
            UIColor.systemBlue.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }

        // Lưu avatar
        let saved = await avatarService.saveAvatar(image: sampleImage)
        XCTAssertTrue(saved)
        XCTAssertTrue(avatarService.hasAvatar)
        XCTAssertNotNil(avatarService.currentAvatarImage)

        // Nạp lại
        avatarService.reloadAvatar(for: testUser)
        XCTAssertTrue(avatarService.hasAvatar)

        // Xóa avatar
        avatarService.deleteAvatar()
        XCTAssertFalse(avatarService.hasAvatar)
        XCTAssertNil(avatarService.currentAvatarImage)
    }

    // MARK: - Testcase 4: Phân tách và cô lập avatar khi đổi tài khoản

    func testAccountSwitchingClearsAndIsolatesAvatar() async {
        let avatarService = ProfileAvatarService.shared

        let userA = AuthUser(
            id: "user_a",
            provider: .google,
            displayName: "User A",
            email: "a@gmail.com",
            phoneNumber: nil,
            photoURL: nil,
            createdAt: .now,
            firebaseUID: "uid_alpha"
        )

        let userB = AuthUser(
            id: "user_b",
            provider: .apple,
            displayName: "User B",
            email: "b@privaterelay.appleid.com",
            phoneNumber: nil,
            photoURL: nil,
            createdAt: .now,
            firebaseUID: "uid_beta"
        )

        // 1. Lưu avatar cho User A
        avatarService.reloadAvatar(for: userA)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 80))
        let imgA = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 80, height: 80))
        }
        _ = await avatarService.saveAvatar(image: imgA)
        XCTAssertTrue(avatarService.hasAvatar)

        // 2. Chuyển sang User B -> Avatar lập tức bị xóa khỏi màn hình (trở về nil)
        avatarService.reloadAvatar(for: userB)
        XCTAssertFalse(avatarService.hasAvatar, "User B chưa có ảnh thì không được hiển thị ảnh của User A")
        XCTAssertNil(avatarService.currentAvatarImage)

        // 3. Quay lại User A -> Avatar của User A được nạp lại nguyên vẹn
        avatarService.reloadAvatar(for: userA)
        XCTAssertTrue(avatarService.hasAvatar, "Avatar của User A phải được bảo toàn khi quay lại")

        // Dọn dẹp
        avatarService.deleteAvatar()
    }

    // MARK: - Testcase 5: Chuẩn hóa hướng và resize ảnh đại diện

    func testImageNormalizationAndResize() {
        let originalSize = CGSize(width: 800, height: 600)
        let renderer = UIGraphicsImageRenderer(size: originalSize)
        let wideImage = renderer.image { ctx in
            UIColor.green.setFill()
            ctx.fill(CGRect(origin: .zero, size: originalSize))
        }

        let normalized = wideImage.normalized()
        XCTAssertEqual(normalized.imageOrientation, .up)

        let avatarResized = normalized.resizedToAvatarSize(targetPixelSize: 512)
        XCTAssertEqual(avatarResized.size.width, 512, accuracy: 1.0)
        XCTAssertEqual(avatarResized.size.height, 512, accuracy: 1.0)
    }
}


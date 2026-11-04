import UIKit

// MARK: - HapticManager

/// Wrapper nhẹ cho UIImpactFeedbackGenerator và UINotificationFeedbackGenerator
/// Tập trung toàn bộ haptic calls vào một chỗ để dễ quản lý
@MainActor
final class HapticManager {

    static let shared = HapticManager()
    private init() {}

    // MARK: - Impact

    /// Khi chọn danh mục hoặc chạm vào chip gợi ý
    func selectionChanged() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Khi lưu khoản chi thành công
    func savedExpense() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Thông báo thao tác thành công
    func notifySuccess() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    /// Khi chạm ngưỡng ngân sách (80%, 100%, vượt)
    func budgetWarning() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }

    /// Khi vượt ngân sách
    func budgetExceeded() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }

    /// Thông báo cảnh báo (đăng xuất, xóa tài khoản...)
    func notifyWarning() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }

    /// Khi xóa thành công
    func deleted() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        generator.impactOccurred()
    }
}

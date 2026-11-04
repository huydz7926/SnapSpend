import Foundation
import SwiftUI

// MARK: - App Language

enum AppLanguage: String, CaseIterable, Identifiable {
    case vietnamese = "vi"
    case english = "en"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vietnamese: return "Tiếng Việt"
        case .english: return "English"
        }
    }
}

// MARK: - LocalizationManager

@MainActor
@Observable
final class LocalizationManager {

    static let shared = LocalizationManager()

    var currentLanguage: AppLanguage = .vietnamese {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "app_language")
        }
    }

    init() {
        if let saved = UserDefaults.standard.string(forKey: "app_language"),
           let lang = AppLanguage(rawValue: saved) {
            self.currentLanguage = lang
        } else {
            self.currentLanguage = .vietnamese
        }
    }

    var locale: Locale {
        switch currentLanguage {
        case .vietnamese: return Locale(identifier: "vi_VN")
        case .english: return Locale(identifier: "en_US")
        }
    }

    // MARK: - Translation Mapping

    private let translations: [String: [AppLanguage: String]] = [
        // Tabs
        "tab_home": [.vietnamese: "Trang chủ", .english: "Home"],
        "tab_memories": [.vietnamese: "Kỷ niệm", .english: "Memories"],
        "tab_analytics": [.vietnamese: "Thống kê", .english: "Analytics"],
        "tab_budget": [.vietnamese: "Ngân sách", .english: "Budget"],
        "tab_settings": [.vietnamese: "Cài đặt", .english: "Settings"],

        // Actions
        "action_save": [.vietnamese: "Lưu", .english: "Save"],
        "action_cancel": [.vietnamese: "Hủy", .english: "Cancel"],
        "action_edit": [.vietnamese: "Sửa", .english: "Edit"],
        "action_delete": [.vietnamese: "Xóa", .english: "Delete"],
        "action_done": [.vietnamese: "Xong", .english: "Done"],
        "action_retake": [.vietnamese: "Chụp lại", .english: "Retake"],
        "action_continue_no_photo": [.vietnamese: "Tiếp tục không có ảnh", .english: "Continue without photo"],
        "action_today": [.vietnamese: "Hôm nay", .english: "Today"],
        "action_save_photo": [.vietnamese: "Lưu ảnh", .english: "Save photo"],
        "action_share": [.vietnamese: "Chia sẻ", .english: "Share"],

        // Types
        "type_expense": [.vietnamese: "Khoản chi", .english: "Expense"],
        "type_income": [.vietnamese: "Khoản thu", .english: "Income"],

        // Common labels
        "label_streak": [.vietnamese: "Chuỗi", .english: "Streak"],
        "label_photos": [.vietnamese: "ảnh", .english: "photos"],
        "label_days": [.vietnamese: "ngày", .english: "days"],
        "label_transaction": [.vietnamese: "Giao dịch", .english: "Transaction"],
        "label_category": [.vietnamese: "Danh mục", .english: "Category"],
        "label_amount": [.vietnamese: "Số tiền", .english: "Amount"],
        "label_caption": [.vietnamese: "Chú thích", .english: "Caption"],
        "label_spent": [.vietnamese: "Đã chi", .english: "Spent"],
        "label_remaining": [.vietnamese: "Còn lại", .english: "Remaining"],
        "label_over_limit": [.vietnamese: "Vượt hạn mức", .english: "Over limit"],

        // Default categories
        "cat_food": [.vietnamese: "Ăn uống", .english: "Food & Dining"],
        "cat_shopping": [.vietnamese: "Mua sắm", .english: "Shopping"],
        "cat_transport": [.vietnamese: "Đi lại", .english: "Transportation"],
        "cat_housing": [.vietnamese: "Nhà ở", .english: "Housing"],
        "cat_education": [.vietnamese: "Học tập", .english: "Education"],
        "cat_health": [.vietnamese: "Sức khỏe", .english: "Healthcare"],
        "cat_entertainment": [.vietnamese: "Giải trí", .english: "Entertainment"],
        "cat_other": [.vietnamese: "Khác", .english: "Other"]
    ]

    /// Dịch theo key
    func t(_ key: String) -> String {
        translations[key]?[currentLanguage] ?? key
    }

    /// Tự động dịch tên danh mục mặc định sang ngôn ngữ hiện tại
    func localizedCategoryName(_ originalName: String) -> String {
        switch originalName {
        case "Ăn uống", "Food & Dining": return t("cat_food")
        case "Mua sắm", "Shopping": return t("cat_shopping")
        case "Đi lại", "Transportation": return t("cat_transport")
        case "Nhà ở", "Housing": return t("cat_housing")
        case "Học tập", "Education": return t("cat_education")
        case "Sức khỏe", "Healthcare": return t("cat_health")
        case "Giải trí", "Entertainment": return t("cat_entertainment")
        case "Khác", "Other": return t("cat_other")
        default: return originalName
        }
    }
}


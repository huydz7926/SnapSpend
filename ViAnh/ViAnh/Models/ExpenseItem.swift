import Foundation
import SwiftData

// MARK: - Transaction Type

enum TransactionType: String, CaseIterable, Codable {
    case expense = "expense"
    case income = "income"

    var title: String {
        switch self {
        case .expense: return "Khoản chi"
        case .income: return "Khoản thu"
        }
    }

    var arrowSymbol: String {
        switch self {
        case .expense: return "↗"
        case .income: return "↙"
        }
    }
}

// MARK: - ExpenseItem Model

@Model
final class ExpenseItem {

    var id: UUID

    // Số tiền — DÙNG Int64 (đơn vị: đồng VND), TUYỆT ĐỐI KHÔNG DÙNG Double
    var amountVND: Int64

    // Loại giao dịch: "expense" (chi) hoặc "income" (thu)
    var transactionTypeRaw: String = "expense"

    // Mã tiền tệ (mặc định VND)
    var currencyCode: String = "VND"

    // Quan hệ nhiều-một với ExpenseCategory
    var category: ExpenseCategory

    // Ví / Nguồn tiền thanh toán
    var wallet: Wallet?

    // Thời điểm phát sinh thực tế (người dùng chọn, mặc định = now)
    var spentAt: Date

    // Ảnh — chỉ lưu tên file tương đối, KHÔNG lưu full path
    // (full path thay đổi khi iOS cập nhật container, lưu relative name là an toàn)
    var imageFileName: String?
    var thumbnailFileName: String?

    // Nguồn ảnh: "camera" (chụp trong app), "library" (từ thư viện), "none" (không ảnh)
    var photoSourceRaw: String = "camera"

    // Thời điểm chụp ảnh thực tế (dùng tính chuỗi streak, không đổi khi sửa spentAt)
    var capturedAt: Date? = nil

    // Caption ảnh kiểu Locket
    var caption: String = ""

    // Metadata
    var title: String
    var note: String
    var createdAt: Date
    var updatedAt: Date

    // Chủ sở hữu dữ liệu (Firebase UID hoặc Guest ID ổn định)
    var ownerUID: String = ""

    init(
        amountVND: Int64,
        category: ExpenseCategory,
        spentAt: Date = .now,
        title: String = "",
        note: String = "",
        type: TransactionType = .expense,
        wallet: Wallet? = nil,
        currencyCode: String = "VND",
        photoSource: String = "camera",
        capturedAt: Date? = nil,
        caption: String = "",
        ownerUID: String = ""
    ) {
        self.id = UUID()
        self.amountVND = amountVND
        self.category = category
        self.spentAt = spentAt
        self.imageFileName = nil
        self.thumbnailFileName = nil
        self.photoSourceRaw = photoSource
        self.capturedAt = capturedAt
        self.caption = caption
        self.title = title
        self.note = note
        self.transactionTypeRaw = type.rawValue
        self.wallet = wallet
        self.currencyCode = currencyCode
        self.createdAt = .now
        self.updatedAt = .now
        self.ownerUID = ownerUID
    }
}

// MARK: - Helpers

extension ExpenseItem {

    /// Enum kiểu loại giao dịch
    var transactionType: TransactionType {
        get { TransactionType(rawValue: transactionTypeRaw) ?? .expense }
        set { transactionTypeRaw = newValue.rawValue }
    }

    /// Alias cho transactionType
    var type: TransactionType {
        get { transactionType }
        set { transactionType = newValue }
    }

    /// Là khoản chi
    var isExpense: Bool {
        transactionType == .expense
    }

    /// Là khoản thu
    var isIncome: Bool {
        transactionType == .income
    }

    /// Tên hiển thị: dùng title nếu có, nếu không dùng tên danh mục (đã được bản địa hóa)
    @MainActor
    var displayTitle: String {
        title.isEmpty ? LocalizationManager.shared.localizedCategoryName(category.name) : title
    }

    /// Là ảnh chụp camera thực tế trong app
    var isCameraPhoto: Bool {
        photoSourceRaw == "camera" && imageFileName != nil
    }

    /// Ngày chụp thực tế (fallback về createdAt hoặc spentAt cho dữ liệu cũ)
    var effectiveCaptureDate: Date {
        capturedAt ?? createdAt
    }

    /// Caption hiển thị (ưu tiên caption, nếu rỗng fallback về note)
    var displayCaption: String {
        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        return note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Cập nhật updatedAt mỗi khi có thay đổi
    func markUpdated() {
        updatedAt = .now
    }
}

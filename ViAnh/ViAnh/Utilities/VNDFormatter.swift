import Foundation

// MARK: - VND Formatter

/// Format số tiền VND từ Int64
/// Ví dụ: 35000 → "35.000 ₫"
extension Int64 {

    /// Format đầy đủ: 35000 → "35.000 ₫"
    var vndFormatted: String {
        VNDFormatter.shared.format(self)
    }

    /// Format có dấu (+/-): +200.000 ₫ hoặc -460.000 ₫
    func vndSignedFormatted(isIncome: Bool) -> String {
        let prefix = isIncome ? "+" : "-"
        return "\(prefix)\(VNDFormatter.shared.format(abs(self)))"
    }

    /// Format ngắn cho chip gợi ý hoặc ô lịch: 35000 → "35k", 1500000 → "1,5tr"
    var vndShortFormatted: String {
        let absValue = abs(self)
        if absValue >= 1_000_000 {
            let millions = Double(absValue) / 1_000_000.0
            if millions == millions.rounded() {
                return "\(Int(millions))tr"
            } else {
                let formatted = String(format: "%.1f", millions)
                return "\(formatted)tr"
            }
        } else if absValue >= 1_000 {
            let thousands = absValue / 1_000
            return "\(thousands)k"
        } else {
            return "\(absValue)₫"
        }
    }

    /// Format ngắn có dấu (+/-) hiển thị trên ô lịch: -460k hoặc +200k
    func vndSignedShortFormatted(isIncome: Bool) -> String {
        let prefix = isIncome ? "+" : "-"
        return "\(prefix)\(vndShortFormatted)"
    }
}

// MARK: - VNDFormatter Singleton

final class VNDFormatter: @unchecked Sendable {

    static let shared = VNDFormatter()

    private let formatter: NumberFormatter

    private init() {
        formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        formatter.groupingSize = 3
    }

    func format(_ amount: Int64) -> String {
        let number = NSNumber(value: amount)
        let formatted = formatter.string(from: number) ?? "\(amount)"
        return "\(formatted) ₫"
    }

    func formatWithoutSymbol(_ amount: Int64) -> String {
        let number = NSNumber(value: amount)
        return formatter.string(from: number) ?? "\(amount)"
    }

    static func formatCompact(_ amount: Int64) -> String {
        VNDFormatter.shared.formatWithoutSymbol(amount)
    }
}

// MARK: - Smart VND Suggestion

/// Khi người dùng gõ "35" → gợi ý [35_000, 350_000, 3_500_000]
struct SmartVNDSuggestion {

    /// Tạo danh sách gợi ý mệnh giá từ chuỗi số người dùng đang gõ
    /// - Parameter rawInput: Chuỗi số thuần túy, ví dụ "35", "1", "120"
    /// - Returns: Tối đa 3 mệnh giá gợi ý (Int64, đơn vị đồng)
    static func suggestions(for rawInput: String) -> [Int64] {
        // Lọc chỉ lấy chữ số
        let digits = rawInput.filter { $0.isNumber }

        guard !digits.isEmpty,
              let baseValue = Int64(digits),
              baseValue > 0 else {
            return []
        }

        // Tạo 3 mức nhân: x1000, x10000, x100000
        // Ví dụ: "35" → 35*1000=35k, 35*10000=350k, 35*100000=3.5tr
        let multipliers: [Int64] = [1_000, 10_000, 100_000]

        return multipliers.compactMap { multiplier -> Int64? in
            // Tránh overflow Int64
            guard baseValue <= Int64.max / multiplier else { return nil }
            let result = baseValue * multiplier
            // Giới hạn hợp lý: tối đa 999 tỷ đồng
            guard result <= 999_000_000_000 else { return nil }
            return result
        }
    }
}

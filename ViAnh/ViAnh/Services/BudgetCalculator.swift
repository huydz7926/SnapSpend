import Foundation

// MARK: - BudgetCalculator

/// Tất cả logic tính toán ngân sách — tách hoàn toàn khỏi View
/// Tất cả methods đều là pure functions (static), dễ unit test
struct BudgetCalculator {

    // MARK: - Budget Status

    /// Trạng thái ngân sách — dùng cả icon lẫn text để đáp ứng accessibility
    enum BudgetStatus: Equatable {
        case notSet                                  // Chưa đặt ngân sách
        case safe(ratio: Double)                     // ratio < 0.8
        case warning(ratio: Double)                  // 0.8 ≤ ratio < 1.0
        case atLimit(ratio: Double)                  // ratio == 1.0 (chính xác)
        case overBudget(ratio: Double, exceededVND: Int64)  // ratio > 1.0

        var ratio: Double? {
            switch self {
            case .notSet: return nil
            case .safe(let r), .warning(let r), .atLimit(let r), .overBudget(let r, _): return r
            }
        }

        /// Nhãn chữ — dùng cho VoiceOver và UI text (KHÔNG chỉ dùng màu)
        @MainActor
        var label: String {
            let isVN = LocalizationManager.shared.currentLanguage == .vietnamese
            switch self {
            case .notSet:
                return isVN ? "Chưa đặt ngân sách" : "No budget set"
            case .safe(let r):
                return isVN ? "\(Int(r * 100))% đã dùng" : "\(Int(r * 100))% used"
            case .warning(let r):
                return isVN ? "Cảnh báo: \(Int(r * 100))% đã dùng" : "Warning: \(Int(r * 100))% used"
            case .atLimit:
                return isVN ? "Đã dùng hết ngân sách" : "Budget reached"
            case .overBudget(_, let exceeded):
                return isVN ? "Vượt \(exceeded.vndFormatted)" : "Over by \(exceeded.vndFormatted)"
            }
        }

        /// SF Symbol name — dùng kèm với label, không thay thế label
        var symbolName: String {
            switch self {
            case .notSet:      return "questionmark.circle"
            case .safe:        return "checkmark.circle.fill"
            case .warning:     return "exclamationmark.triangle.fill"
            case .atLimit:     return "exclamationmark.circle.fill"
            case .overBudget:  return "xmark.circle.fill"
            }
        }

        static func == (lhs: BudgetStatus, rhs: BudgetStatus) -> Bool {
            switch (lhs, rhs) {
            case (.notSet, .notSet): return true
            case (.safe(let a), .safe(let b)): return abs(a - b) < 0.001
            case (.warning(let a), .warning(let b)): return abs(a - b) < 0.001
            case (.atLimit(let a), .atLimit(let b)): return abs(a - b) < 0.001
            case (.overBudget(let a, let c), .overBudget(let b, let d)): return abs(a - b) < 0.001 && c == d
            default: return false
            }
        }
    }

    // MARK: - Total Spent

    /// Tính tổng chi trong một tháng/năm cụ thể
    /// Dùng Calendar.current để tính đúng ranh giới tháng theo timezone người dùng
    static func totalSpent(
        expenses: [ExpenseItem],
        year: Int,
        month: Int,
        calendar: Calendar = .current
    ) -> Int64 {
        let filtered = expenses.filter { expense in
            isExpense(expense, inYear: year, month: month, calendar: calendar)
        }
        // Dùng reduce với Int64 để tránh overflow
        return filtered.reduce(Int64(0)) { sum, expense in
            sum + expense.amountVND
        }
    }

    /// Tính tổng chi hôm nay
    static func totalSpentToday(
        expenses: [ExpenseItem],
        calendar: Calendar = .current
    ) -> Int64 {
        let today = calendar.startOfDay(for: Date.now)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else {
            return 0
        }
        let filtered = expenses.filter { expense in
            expense.spentAt >= today && expense.spentAt < tomorrow
        }
        return filtered.reduce(Int64(0)) { $0 + $1.amountVND }
    }

    // MARK: - Budget Status Calculation

    /// Tính trạng thái ngân sách tổng
    /// QUAN TRỌNG: KHÔNG BAO GIỜ chia cho 0 — guard budget != nil và > 0
    static func budgetStatus(
        spent: Int64,
        budget: Int64?
    ) -> BudgetStatus {
        guard let budget = budget, budget > 0 else {
            return .notSet
        }

        let ratio = Double(spent) / Double(budget)

        if ratio > 1.0 {
            let exceeded = spent - budget
            return .overBudget(ratio: ratio, exceededVND: exceeded)
        } else if ratio >= 1.0 {
            return .atLimit(ratio: ratio)
        } else if ratio >= 0.8 {
            return .warning(ratio: ratio)
        } else {
            return .safe(ratio: ratio)
        }
    }

    /// Tính tổng chi của một danh mục trong tháng/năm
    static func totalSpentInCategory(
        categoryId: UUID,
        expenses: [ExpenseItem],
        year: Int,
        month: Int,
        calendar: Calendar = .current
    ) -> Int64 {
        let filtered = expenses.filter { expense in
            expense.category.id == categoryId &&
            isExpense(expense, inYear: year, month: month, calendar: calendar)
        }
        return filtered.reduce(Int64(0)) { $0 + $1.amountVND }
    }

    /// Tính trạng thái ngân sách theo danh mục cụ thể
    static func categoryBudgetStatus(
        categoryId: UUID,
        expenses: [ExpenseItem],
        year: Int,
        month: Int,
        categoryBudget: Int64?,
        calendar: Calendar = .current
    ) -> BudgetStatus {
        let spent = totalSpentInCategory(
            categoryId: categoryId,
            expenses: expenses,
            year: year,
            month: month,
            calendar: calendar
        )
        return budgetStatus(spent: spent, budget: categoryBudget)
    }

    // MARK: - Group By Month

    /// Phân nhóm expenses theo tháng — dùng cho section header trong Album
    /// Trả về danh sách đã sắp xếp mới nhất trước
    static func groupByMonth(
        expenses: [ExpenseItem],
        calendar: Calendar = .current
    ) -> [(key: DateComponents, expenses: [ExpenseItem])] {
        var groups: [DateComponents: [ExpenseItem]] = [:]

        for expense in expenses {
            let components = calendar.dateComponents([.year, .month], from: expense.spentAt)
            groups[components, default: []].append(expense)
        }

        // Sắp xếp mỗi nhóm: mới nhất trước
        var result = groups.map { key, value in
            (key: key, expenses: value.sorted { $0.spentAt > $1.spentAt })
        }

        // Sắp xếp các nhóm: tháng mới nhất trước
        result.sort { a, b in
            let aYear = a.key.year ?? 0
            let bYear = b.key.year ?? 0
            if aYear != bYear { return aYear > bYear }
            let aMonth = a.key.month ?? 0
            let bMonth = b.key.month ?? 0
            return aMonth > bMonth
        }

        return result
    }

    // MARK: - Spending by Category

    /// Tính chi tiêu theo danh mục trong một tháng (dùng cho biểu đồ)
    static func spentByCategory(
        expenses: [ExpenseItem],
        year: Int,
        month: Int,
        calendar: Calendar = .current
    ) -> [UUID: Int64] {
        var result: [UUID: Int64] = [:]

        let filtered = expenses.filter { expense in
            isExpense(expense, inYear: year, month: month, calendar: calendar)
        }

        for expense in filtered {
            let catId = expense.category.id
            result[catId, default: 0] += expense.amountVND
        }

        return result
    }

    // MARK: - Month Boundary Helper

    /// Kiểm tra expense có nằm trong tháng/năm không
    /// Dùng Calendar để tính đúng ranh giới ngày đầu/cuối tháng
    static func isExpense(
        _ expense: ExpenseItem,
        inYear year: Int,
        month: Int,
        calendar: Calendar = .current
    ) -> Bool {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        components.hour = 0
        components.minute = 0
        components.second = 0

        guard let startOfMonth = calendar.date(from: components),
              let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
            return false
        }

        // spentAt >= startOfMonth AND spentAt < startOfNextMonth
        // Đây là cách tính ranh giới tháng chính xác, tránh lỗi giao thừa 23:59→00:00
        return expense.spentAt >= startOfMonth && expense.spentAt < startOfNextMonth
    }

    // MARK: - Current Month/Year

    static func currentYear(calendar: Calendar = .current) -> Int {
        calendar.component(.year, from: Date.now)
    }

    static func currentMonth(calendar: Calendar = .current) -> Int {
        calendar.component(.month, from: Date.now)
    }
}

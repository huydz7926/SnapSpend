import SwiftUI
import SwiftData

// MARK: - DashboardView (Trang chủ & Kỷ Niệm SnapSpend)

struct DashboardView: View {

    @Query(sort: \ExpenseItem.spentAt, order: .reverse)
    private var allExpenses: [ExpenseItem]

    @Query private var budgets: [MonthlyBudget]

    private let authService = AuthService.shared

    /// Định danh chủ tài khoản hiện tại
    private var currentOwnerUID: String {
        authService.currentOwnerID
    }

    /// Lọc triệt để chỉ các giao dịch thuộc chủ tài khoản hiện tại
    private var userExpenses: [ExpenseItem] {
        guard !authService.isSignedOut else { return [] }
        return allExpenses.filter { $0.ownerUID == currentOwnerUID }
    }

    /// Lọc ngân sách thuộc chủ tài khoản hiện tại
    private var userBudgets: [MonthlyBudget] {
        guard !authService.isSignedOut else { return [] }
        return budgets.filter { $0.ownerUID == currentOwnerUID }
    }

    // Trạng thái thanh công cụ
    @State private var periodMode: DashboardPeriodMode = .month
    @State private var isMoneyHidden: Bool = false
    @State private var isGridLayout: Bool = true // true = Lịch ảnh, false = Danh sách
    @State private var showFilterSheet: Bool = false

    // Bộ lọc
    @State private var selectedCategoryId: UUID? = nil
    @State private var selectedWalletId: UUID? = nil

    // Kỳ thời gian đang chọn
    @State private var selectedDay: Int = Calendar.current.component(.day, from: .now)
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: .now)
    @State private var selectedYear: Int = Calendar.current.component(.year, from: .now)

    // Điều hướng chi tiết
    @State private var showSettings: Bool = false
    @State private var showAddExpense: Bool = false
    @State private var targetAddDate: Date = Date.now
    @State private var selectedExpenseForDetail: ExpenseItem? = nil
    @State private var selectedDayExpenses: DayExpensesIdentifiable? = nil

    private let theme = ThemeManager.shared
    private let locManager = LocalizationManager.shared

    // MARK: - Filtered Expenses

    private var filteredExpenses: [ExpenseItem] {
        userExpenses.filter { expense in
            let cal = Calendar.current
            let y = cal.component(.year, from: expense.spentAt)
            let m = cal.component(.month, from: expense.spentAt)

            guard y == selectedYear && m == selectedMonth else {
                return false
            }

            if periodMode == .day {
                let d = cal.component(.day, from: expense.spentAt)
                guard d == selectedDay else { return false }
            }

            if let catId = selectedCategoryId, expense.category.id != catId {
                return false
            }

            if let walletId = selectedWalletId, expense.wallet?.id != walletId {
                return false
            }

            return true
        }
    }

    // Tổng chi & thu trong kỳ
    private var totalExpenseInPeriod: Int64 {
        filteredExpenses.filter { $0.isExpense }.reduce(0) { $0 + $1.amountVND }
    }

    private var totalIncomeInPeriod: Int64 {
        filteredExpenses.filter { $0.isIncome }.reduce(0) { $0 + $1.amountVND }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 1. Header: Lời chào theo giờ + Bánh răng cài đặt + Avatar
                DashboardHeaderView(onOpenSettings: {
                    showSettings = true
                })

                // 2. Toolbar: Gạt Ngày/Tháng, Nút Hôm nay, 3 nút công cụ xanh lam nhạt, Thanh cuộn kỳ
                DashboardToolbarView(
                    periodMode: $periodMode,
                    isMoneyHidden: $isMoneyHidden,
                    isGridLayout: $isGridLayout,
                    showFilterSheet: $showFilterSheet,
                    hasActiveFilters: selectedCategoryId != nil || selectedWalletId != nil,
                    selectedDay: $selectedDay,
                    selectedMonth: $selectedMonth,
                    selectedYear: $selectedYear,
                    onJumpToToday: jumpToToday
                )

                // 3. Hai thẻ trắng Chi ↗ (hồng đỏ) và Thu ↙ (xanh lá) đặt cạnh nhau
                TransactionSummaryCardsRow(
                    totalExpense: totalExpenseInPeriod,
                    totalIncome: totalIncomeInPeriod,
                    isMoneyHidden: isMoneyHidden
                )

                // 4. Nội dung chính: Lịch Kỷ Niệm (Chế độ Tháng) hoặc Chi tiết Ngày (Chế độ Ngày)
                if periodMode == .month && isGridLayout {
                    MemoryCalendarView(
                        year: selectedYear,
                        month: selectedMonth,
                        expenses: filteredExpenses,
                        allExpenses: userExpenses,
                        isMoneyHidden: isMoneyHidden,
                        onAddForDate: { date in
                            targetAddDate = date
                            showAddExpense = true
                        },
                        onSelectDay: { date, items in
                            selectedDayExpenses = DayExpensesIdentifiable(date: date, expenses: items)
                        }
                    )
                } else {
                    // Hiển thị danh sách giao dịch & kỷ niệm trong ngày hoặc danh sách list
                    transactionsListSection
                }

                Spacer().frame(height: 24)
            }
            .padding(.top, 4)
        }
        .background(theme.background)
        .navigationBarHidden(true)
        .onChange(of: authService.currentOwnerID) { _, _ in
            // Khi phiên đăng nhập thay đổi hoặc đăng xuất, lập tức đóng các màn hình/sheet đang mở của tài khoản cũ
            showSettings = false
            showFilterSheet = false
            showAddExpense = false
            selectedExpenseForDetail = nil
            selectedDayExpenses = nil
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
            }
        }
        .sheet(isPresented: $showFilterSheet) {
            DashboardFilterSheet(
                selectedCategoryId: $selectedCategoryId,
                selectedWalletId: $selectedWalletId
            )
        }
        .sheet(isPresented: $showAddExpense) {
            AddExpenseView(initialDate: targetAddDate)
        }
        .sheet(item: $selectedExpenseForDetail) { expense in
            ExpenseDetailView(expense: expense)
        }
        .sheet(item: $selectedDayExpenses) { wrapper in
            NavigationStack {
                List(wrapper.expenses) { expense in
                    Button {
                        selectedDayExpenses = nil
                        selectedExpenseForDetail = expense
                    } label: {
                        RecentExpenseRow(expense: expense)
                    }
                    .buttonStyle(.plain)
                }
                .navigationTitle(
                    locManager.currentLanguage == .vietnamese
                        ? "Giao dịch ngày \(DateHelpers.formatFullDate(wrapper.date))"
                        : "Transactions on \(DateHelpers.formatFullDate(wrapper.date))"
                )
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    private func jumpToToday() {
        let now = Date.now
        let cal = Calendar.current
        selectedYear = cal.component(.year, from: now)
        selectedMonth = cal.component(.month, from: now)
        selectedDay = cal.component(.day, from: now)
    }

    // MARK: - Transactions List Section (Chế độ Ngày hoặc Chế độ Danh sách)

    private var transactionsListSection: some View {
        VStack(spacing: 12) {
            if filteredExpenses.isEmpty {
                EmptyStateView(
                    symbol: "photo.on.rectangle.angled",
                    title: periodMode == .day
                        ? (locManager.currentLanguage == .vietnamese ? "Chưa có ảnh hoặc chi tiêu ngày này" : "No photos or expenses for this day")
                        : (locManager.currentLanguage == .vietnamese ? "Chưa có giao dịch" : "No transactions"),
                    message: locManager.currentLanguage == .vietnamese
                        ? "Bấm nút [+] để thêm một khoản chi bằng hình ảnh ngay."
                        : "Tap [+] to snap and add an expense with photo.",
                    actionTitle: locManager.currentLanguage == .vietnamese ? "Thêm chi tiêu" : "Add Expense",
                    action: {
                        var comp = DateComponents()
                        comp.year = selectedYear
                        comp.month = selectedMonth
                        comp.day = selectedDay
                        targetAddDate = Calendar.current.date(from: comp) ?? Date.now
                        showAddExpense = true
                    }
                )
                .padding(.top, 16)
            } else {
                ForEach(filteredExpenses) { expense in
                    Button {
                        selectedExpenseForDetail = expense
                        HapticManager.shared.selectionChanged()
                    } label: {
                        dayExpenseCard(for: expense)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    private func dayExpenseCard(for expense: ExpenseItem) -> some View {
        HStack(spacing: 14) {
            // Thumbnail ảnh hoặc Icon danh mục
            if let thumb = expense.thumbnailFileName {
                AsyncThumbnailView(fileName: thumb, category: expense.category)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color(hex: "#FF4081")?.opacity(0.6) ?? Color.pink.opacity(0.6), lineWidth: 1.5)
                    }
            } else {
                Circle()
                    .fill(expense.category.color.opacity(0.15))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: expense.category.symbolName)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(expense.category.color)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(expense.displayTitle)
                    .font(.body.weight(.bold))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(expense.category.name)
                        .font(.caption2)
                        .foregroundStyle(expense.category.color)

                    Text("•")
                        .font(.caption2)
                        .foregroundStyle(theme.textSecondary)

                    Text(DateHelpers.formatRelativeDateTime(expense.spentAt))
                        .font(.caption2)
                        .foregroundStyle(theme.textSecondary)
                }

                if !expense.displayCaption.isEmpty {
                    Text(expense.displayCaption)
                        .font(.caption2.italic())
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(expense.isExpense ? "-\(expense.amountVND.vndFormatted)" : "+\(expense.amountVND.vndFormatted)")
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(expense.isExpense ? theme.expenseColor : theme.incomeColor)
        }
        .padding(14)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

// Wrapper hỗ trợ hiển thị sheet danh sách giao dịch trong ngày
struct DayExpensesIdentifiable: Identifiable {
    let id = UUID()
    let date: Date
    let expenses: [ExpenseItem]
}

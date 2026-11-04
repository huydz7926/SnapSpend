import SwiftUI
import SwiftData

// MARK: - BudgetView

struct BudgetView: View {

    @Query(sort: \ExpenseItem.spentAt, order: .reverse)
    private var allExpenses: [ExpenseItem]

    @Query private var budgets: [MonthlyBudget]

    private let authService = AuthService.shared

    private var currentOwnerUID: String {
        authService.currentOwnerID
    }

    /// Lọc các khoản chi tiêu thuộc sở hữu của người dùng hiện tại
    private var userExpenses: [ExpenseItem] {
        guard !authService.isSignedOut else { return [] }
        return allExpenses.filter { $0.ownerUID == currentOwnerUID }
    }

    /// Lọc ngân sách thuộc sở hữu của người dùng hiện tại
    private var userBudgets: [MonthlyBudget] {
        guard !authService.isSignedOut else { return [] }
        return budgets.filter { $0.ownerUID == currentOwnerUID }
    }

    @State private var selectedYear = BudgetCalculator.currentYear()
    @State private var selectedMonth = BudgetCalculator.currentMonth()
    @State private var showSetupSheet = false

    private let locManager = LocalizationManager.shared

    private var isVN: Bool {
        locManager.currentLanguage == .vietnamese
    }

    private var currentBudget: MonthlyBudget? {
        userBudgets.first { $0.year == selectedYear && $0.month == selectedMonth }
    }

    private var monthSpent: Int64 {
        BudgetCalculator.totalSpent(expenses: userExpenses, year: selectedYear, month: selectedMonth)
    }

    private var totalStatus: BudgetCalculator.BudgetStatus {
        BudgetCalculator.budgetStatus(spent: monthSpent, budget: currentBudget?.totalBudgetVND)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Thanh điều hướng tháng
                monthSelector
                    .padding(.horizontal)

                // Ngân sách tổng
                if let totalBudget = currentBudget?.totalBudgetVND, totalBudget > 0 {
                    BudgetProgressCard(
                        title: isVN ? "Tổng ngân sách tháng" : "Total Monthly Budget",
                        icon: "wallet.pass.fill",
                        iconColor: Color.brandGreen,
                        spent: monthSpent,
                        budget: totalBudget,
                        status: totalStatus
                    )
                    .padding(.horizontal)
                } else {
                    noBudgetCard
                        .padding(.horizontal)
                }

                // Ngân sách theo danh mục
                if let budget = currentBudget, !budget.categoryBudgets.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(isVN ? "Theo danh mục" : "By Category")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(budget.categoryBudgets) { cb in
                            let catSpent = BudgetCalculator.totalSpentInCategory(
                                categoryId: cb.category.id,
                                expenses: userExpenses,
                                year: selectedYear,
                                month: selectedMonth
                            )
                            let catStatus = BudgetCalculator.budgetStatus(spent: catSpent, budget: cb.amountVND)

                            BudgetProgressCard(
                                title: locManager.localizedCategoryName(cb.category.name),
                                icon: cb.category.symbolName,
                                iconColor: cb.category.color,
                                spent: catSpent,
                                budget: cb.amountVND,
                                status: catStatus
                            )
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(locManager.t("tab_budget"))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: authService.currentOwnerID) { _, _ in
            showSetupSheet = false
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(currentBudget == nil ? (isVN ? "Thiết lập" : "Setup") : (isVN ? "Sửa" : "Edit")) {
                    showSetupSheet = true
                }
                .font(.subheadline.weight(.semibold))
            }
        }
        .sheet(isPresented: $showSetupSheet) {
            BudgetSetupView(
                year: selectedYear,
                month: selectedMonth,
                existingBudget: currentBudget
            )
        }
    }

    // MARK: - Month Selector

    private var monthSelector: some View {
        HStack {
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .padding(8)
            }

            Spacer()

            Text(DateHelpers.formatMonthYear(year: selectedYear, month: selectedMonth))
                .font(.headline)

            Spacer()

            Button {
                changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .padding(8)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.secondarySystemBackground))
        .clipShape(Capsule())
    }

    private func changeMonth(by delta: Int) {
        var m = selectedMonth + delta
        var y = selectedYear
        if m < 1 {
            m = 12
            y -= 1
        } else if m > 12 {
            m = 1
            y += 1
        }
        selectedMonth = m
        selectedYear = y
        HapticManager.shared.selectionChanged()
    }

    // MARK: - No Budget Card

    private var noBudgetCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Color.secondary)

            Text(isVN ? "Chưa đặt ngân sách tháng này" : "No budget set for this month")
                .font(.headline)

            Text(isVN
                 ? "Đặt ngân sách giúp bạn kiểm soát chi tiêu và nhận cảnh báo khi chạm ngưỡng 80%."
                 : "Set a budget to track spending and get notified at 80% threshold.")
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)

            Button {
                showSetupSheet = true
            } label: {
                Text(isVN ? "Đặt ngân sách ngay" : "Set Budget Now")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.brandGreen)
                    .clipShape(Capsule())
            }
            .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}


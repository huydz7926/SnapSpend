import SwiftUI
import SwiftData

// MARK: - BudgetSetupView (Nhập Số Tự Nhiên & Nhanh Chóng)

struct BudgetSetupView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let year: Int
    let month: Int
    let existingBudget: MonthlyBudget?

    @Query(sort: \ExpenseCategory.sortOrder)
    private var categories: [ExpenseCategory]

    private var userCategories: [ExpenseCategory] {
        let uid = AuthService.shared.currentOwnerID
        return categories.filter { $0.isDefault || $0.ownerUID == uid }
    }

    @State private var totalBudgetVND: Int64 = 0
    @State private var rawAmountString: String = "5000000"
    @State private var categoryBudgets: [UUID: Int64] = [:]

    @FocusState private var isAmountFocused: Bool

    private let theme = ThemeManager.shared
    private let locManager = LocalizationManager.shared
    private let presetOptions: [Int64] = [3_000_000, 5_000_000, 10_000_000, 15_000_000, 20_000_000]

    private var isVN: Bool {
        locManager.currentLanguage == .vietnamese
    }

    var body: some View {
        NavigationStack {
            Form {
                // Section 1: Hero Card Nhập Số Tự Nhiên
                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(isVN ? "Mục tiêu chi tiêu tháng \(month)/\(year)" : "Spending target for \(month)/\(year)")
                            .font(.subheadline)
                            .foregroundStyle(theme.textSecondary)

                        // Hiển thị số tiền lớn dễ nhìn
                        HStack(alignment: .firstTextBaseline) {
                            Text(totalBudgetVND == 0 ? "0 ₫" : totalBudgetVND.vndFormatted)
                                .font(.system(size: 32, weight: .heavy, design: .rounded))
                                .foregroundStyle(theme.textPrimary)

                            Spacer()

                            Button {
                                isAmountFocused = true
                                HapticManager.shared.selectionChanged()
                            } label: {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(theme.primaryAction)
                            }
                            .buttonStyle(.plain)
                        }

                        // Ô nhập ẩn/hiện mượt mà
                        HStack {
                            Text(isVN ? "Nhập số tiền:" : "Enter amount:")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme.textSecondary)

                            TextField(isVN ? "Số tiền" : "Amount", text: $rawAmountString)
                                .keyboardType(.numberPad)
                                .focused($isAmountFocused)
                                .font(.headline.weight(.bold))
                                .multilineTextAlignment(.trailing)
                                .onChange(of: rawAmountString) { _, newValue in
                                    let clean = newValue.filter { $0.isNumber }
                                    if let val = Int64(clean) {
                                        totalBudgetVND = val
                                    } else if clean.isEmpty {
                                        totalBudgetVND = 0
                                    }
                                }
                        }
                        .padding(10)
                        .background(theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        // Gợi ý mức ngân sách phổ biến
                        VStack(alignment: .leading, spacing: 6) {
                            Text(isVN ? "Mức phổ biến:" : "Popular targets:")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(theme.textSecondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(presetOptions, id: \.self) { amount in
                                        let isSelected = totalBudgetVND == amount
                                        Button {
                                            totalBudgetVND = amount
                                            rawAmountString = "\(amount)"
                                            HapticManager.shared.selectionChanged()
                                        } label: {
                                            Text(shortMillionFormat(amount))
                                                .font(.system(size: 13, weight: isSelected ? .heavy : .semibold, design: .rounded))
                                                .foregroundStyle(isSelected ? Color.white : theme.textPrimary)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 7)
                                                .background(isSelected ? theme.primaryAction : theme.surface)
                                                .clipShape(Capsule())
                                                .shadow(color: Color.black.opacity(0.04), radius: 3, y: 1)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        // Phím cộng thêm nhanh
                        HStack(spacing: 8) {
                            quickAddButton(label: "+500k", addAmount: 500_000)
                            quickAddButton(label: isVN ? "+1 triệu" : "+1M", addAmount: 1_000_000)
                            quickAddButton(label: isVN ? "+2 triệu" : "+2M", addAmount: 2_000_000)

                            Button {
                                totalBudgetVND = 0
                                rawAmountString = ""
                                HapticManager.shared.selectionChanged()
                            } label: {
                                Text(isVN ? "Xoá" : "Clear")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.red)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.red.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text(isVN ? "NGÂN SÁCH TỔNG" : "TOTAL BUDGET")
                } footer: {
                    Text(isVN
                         ? "Bạn có thể chạm vào các gợi ý hoặc nhập nhanh bằng bàn phím."
                         : "Tap presets or type directly using the keyboard.")
                }

                // Section 2: Giới hạn theo danh mục (tuỳ chọn)
                Section(isVN ? "Giới hạn theo danh mục (tuỳ chọn)" : "Category Limits (Optional)") {
                    ForEach(userCategories) { category in
                        categoryBudgetRow(category)
                    }
                }
            }
            .navigationTitle(existingBudget == nil ? (isVN ? "Thiết lập ngân sách" : "Setup Budget") : (isVN ? "Sửa ngân sách" : "Edit Budget"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(locManager.t("action_cancel")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(locManager.t("action_save")) { saveBudget() }
                        .font(.headline)
                        .foregroundStyle(Color.brandGreen)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(locManager.t("action_done")) {
                        isAmountFocused = false
                    }
                    .font(.body.weight(.bold))
                }
            }
            .onAppear {
                loadExistingData()
            }
        }
    }

    private func quickAddButton(label: String, addAmount: Int64) -> some View {
        Button {
            totalBudgetVND += addAmount
            rawAmountString = "\(totalBudgetVND)"
            HapticManager.shared.selectionChanged()
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(theme.primaryAction)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(theme.primaryAction.opacity(0.12))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func shortMillionFormat(_ amount: Int64) -> String {
        let millions = amount / 1_000_000
        return isVN ? "\(millions) triệu" : "\(millions)M"
    }

    private func categoryBudgetRow(_ category: ExpenseCategory) -> some View {
        HStack {
            Image(systemName: category.symbolName)
                .foregroundStyle(category.color)
                .frame(width: 24)

            Text(locManager.localizedCategoryName(category.name))
                .font(.body)

            Spacer()

            let binding = Binding<String>(
                get: {
                    if let val = categoryBudgets[category.id], val > 0 {
                        return "\(val)"
                    }
                    return ""
                },
                set: { str in
                    let clean = str.filter { $0.isNumber }
                    if let val = Int64(clean), val > 0 {
                        categoryBudgets[category.id] = val
                    } else {
                        categoryBudgets[category.id] = nil
                    }
                }
            )

            TextField("0 ₫", text: binding)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(.subheadline.weight(.semibold))
                .frame(width: 110)
        }
    }

    private func loadExistingData() {
        if let budget = existingBudget {
            totalBudgetVND = budget.totalBudgetVND ?? 0
            rawAmountString = totalBudgetVND > 0 ? "\(totalBudgetVND)" : ""
            for cb in budget.categoryBudgets {
                categoryBudgets[cb.category.id] = cb.amountVND
            }
        } else {
            // Mặc định gợi ý 5.000.000 ₫
            totalBudgetVND = 5_000_000
            rawAmountString = "5000000"
        }
    }

    private func saveBudget() {
        let budget: MonthlyBudget
        let currentUID = AuthService.shared.currentOwnerID

        if let existing = existingBudget {
            budget = existing
            budget.totalBudgetVND = totalBudgetVND > 0 ? totalBudgetVND : nil
            budget.ownerUID = currentUID
        } else {
            budget = MonthlyBudget(
                year: year,
                month: month,
                totalBudgetVND: totalBudgetVND > 0 ? totalBudgetVND : nil,
                ownerUID: currentUID
            )
            modelContext.insert(budget)
        }

        // Xóa category budgets cũ và cập nhật mới
        for oldCB in budget.categoryBudgets {
            modelContext.delete(oldCB)
        }
        budget.categoryBudgets.removeAll()

        for (catID, amount) in categoryBudgets where amount > 0 {
            if let cat = categories.first(where: { $0.id == catID }) {
                let cb = CategoryBudget(category: cat, amountVND: amount, monthlyBudget: budget)
                budget.categoryBudgets.append(cb)
            }
        }

        try? modelContext.save()
        HapticManager.shared.savedExpense()
        dismiss()
    }
}

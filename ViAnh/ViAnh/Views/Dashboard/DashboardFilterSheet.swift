import SwiftUI
import SwiftData

// MARK: - DashboardFilterSheet

struct DashboardFilterSheet: View {

    @Binding var selectedCategoryId: UUID?
    @Binding var selectedWalletId: UUID?

    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]

    private var userCategories: [ExpenseCategory] {
        let uid = AuthService.shared.currentOwnerID
        return categories.filter { $0.isDefault || $0.ownerUID == uid }
    }

    @Environment(\.dismiss) private var dismiss
    private let theme = ThemeManager.shared
    private let locManager = LocalizationManager.shared

    var body: some View {
        NavigationStack {
            Form {
                // Mục 1: Lọc theo Danh mục
                Section(locManager.currentLanguage == .vietnamese ? "Danh mục" : "Categories") {
                    Button {
                        selectedCategoryId = nil
                    } label: {
                        HStack {
                            Text(locManager.currentLanguage == .vietnamese ? "Tất cả danh mục" : "All Categories")
                                .foregroundStyle(theme.textPrimary)
                            Spacer()
                            if selectedCategoryId == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(theme.primaryAction)
                            }
                        }
                    }

                    ForEach(userCategories) { cat in
                        Button {
                            selectedCategoryId = cat.id
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: cat.symbolName)
                                    .foregroundStyle(cat.color)
                                    .frame(width: 24)

                                Text(locManager.localizedCategoryName(cat.name))
                                    .foregroundStyle(theme.textPrimary)

                                Spacer()

                                if selectedCategoryId == cat.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(theme.primaryAction)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(locManager.currentLanguage == .vietnamese ? "Bộ lọc" : "Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(locManager.currentLanguage == .vietnamese ? "Đặt lại" : "Reset") {
                        selectedCategoryId = nil
                        selectedWalletId = nil
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(locManager.t("action_done")) {
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.primaryAction)
                }
            }
        }
    }
}


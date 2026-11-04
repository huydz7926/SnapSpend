import SwiftUI
import SwiftData

// MARK: - JournalView

struct JournalView: View {

    @Query(sort: \ExpenseItem.spentAt, order: .reverse)
    private var allExpenses: [ExpenseItem]

    @Query(sort: \ExpenseCategory.sortOrder)
    private var categories: [ExpenseCategory]

    private let authService = AuthService.shared

    private var currentOwnerUID: String {
        authService.currentOwnerID
    }

    private var userExpenses: [ExpenseItem] {
        guard !authService.isSignedOut else { return [] }
        return allExpenses.filter { $0.ownerUID == currentOwnerUID }
    }

    private var userCategories: [ExpenseCategory] {
        categories.filter { $0.isDefault || $0.ownerUID == currentOwnerUID }
    }

    enum ViewMode {
        case grid
        case list
    }

    @State private var viewMode: ViewMode = .grid
    @State private var searchText: String = ""
    @State private var selectedCategoryId: UUID? = nil

    private var filteredExpenses: [ExpenseItem] {
        userExpenses.filter { expense in
            let matchesCategory = selectedCategoryId == nil || expense.category.id == selectedCategoryId
            let matchesSearch = searchText.isEmpty ||
                expense.displayTitle.localizedCaseInsensitiveContains(searchText) ||
                expense.note.localizedCaseInsensitiveContains(searchText)
            return matchesCategory && matchesSearch
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Category Filter Pills
                categoryFilterBar

                // Content Grid hoặc List
                if filteredExpenses.isEmpty {
                    EmptyStateView(
                        symbol: "photo.on.rectangle.angled",
                        title: searchText.isEmpty ? "Chưa có ảnh chi tiêu" : "Không tìm thấy kết quả",
                        message: searchText.isEmpty
                            ? "Các món đồ và hóa đơn bạn chụp lại sẽ xuất hiện dưới dạng album Polaroid tại đây."
                            : "Thử tìm kiếm với từ khóa khác hoặc xóa bộ lọc."
                    )
                    .padding(.top, 40)
                } else {
                    if viewMode == .grid {
                        ExpenseGridView(expenses: filteredExpenses)
                    } else {
                        ExpenseListView(expenses: filteredExpenses)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Nhật ký")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Tìm khoản chi, ghi chú...")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewMode = viewMode == .grid ? .list : .grid
                    }
                    HapticManager.shared.selectionChanged()
                } label: {
                    Image(systemName: viewMode == .grid ? "list.bullet" : "square.grid.2x2")
                        .font(.body.weight(.medium))
                }
                .accessibilityLabel(viewMode == .grid ? "Chuyển sang chế độ danh sách" : "Chuyển sang chế độ lưới ảnh")
            }
        }
    }

    // MARK: - Category Filter Bar

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Pill "Tất cả"
                Button {
                    selectedCategoryId = nil
                    HapticManager.shared.selectionChanged()
                } label: {
                    Text("Tất cả")
                        .font(.subheadline.weight(selectedCategoryId == nil ? .bold : .medium))
                        .foregroundStyle(selectedCategoryId == nil ? .white : Color.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(selectedCategoryId == nil ? Color.brandGreen : Color(.secondarySystemBackground))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                // Các danh mục
                ForEach(userCategories) { category in
                    let isSelected = selectedCategoryId == category.id
                    Button {
                        selectedCategoryId = isSelected ? nil : category.id
                        HapticManager.shared.selectionChanged()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: category.symbolName)
                                .font(.caption.weight(.semibold))
                            Text(category.name)
                                .font(.subheadline.weight(isSelected ? .bold : .medium))
                        }
                        .foregroundStyle(isSelected ? .white : Color.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(isSelected ? category.color : Color(.secondarySystemBackground))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }
}


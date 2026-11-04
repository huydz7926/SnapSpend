import SwiftUI
import SwiftData

// MARK: - CategoryManagementView

struct CategoryManagementView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExpenseCategory.sortOrder)
    private var categories: [ExpenseCategory]

    @State private var showAddOrEditSheet = false
    @State private var categoryToEdit: ExpenseCategory? = nil
    @State private var nameInput = ""
    @State private var symbolInput = "tag"
    @State private var colorInput = "#4ECDC4"

    @State private var categoryToDelete: ExpenseCategory? = nil
    @State private var selectedReplacementId: UUID? = nil
    @State private var errorMessage: String? = nil

    private let availableSymbols = [
        "fork.knife", "bag", "car", "house", "book", "heart",
        "gamecontroller", "cup.and.saucer", "tshirt", "fuelpump",
        "theatermasks", "cart", "gift", "pawprint", "sparkles", "tag"
    ]

    private let availableColors = [
        "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4",
        "#F9CA24", "#DDA0DD", "#98D8C8", "#FF9F43",
        "#10AC84", "#54A0FF", "#5F27CD", "#B0B0B0"
    ]

    var body: some View {
        List {
            Section("Danh mục hệ thống (8 mặc định)") {
                ForEach(categories.filter { $0.isDefault }) { cat in
                    categoryRow(cat, canEditOrDelete: false)
                }
            }

            Section("Danh mục tùy chỉnh") {
                let currentUID = AuthService.shared.currentOwnerID
                let customCats = categories.filter { !$0.isDefault && $0.ownerUID == currentUID }
                if customCats.isEmpty {
                    Text("Chưa có danh mục tự tạo.")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                } else {
                    ForEach(customCats) { cat in
                        categoryRow(cat, canEditOrDelete: true)
                    }
                }
            }
        }
        .navigationTitle("Quản lý danh mục")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    categoryToEdit = nil
                    nameInput = ""
                    symbolInput = "tag"
                    colorInput = "#4ECDC4"
                    showAddOrEditSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddOrEditSheet) {
            addOrEditCategorySheet
        }
        .confirmationDialog(
            "Xác nhận xóa danh mục?",
            isPresented: Binding(
                get: { categoryToDelete != nil },
                set: { if !$0 { categoryToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Xóa & Chuyển sang 'Khác'", role: .destructive) {
                if let cat = categoryToDelete {
                    let fallback = CategoryManager.findOtherCategory(context: modelContext)
                    deleteCategory(cat, replacement: fallback)
                }
            }

            Button("Hủy", role: .cancel) {}
        } message: {
            if let cat = categoryToDelete {
                let count = cat.expenses.count
                if count > 0 {
                    Text("Danh mục này đang có \(count) khoản chi. Các khoản chi sẽ tự động chuyển sang 'Khác' để bảo toàn dữ liệu.")
                } else {
                    Text("Bạn có chắc chắn muốn xóa danh mục này không?")
                }
            } else {
                Text("Hành động này sẽ xóa danh mục đã chọn.")
            }
        }
        .alert("Lỗi", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func categoryRow(_ category: ExpenseCategory, canEditOrDelete: Bool) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(category.color.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: category.symbolName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(category.color)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.body)

                if category.expenses.count > 0 {
                    Text("\(category.expenses.count) khoản chi")
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                }
            }

            Spacer()

            if canEditOrDelete {
                Button {
                    categoryToEdit = category
                    nameInput = category.name
                    symbolInput = category.symbolName
                    colorInput = category.colorHex
                    showAddOrEditSheet = true
                } label: {
                    Image(systemName: "pencil")
                        .foregroundStyle(Color.secondary)
                }
                .buttonStyle(.borderless)

                Button(role: .destructive) {
                    categoryToDelete = category
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(Color.red)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private var addOrEditCategorySheet: some View {
        NavigationStack {
            Form {
                Section("Tên danh mục") {
                    TextField("Nhập tên danh mục...", text: $nameInput)
                }

                Section("Biểu tượng") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(availableSymbols, id: \.self) { symbol in
                            Button {
                                symbolInput = symbol
                                HapticManager.shared.selectionChanged()
                            } label: {
                                Image(systemName: symbol)
                                    .font(.title3)
                                    .frame(width: 40, height: 40)
                                    .background(symbolInput == symbol ? Color.brandGreen.opacity(0.2) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(Color.brandGreen, lineWidth: symbolInput == symbol ? 2 : 0)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Màu sắc") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(availableColors, id: \.self) { hex in
                            Button {
                                colorInput = hex
                                HapticManager.shared.selectionChanged()
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex) ?? .gray)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(Color.primary, lineWidth: colorInput == hex ? 3 : 0)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(categoryToEdit == nil ? "Tạo danh mục mới" : "Chỉnh sửa danh mục")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Hủy") { showAddOrEditSheet = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Lưu") {
                        saveCategory()
                    }
                    .disabled(nameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveCategory() {
        let name = nameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        if let existing = categoryToEdit {
            existing.name = name
            existing.symbolName = symbolInput
            existing.colorHex = colorInput
            try? modelContext.save()
            HapticManager.shared.notifySuccess()
        } else {
            let category = ExpenseCategory(
                name: name,
                symbolName: symbolInput,
                colorHex: colorInput,
                isDefault: false,
                sortOrder: categories.count,
                ownerUID: AuthService.shared.currentOwnerID
            )
            modelContext.insert(category)
            try? modelContext.save()
            HapticManager.shared.savedExpense()
        }

        nameInput = ""
        categoryToEdit = nil
        showAddOrEditSheet = false
    }

    private func deleteCategory(_ category: ExpenseCategory, replacement: ExpenseCategory?) {
        do {
            try CategoryManager.deleteCategory(category, replacementCategory: replacement, context: modelContext)
            HapticManager.shared.deleted()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

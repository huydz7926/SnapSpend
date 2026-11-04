import SwiftUI
import SwiftData

// MARK: - CategoryPickerStep

struct CategoryPickerStep: View {

    @Query(sort: \ExpenseCategory.sortOrder)
    private var categories: [ExpenseCategory]

    private var userCategories: [ExpenseCategory] {
        let uid = AuthService.shared.currentOwnerID
        return categories.filter { $0.isDefault || $0.ownerUID == uid }
    }

    @Binding var selectedCategory: ExpenseCategory?
    @Binding var title: String
    @Binding var note: String
    @Binding var spentAt: Date

    let isSaving: Bool
    let onSave: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Lưới chọn danh mục
                Text("Chọn danh mục")
                    .font(.headline)
                    .padding(.horizontal)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                    ForEach(userCategories) { category in
                        categoryItem(category)
                    }
                }
                .padding(.horizontal)

                Divider()
                    .padding(.vertical, 8)

                // Tên khoản chi (tuỳ chọn)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tên khoản chi (tuỳ chọn)")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)

                    TextField("Ví dụ: Cơm tấm, Cà phê Highlands...", text: $title)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)

                // Ngày giờ phát sinh
                VStack(alignment: .leading, spacing: 8) {
                    Text("Thời điểm chi")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)

                    DatePicker("", selection: $spentAt, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal)

                // Ghi chú (tuỳ chọn)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ghi chú")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)

                    TextField("Thêm ghi chú...", text: $note)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)

                // Nút Lưu
                Button(action: onSave) {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                                .padding(.trailing, 6)
                        }
                        Text("Lưu khoản chi")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(selectedCategory != nil ? Color.brandGreen : Color.secondary.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(selectedCategory == nil || isSaving)
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .padding(.top)
        }
    }

    private func categoryItem(_ category: ExpenseCategory) -> some View {
        let isSelected = selectedCategory?.id == category.id

        return Button {
            HapticManager.shared.selectionChanged()
            selectedCategory = category
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(category.color.opacity(isSelected ? 0.9 : 0.15))
                        .frame(width: 50, height: 50)

                    Image(systemName: category.symbolName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : category.color)
                }

                Text(category.name)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.brandGreen, lineWidth: isSelected ? 2 : 0)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(category.name)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}


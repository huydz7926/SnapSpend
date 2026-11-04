import SwiftUI

// MARK: - RecentExpenseRow

struct RecentExpenseRow: View {

    let expense: ExpenseItem

    var body: some View {
        HStack(spacing: 12) {
            // Icon hoặc thumbnail nhỏ
            Group {
                if let thumb = expense.thumbnailFileName {
                    AsyncThumbnailView(fileName: thumb, category: expense.category)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    ZStack {
                        expense.category.color.opacity(0.15)
                        Image(systemName: expense.category.symbolName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(expense.category.color)
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(expense.displayTitle)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                Text(DateHelpers.relativeDayString(from: expense.spentAt))
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 3) {
                    Text(expense.transactionType.arrowSymbol)
                        .font(.system(size: 13, weight: .bold))

                    Text(expense.amountVND.vndFormatted)
                        .font(.callout.weight(.bold))
                }
                .foregroundStyle(expense.isExpense ? ThemeManager.shared.expenseColor : ThemeManager.shared.incomeColor)

                if let walletName = expense.wallet?.name {
                    Text(walletName)
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(expense.displayTitle), \(expense.amountVND.vndFormatted), ngày \(DateHelpers.relativeDayString(from: expense.spentAt))")
    }
}


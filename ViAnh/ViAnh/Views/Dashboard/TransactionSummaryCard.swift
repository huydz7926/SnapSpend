import SwiftUI

// MARK: - TransactionSummaryCard

/// Cặp 2 thẻ trắng Chi (↗ hồng đỏ) và Thu (↙ xanh lá) đặt cạnh nhau
struct TransactionSummaryCardsRow: View {

    var totalExpense: Int64
    var totalIncome: Int64
    var isMoneyHidden: Bool

    private let theme = ThemeManager.shared
    private let locManager = LocalizationManager.shared

    var body: some View {
        HStack(spacing: 12) {
            // Thẻ Khoản Chi
            singleSummaryCard(
                title: locManager.currentLanguage == .vietnamese ? "Chi" : "Expense",
                symbol: "↗",
                symbolColor: theme.expenseColor,
                amount: totalExpense,
                isIncome: false
            )

            // Thẻ Khoản Thu
            singleSummaryCard(
                title: locManager.currentLanguage == .vietnamese ? "Thu" : "Income",
                symbol: "↙",
                symbolColor: theme.incomeColor,
                amount: totalIncome,
                isIncome: true
            )
        }
        .padding(.horizontal, 20)
    }

    private func singleSummaryCard(
        title: String,
        symbol: String,
        symbolColor: Color,
        amount: Int64,
        isIncome: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Ký hiệu mũi tên + Nhãn
            HStack(spacing: 6) {
                Text(symbol)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(symbolColor)

                Text(title)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.textSecondary)

                Spacer()
            }

            // Số tiền lớn
            Text(displayAmount(amount, isIncome: isIncome))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(theme.surface)
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(theme.separator.opacity(0.5), lineWidth: 0.5)
                }
        }
    }

    private func displayAmount(_ amount: Int64, isIncome: Bool) -> String {
        if isMoneyHidden {
            return "•••••• ₫"
        }
        return amount.vndFormatted
    }
}

#Preview {
    TransactionSummaryCardsRow(
        totalExpense: 460_000,
        totalIncome: 10_000_000,
        isMoneyHidden: false
    )
}


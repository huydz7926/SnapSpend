import SwiftUI

// MARK: - BudgetProgressCard

struct BudgetProgressCard: View {

    let title: String
    let icon: String?
    let iconColor: Color?
    let spent: Int64
    let budget: Int64
    let status: BudgetCalculator.BudgetStatus

    init(
        title: String,
        icon: String? = nil,
        iconColor: Color? = nil,
        spent: Int64,
        budget: Int64,
        status: BudgetCalculator.BudgetStatus
    ) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.spent = spent
        self.budget = budget
        self.status = status
    }

    private let theme = ThemeManager.shared
    private let currencyService = CurrencyExchangeService.shared

    private var ratio: Double {
        guard budget > 0 else { return 0 }
        return Double(spent) / Double(budget)
    }

    private var remaining: Int64 {
        budget - spent
    }

    private var progressColor: Color {
        switch status {
        case .notSet: return theme.textSecondary
        case .safe: return theme.incomeColor
        case .warning: return theme.warningColor
        case .atLimit, .overBudget: return theme.expenseColor
        }
    }

    private var formattedSpent: String {
        currencyService.formatFromVND(spent)
    }

    private var formattedBudget: String {
        currencyService.formatFromVND(budget)
    }

    private var formattedRemaining: String {
        currencyService.formatFromVND(remaining)
    }

    private var formattedOver: String {
        currencyService.formatFromVND(abs(remaining))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 10) {
                if let icon = icon, let color = iconColor {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: icon)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(color)
                        )
                }

                Text(title)
                    .font(.body.weight(.bold))
                    .foregroundStyle(theme.textPrimary)

                Spacer()

                BudgetStatusBadge(status: status)
            }

            // Thanh tiến độ
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.separator.opacity(0.5))
                        .frame(height: 8)

                    Capsule()
                        .fill(progressColor)
                        .frame(width: geo.size.width * CGFloat(min(1.0, ratio)), height: 8)
                }
            }
            .frame(height: 8)

            // Dòng số liệu chi tiết
            HStack(alignment: .firstTextBaseline) {
                let isVN = LocalizationManager.shared.currentLanguage == .vietnamese
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(isVN ? "Đã chi" : "Spent"): \(formattedSpent)")
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(theme.textPrimary)

                    Text("\(isVN ? "Hạn mức" : "Budget"): \(formattedBudget)")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(theme.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    if remaining >= 0 {
                        Text("\(isVN ? "Còn lại" : "Remaining"): \(formattedRemaining)")
                            .font(.system(.footnote, design: .rounded).weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(theme.incomeColor)
                    } else {
                        Text("\(isVN ? "Vượt" : "Over"): +\(formattedOver)")
                            .font(.system(.footnote, design: .rounded).weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(theme.expenseColor)
                    }

                    Text("\(Int(ratio * 100))%")
                        .font(.caption2.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(progressColor)
                }
            }
        }
        .padding(16)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.cardCornerRadius, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

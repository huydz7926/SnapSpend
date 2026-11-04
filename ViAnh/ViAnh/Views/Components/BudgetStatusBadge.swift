import SwiftUI

// MARK: - BudgetStatusBadge

/// Badge hiển thị trạng thái ngân sách với cả icon lẫn chữ (Accessibility WCAG 2.1 AA)
struct BudgetStatusBadge: View {

    let status: BudgetCalculator.BudgetStatus

    private var badgeColor: Color {
        switch status {
        case .notSet: return Color.secondary
        case .safe: return Color.budgetSafe
        case .warning: return Color.budgetWarning
        case .atLimit, .overBudget: return Color.budgetOver
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.symbolName)
                .font(.caption.weight(.bold))

            Text(status.label)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(badgeColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(badgeColor.opacity(0.12))
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Trạng thái ngân sách: \(status.label)")
    }
}


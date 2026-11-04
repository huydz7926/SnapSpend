import SwiftUI

// MARK: - ExpenseListView

struct ExpenseListView: View {

    let expenses: [ExpenseItem]

    private var groupedExpenses: [(key: DateComponents, expenses: [ExpenseItem])] {
        BudgetCalculator.groupByMonth(expenses: expenses)
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 20) {
            ForEach(groupedExpenses, id: \.key) { group in
                let year = group.key.year ?? 0
                let month = group.key.month ?? 0
                let total = group.expenses.reduce(Int64(0)) { $0 + $1.amountVND }

                Section {
                    VStack(spacing: 0) {
                        ForEach(group.expenses) { expense in
                            NavigationLink(destination: ExpenseDetailView(expense: expense)) {
                                RecentExpenseRow(expense: expense)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)

                            if expense.id != group.expenses.last?.id {
                                Divider().padding(.leading, 68)
                            }
                        }
                    }
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                } header: {
                    HStack {
                        Text(DateHelpers.formatMonthYear(year: year, month: month))
                            .font(.headline.weight(.bold))

                        Spacer()

                        Text(total.vndFormatted)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.brandGreen)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(.horizontal)
    }
}


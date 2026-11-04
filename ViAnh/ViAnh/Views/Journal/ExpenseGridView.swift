import SwiftUI

// MARK: - ExpenseGridView

struct ExpenseGridView: View {

    let expenses: [ExpenseItem]

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private var groupedExpenses: [(key: DateComponents, expenses: [ExpenseItem])] {
        BudgetCalculator.groupByMonth(expenses: expenses)
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 24) {
            ForEach(groupedExpenses, id: \.key) { group in
                let year = group.key.year ?? 0
                let month = group.key.month ?? 0
                let total = group.expenses.reduce(Int64(0)) { $0 + $1.amountVND }

                Section {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(group.expenses) { expense in
                            NavigationLink(destination: ExpenseDetailView(expense: expense)) {
                                PolaroidCardView(expense: expense)
                            }
                            .buttonStyle(.plain)
                        }
                    }
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


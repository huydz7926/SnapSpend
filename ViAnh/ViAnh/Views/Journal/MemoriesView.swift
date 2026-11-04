import SwiftUI
import SwiftData

// MARK: - MemoriesView (Tab Kỷ Niệm chuẩn Ảnh 2)

struct MemoriesView: View {

    @Query(sort: \ExpenseItem.spentAt, order: .reverse)
    private var allExpenses: [ExpenseItem]

    @State private var viewMode: MemoryViewMode = .calendar
    @State private var selectedYear: Int = Calendar.current.component(.year, from: .now)
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: .now)
    @State private var selectedExpenseForDetail: ExpenseItem? = nil
    @State private var selectedDayExpenses: DayExpensesIdentifiable? = nil
    @State private var showAddExpense: Bool = false
    @State private var targetAddDate: Date = Date.now

    enum MemoryViewMode {
        case calendar
        case album
    }

    private let theme = ThemeManager.shared
    private let locManager = LocalizationManager.shared
    private let authService = AuthService.shared

    private var currentOwnerUID: String {
        authService.currentOwnerID
    }

    /// Lọc các khoản chi thuộc sở hữu của người dùng hiện tại
    private var userExpenses: [ExpenseItem] {
        guard !authService.isSignedOut else { return [] }
        return allExpenses.filter { $0.ownerUID == currentOwnerUID }
    }

    // Các khoản chi có ảnh chụp thuộc sở hữu của người dùng hiện tại
    private var photoExpenses: [ExpenseItem] {
        userExpenses.filter { $0.thumbnailFileName != nil }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                // Top Header: Tiêu đề Kỷ niệm & Nút đổi chế độ Lịch / Album
                HStack {
                    Text(locManager.t("tab_memories"))
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(theme.textPrimary)

                    Spacer()

                    // Toggle Lịch / Album
                    Button {
                        withAnimation(theme.defaultSpring) {
                            viewMode = (viewMode == .calendar ? .album : .calendar)
                        }
                        HapticManager.shared.selectionChanged()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: viewMode == .calendar ? "square.grid.2x2" : "calendar")
                            Text(locManager.currentLanguage == .vietnamese
                                 ? (viewMode == .calendar ? "Xem Album" : "Xem Lịch")
                                 : (viewMode == .calendar ? "View Album" : "View Calendar"))
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(theme.primaryAction)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(theme.surface)
                        .clipShape(Capsule())
                        .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                if viewMode == .calendar {
                    // Chế độ Lịch Kỷ niệm theo Ảnh 2
                    MemoryCalendarView(
                        year: selectedYear,
                        month: selectedMonth,
                        expenses: userExpenses,
                        allExpenses: userExpenses,
                        isMoneyHidden: false,
                        onAddForDate: { date in
                            targetAddDate = date
                            showAddExpense = true
                        },
                        onSelectDay: { date, items in
                            selectedDayExpenses = DayExpensesIdentifiable(date: date, expenses: items)
                        }
                    )
                } else {
                    // Chế độ Album ảnh kỷ niệm Polaroid
                    if photoExpenses.isEmpty {
                        EmptyStateView(
                            symbol: "photo.on.rectangle.angled",
                            title: locManager.currentLanguage == .vietnamese ? "Chưa có ảnh kỷ niệm" : "No memories yet",
                            message: locManager.currentLanguage == .vietnamese
                                ? "Mỗi khoản chi tiêu bằng ảnh bạn chụp sẽ xuất hiện trong album tại đây."
                                : "Every expense photo you capture will appear in this album."
                        )
                        .padding(.top, 40)
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 14) {
                            ForEach(photoExpenses) { item in
                                Button {
                                    selectedExpenseForDetail = item
                                    HapticManager.shared.selectionChanged()
                                } label: {
                                    polaroidCard(for: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }

                Spacer().frame(height: 36)
            }
        }
        .background(theme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .onChange(of: authService.currentOwnerID) { _, _ in
            selectedExpenseForDetail = nil
            selectedDayExpenses = nil
            showAddExpense = false
        }
        .sheet(item: $selectedExpenseForDetail) { expense in
            ExpenseDetailView(expense: expense)
        }
        .sheet(isPresented: $showAddExpense) {
            AddExpenseView(initialDate: targetAddDate)
        }
        .sheet(item: $selectedDayExpenses) { wrapper in
            NavigationStack {
                List(wrapper.expenses) { expense in
                    Button {
                        selectedDayExpenses = nil
                        selectedExpenseForDetail = expense
                    } label: {
                        RecentExpenseRow(expense: expense)
                    }
                    .buttonStyle(.plain)
                }
                .navigationTitle(
                    locManager.currentLanguage == .vietnamese
                        ? "Ảnh ngày \(DateHelpers.formatFullDate(wrapper.date))"
                        : "Photos on \(DateHelpers.formatFullDate(wrapper.date))"
                )
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    private func polaroidCard(for item: ExpenseItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let thumb = item.thumbnailFileName {
                AsyncThumbnailView(fileName: thumb, category: item.category)
                    .aspectRatio(1, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(CurrencyExchangeService.shared.format(amountVND: item.amountVND, showSign: true, isExpense: item.isExpense))
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(item.isExpense ? theme.expenseColor : theme.incomeColor)

                Text(DateHelpers.formatRelativeDateTime(item.spentAt))
                    .font(.caption2)
                    .foregroundStyle(theme.textSecondary)

                if !item.displayCaption.isEmpty {
                    Text(item.displayCaption)
                        .font(.caption2.italic())
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
        .padding(10)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
    }
}


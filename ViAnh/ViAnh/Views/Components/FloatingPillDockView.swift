import SwiftUI

// MARK: - FloatingPillDockView

/// Floating dock dạng viên thuốc nổi 5 vị trí theo thiết kế SnapSpend
struct FloatingPillDockView: View {

    @Binding var selectedTab: AppTab
    @Binding var showAddExpense: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let theme = ThemeManager.shared

    var body: some View {
        HStack(spacing: 0) {
            // Tab 1: Trang chủ
            dockItem(
                tab: .home,
                title: AppTab.home.title,
                activeIcon: "house.fill",
                inactiveIcon: "house"
            )

            // Tab 2: Kỷ niệm (Lịch & Album ảnh)
            dockItem(
                tab: .memories,
                title: AppTab.memories.title,
                activeIcon: "photo.stack.fill",
                inactiveIcon: "photo.stack"
            )

            // Vị trí 3: Nút [+] nhô cao ở giữa
            centerAddButton

            // Tab 4: Thống kê
            dockItem(
                tab: .analytics,
                title: AppTab.analytics.title,
                activeIcon: "chart.pie.fill",
                inactiveIcon: "chart.pie"
            )

            // Tab 5: Ngân sách
            dockItem(
                tab: .budget,
                title: AppTab.budget.title,
                activeIcon: "creditcard.fill",
                inactiveIcon: "creditcard"
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            Capsule()
                .fill(theme.surface)
                .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 6)
                .overlay {
                    Capsule()
                        .stroke(theme.separator.opacity(0.6), lineWidth: 0.5)
                }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    // MARK: - Dock Tab Item

    private func dockItem(
        tab: AppTab,
        title: String,
        activeIcon: String,
        inactiveIcon: String
    ) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            if reduceMotion {
                selectedTab = tab
            } else {
                withAnimation(theme.defaultSpring) {
                    selectedTab = tab
                }
            }
            HapticManager.shared.selectionChanged()
        } label: {
            VStack(spacing: 3) {
                Image(systemName: isSelected ? activeIcon : inactiveIcon)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? theme.primaryAction : theme.textSecondary)

                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundStyle(isSelected ? theme.primaryAction : theme.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44) // Đảm bảo vùng chạm tối thiểu 44pt theo UI/UX Pro Max
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - Center Plus Button

    private var centerAddButton: some View {
        Button {
            HapticManager.shared.selectionChanged()
            showAddExpense = true
        } label: {
            ZStack {
                Circle()
                    .fill(theme.primaryAction)
                    .frame(width: 52, height: 52)
                    .shadow(color: theme.primaryAction.opacity(0.35), radius: 10, x: 0, y: 5)

                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .offset(y: -12) // Nhô cao lên trên dock
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Thêm khoản chi tiêu mới")
        .accessibilityHint("Mở màn hình chụp ảnh hoặc nhập số tiền")
    }
}


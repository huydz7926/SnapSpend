import SwiftUI
import SwiftData

// MARK: - AppTab Enum

enum AppTab: String, CaseIterable, Identifiable {
    case home      = "home"
    case memories  = "memories"
    case analytics = "analytics"
    case budget    = "budget"

    var id: String { rawValue }

    var translationKey: String {
        switch self {
        case .home:      return "tab_home"
        case .memories:  return "tab_memories"
        case .analytics: return "tab_analytics"
        case .budget:    return "tab_budget"
        }
    }

    @MainActor
    var title: String {
        LocalizationManager.shared.t(translationKey)
    }
}

// MARK: - ContentView (SnapSpend Root)

struct ContentView: View {

    @State private var selectedTab: AppTab = .home
    @State private var showAddExpense = false

    @AppStorage("app_language") private var appLanguage: String = "vi"
    @AppStorage("app_display_currency") private var appCurrency: String = "VND"
    @AppStorage("app_theme_mode") private var appThemeMode: String = "autoTime"
    @AppStorage("app_theme_palette") private var appThemePalette: String = "warmCream"

    private let theme = ThemeManager.shared
    private let authService = AuthService.shared

    var body: some View {
        ZStack {
            // Nền Warm Cream ấm áp toàn app
            theme.background
                .ignoresSafeArea()

            // Nội dung theo Tab
            Group {
                switch selectedTab {
                case .home:
                    NavigationStack {
                        DashboardView()
                    }
                case .memories:
                    NavigationStack {
                        MemoriesView()
                    }
                case .analytics:
                    NavigationStack {
                        AnalyticsView()
                    }
                case .budget:
                    NavigationStack {
                        BudgetView()
                    }
                }
            }
            // Dùng safeAreaInset cạnh dưới để floating dock không che khuất dòng cuối
            .safeAreaInset(edge: .bottom) {
                FloatingPillDockView(
                    selectedTab: $selectedTab,
                    showAddExpense: $showAddExpense
                )
            }
        }
        .id("\(appLanguage)_\(appCurrency)_\(appThemeMode)_\(appThemePalette)_\(authService.currentOwnerID)_\(authService.sessionToken.uuidString)")
        .onChange(of: authService.currentOwnerID) { _, _ in
            showAddExpense = false
        }
        .sheet(isPresented: $showAddExpense) {
            AddExpenseView()
        }
        .fullScreenCover(isPresented: Binding(
            get: { authService.isSignedOut },
            set: { _ in }
        )) {
            AuthWelcomeView()
                .interactiveDismissDisabled(true)
        }
        .preferredColorScheme(theme.preferredColorScheme)
    }
}

// MARK: - Brand Colors Compatibility

extension Color {
    static let brandGreen = Color(hex: "#1B4D3E") ?? .green
    static let brandGreenLight = Color(hex: "#2E7D32") ?? .green
    static let budgetSafe = Color(hex: "#2E7D32") ?? .green
    static let budgetWarning = Color(hex: "#E65100") ?? .orange
    static let budgetOver = Color(hex: "#E84A5F") ?? .red
}

// MARK: - Preview

#if DEBUG
#Preview {
    ContentView()
        .modelContainer(PreviewData.container)
}
#endif
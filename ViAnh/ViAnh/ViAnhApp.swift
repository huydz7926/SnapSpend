import SwiftUI
import SwiftData

// MARK: - ViAnhApp

@main
struct ViAnhApp: App {

    let modelContainer: ModelContainer

    init() {
        // Khai báo toàn bộ models trong schema
        let schema = Schema([
            ExpenseItem.self,
            ExpenseCategory.self,
            MonthlyBudget.self,
            CategoryBudget.self,
            Wallet.self,
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false  // Lưu thật vào disk
        )

        do {
            modelContainer = try ModelContainer(for: schema, configurations: modelConfiguration)
        } catch {
            // Không thể khởi tạo container — crash có kiểm soát với thông báo rõ ràng
            fatalError("Không thể khởi tạo ModelContainer: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
                .onAppear {
                    // Khởi tạo & kiểm tra Firebase Authentication metadata
                    AuthService.shared.configureFirebase()

                    // Seed danh mục và ví mặc định nếu chưa có
                    CategoryManager.seedDefaultCategoriesIfNeeded(
                        context: modelContainer.mainContext
                    )
                    WalletManager.seedDefaultWalletsIfNeeded(
                        context: modelContainer.mainContext
                    )

                    // Phân quyền dữ liệu cũ theo Firebase UID
                    DataOwnerMigrationService.shared.migrateLegacyDataIfNeeded(
                        context: modelContainer.mainContext,
                        activeOwnerID: AuthService.shared.currentOwnerID
                    )
                }
                .onOpenURL { url in
                    print("[SnapSpend] Callback URL nhận được: \(url.absoluteString)")
                }
        }
    }
}

import SwiftUI
import SwiftData

// MARK: - WalletManagementView

struct WalletManagementView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Wallet.sortOrder) private var wallets: [Wallet]
    @Query private var allExpenses: [ExpenseItem]

    private var userWallets: [Wallet] {
        let uid = AuthService.shared.currentOwnerID
        return wallets.filter { $0.isDefault || $0.ownerUID == uid }
    }

    @State private var showAddWallet = false
    @State private var newWalletName = ""
    @State private var newWalletSymbol = "banknote.fill"
    @State private var walletToDelete: Wallet? = nil
    @State private var alertMessage: String? = nil

    private let availableSymbols = [
        "banknote.fill", "creditcard.fill", "building.columns.fill", "wallet.pass.fill",
        "dollarsign.circle.fill", "bag.fill", "cart.fill", "giftcard.fill"
    ]

    private let theme = ThemeManager.shared

    var body: some View {
        List {
            Section {
                ForEach(userWallets) { wallet in
                    walletRow(for: wallet)
                }
            } header: {
                Text("Danh sách tài khoản & Ví")
            } footer: {
                Text("Mỗi khoản thu chi có thể gắn liền với một Ví để quản lý dòng tiền chi tiết.")
            }
        }
        .navigationTitle("Quản lý Ví")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddWallet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                }
            }
        }
        .sheet(isPresented: $showAddWallet) {
            addWalletSheet
        }
        .confirmationDialog(
            "Xóa Ví này?",
            isPresented: Binding(
                get: { walletToDelete != nil },
                set: { if !$0 { walletToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Xóa Ví", role: .destructive) {
                if let w = walletToDelete {
                    deleteWalletSafely(w)
                }
            }
            Button("Hủy", role: .cancel) {}
        } message: {
            Text("Lịch sử giao dịch thuộc Ví này sẽ được tự động chuyển về Ví mặc định (Tiền mặt) để bảo toàn dữ liệu.")
        }
        .alert("Thông báo", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK") {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private func walletRow(for wallet: Wallet) -> some View {
        HStack(spacing: 12) {
            Image(systemName: wallet.symbolName)
                .font(.headline)
                .foregroundStyle(wallet.isDefault ? theme.primaryAction : theme.textPrimary)
                .frame(width: 36, height: 36)
                .background(theme.primaryAction.opacity(wallet.isDefault ? 0.15 : 0.08))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(wallet.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(theme.textPrimary)

                    if wallet.isDefault {
                        Text("Mặc định")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(theme.primaryAction)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(theme.primaryAction.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                Text("\(expensesCount(for: wallet)) giao dịch")
                    .font(.caption2)
                    .foregroundStyle(theme.textSecondary)
            }

            Spacer()

            if !wallet.isDefault {
                Button(role: .destructive) {
                    walletToDelete = wallet
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline)
                        .foregroundStyle(Color.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private func expensesCount(for wallet: Wallet) -> Int {
        let currentUID = AuthService.shared.currentOwnerID
        return allExpenses.filter { $0.wallet?.id == wallet.id && $0.ownerUID == currentUID }.count
    }

    private func deleteWalletSafely(_ wallet: Wallet) {
        guard !wallet.isDefault else {
            alertMessage = "Không thể xóa ví mặc định."
            return
        }

        let fallbackWallet = wallets.first { $0.isDefault } ?? wallets.first

        // Chuyển toàn bộ giao dịch sang ví fallback
        for exp in allExpenses where exp.wallet?.id == wallet.id {
            exp.wallet = fallbackWallet
        }

        modelContext.delete(wallet)
        try? modelContext.save()
        HapticManager.shared.notifySuccess()
    }

    // MARK: - Add Wallet Sheet

    private var addWalletSheet: some View {
        NavigationStack {
            Form {
                Section("Tên Ví / Tài khoản") {
                    TextField("Ví dụ: Thẻ Techcombank, Heo đất...", text: $newWalletName)
                }

                Section("Biểu tượng") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(availableSymbols, id: \.self) { symbol in
                                Image(systemName: symbol)
                                    .font(.title3)
                                    .foregroundStyle(newWalletSymbol == symbol ? Color.white : theme.textPrimary)
                                    .frame(width: 44, height: 44)
                                    .background(newWalletSymbol == symbol ? theme.primaryAction : theme.surface)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(theme.separator, lineWidth: 0.5))
                                    .onTapGesture {
                                        newWalletSymbol = symbol
                                        HapticManager.shared.selectionChanged()
                                    }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Thêm Ví mới")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Hủy") { showAddWallet = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Lưu") {
                        saveNewWallet()
                    }
                    .font(.body.weight(.bold))
                    .foregroundStyle(theme.primaryAction)
                    .disabled(newWalletName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func saveNewWallet() {
        let trimmed = newWalletName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let newWallet = Wallet(
            name: trimmed,
            symbolName: newWalletSymbol,
            colorHex: "#1B4D3E",
            isDefault: false,
            sortOrder: wallets.count,
            ownerUID: AuthService.shared.currentOwnerID
        )

        modelContext.insert(newWallet)
        try? modelContext.save()

        newWalletName = ""
        showAddWallet = false
        HapticManager.shared.notifySuccess()
    }
}

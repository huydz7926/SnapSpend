import SwiftUI
import SwiftData

// MARK: - ExpenseCaptureView (Theo Thiết Kế Mẫu Ảnh 1 & Quản lý Focus Chuẩn)

struct ExpenseCaptureView: View {

    var capturedImage: UIImage?
    var isFromLibrary: Bool = false
    var initialDate: Date = Date.now

    var onRetake: () -> Void
    var onDismiss: () -> Void
    var onSaveSuccess: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]
    @Query private var wallets: [Wallet]
    @Query private var allBudgets: [MonthlyBudget]
    @Query private var allExpenses: [ExpenseItem]

    private let authService = AuthService.shared

    private var currentOwnerUID: String {
        authService.currentOwnerID
    }

    private var userCategories: [ExpenseCategory] {
        categories.filter { $0.isDefault || $0.ownerUID == currentOwnerUID }
    }

    private var userWallets: [Wallet] {
        wallets.filter { $0.isDefault || $0.ownerUID == currentOwnerUID }
    }

    private var userBudgets: [MonthlyBudget] {
        allBudgets.filter { $0.ownerUID == currentOwnerUID }
    }

    private var userExpenses: [ExpenseItem] {
        allExpenses.filter { $0.ownerUID == currentOwnerUID }
    }

    // Form State
    @State private var amountRawString: String = ""
    @State private var transactionType: TransactionType = .expense
    @State private var selectedCategory: ExpenseCategory?
    @State private var selectedWallet: Wallet?
    @State private var spentAtDate: Date = Date.now
    @State private var captionText: String = ""

    // Focus State rõ ràng giữa Số tiền và Caption
    enum CaptureFocusField: Hashable {
        case amount
        case caption
    }
    @FocusState private var focusedField: CaptureFocusField?

    // Sheets & Modals
    @State private var showCategoryPicker = false
    @State private var showWalletPicker = false
    @State private var showDatePicker = false
    @State private var showShareSheet = false
    @State private var isSaving = false

    private let theme = ThemeManager.shared
    private let exchange = CurrencyExchangeService.shared
    private let locManager = LocalizationManager.shared

    private var isVN: Bool {
        locManager.currentLanguage == .vietnamese
    }

    private var currentAmountVND: Int64 {
        let digits = amountRawString.filter { $0.isNumber }
        return Int64(digits) ?? 0
    }

    private var formattedDisplayAmount: String {
        let prefix = transactionType == .expense ? "- " : "+ "
        if currentAmountVND == 0 {
            return "\(prefix)0 \(exchange.displayCurrency.symbol)"
        }
        return "\(prefix)\(VNDFormatter.shared.formatWithoutSymbol(currentAmountVND)) \(exchange.displayCurrency.symbol)"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Nền ấm chuẩn SnapSpend (Ảnh 1)
                theme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Top Bar: Nút Hủy dạng Pill trắng góc trên bên trái
                    HStack {
                        Button {
                            HapticManager.shared.selectionChanged()
                            onDismiss()
                        } label: {
                            Text(locManager.t("action_cancel"))
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.black.opacity(0.8))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(Color.white)
                                .clipShape(Capsule())
                                .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 8)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            // 1. Khung Ảnh bo góc lớn kèm Thẻ Nhập Tiền & Caption đè mép dưới (Ảnh 1)
                            photoWithOverlayCard

                            // 2. Hàng Pill: Danh mục (màu cam nhạt) & Ví tiền (màu xanh lá nhạt)
                            categoryAndWalletPillsRow

                            // 3. Nút Gạt Loại Giao Dịch (Đỏ Chi tiêu ↗ / Xanh Thu nhập ↙)
                            transactionTypeTogglePill

                            // 4. Pill Chọn Ngày (Hôm nay ⌵)
                            datePickerPill
                        }
                        .padding(.bottom, 16)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    // Chạm khoảng trắng ngoài ô nhập cũng đóng bàn phím mà không ảnh hưởng nút bấm
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            if focusedField != nil {
                                focusedField = nil
                            }
                        }
                    )

                    // 5. Thanh Điều Khiển Dưới Cùng: Chụp lại (trái) • Nút Lưu ✓ tròn lớn (giữa) • Chia sẻ (phải)
                    bottomActionBar
                        .padding(.bottom, 16)
                }
            }
            .navigationBarHidden(true)
            .toolbar {
                // Nút "Xong" trên thanh bàn phím hệ thống iPhone: CHỈ đóng bàn phím, KHÔNG thoát màn hình và KHÔNG đổi tab
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button {
                        focusedField = nil
                        HapticManager.shared.selectionChanged()
                    } label: {
                        Text(locManager.t("action_done"))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(theme.primaryAction)
                    }
                }
            }
            .sheet(isPresented: $showCategoryPicker) {
                categorySelectionSheet
            }
            .sheet(isPresented: $showWalletPicker) {
                walletSelectionSheet
            }
            .sheet(isPresented: $showDatePicker) {
                datePickerSheet
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = capturedImage {
                    ShareActivityView(activityItems: [image, "\(formattedDisplayAmount) - \(selectedCategory?.name ?? "")"])
                }
            }
            .onAppear {
                self.spentAtDate = initialDate
                if selectedCategory == nil {
                    selectedCategory = categories.first(where: { $0.isDefault }) ?? categories.first
                }
                if selectedWallet == nil {
                    selectedWallet = wallets.first(where: { $0.isDefault }) ?? wallets.first
                }
            }
        }
    }

    // MARK: - 1. Photo With Overlay Card (Theo Mẫu Ảnh 1)

    private var photoWithOverlayCard: some View {
        ZStack(alignment: .bottom) {
            // Ảnh vừa chụp hoặc Placeholder
            Group {
                if let image = capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 390)
                        .clipped()
                } else {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color(hex: "#222222") ?? Color.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 390)
                        .overlay {
                            VStack(spacing: 8) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 40))
                                    .foregroundStyle(Color.white.opacity(0.6))
                                Text(isVN ? "Khoản chi không kèm ảnh" : "Expense without photo")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.white.opacity(0.8))
                            }
                        }
                }
            }

            // Thẻ Trắng đè lên mép dưới ảnh (Theo phong cách nhập tiền Techcombank)
            VStack(spacing: 12) {
                // Ô Nhập Số tiền trực tiếp với bàn phím số iPhone
                HStack(alignment: .center, spacing: 6) {
                    Text(transactionType == .expense ? "-" : "+")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(transactionType == .expense ? (Color(hex: "#F05656") ?? .red) : (Color(hex: "#2E7D46") ?? .green))

                    ZStack(alignment: .leading) {
                        if amountRawString.isEmpty {
                            Text(LocalizationManager.shared.currentLanguage == .vietnamese ? "Nhập số tiền" : "Enter amount")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.black.opacity(0.28))
                        }

                        TextField("", text: $amountRawString)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .amount)
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.black.opacity(0.88))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: true, vertical: false)
                            .onChange(of: amountRawString) { _, newValue in
                                handleAmountInputChanged(newValue)
                            }
                    }

                    Text(exchange.displayCurrency.symbol)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.5))
                        .padding(.leading, 2)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    focusedField = .amount
                    HapticManager.shared.selectionChanged()
                }

                // Hai nút nhân nhanh "000" và "000,000" (Chỉ hoạt động khi đã có số tiền, tránh 000 vô nghĩa)
                HStack(spacing: 12) {
                    Button {
                        appendZeros(3)
                        HapticManager.shared.selectionChanged()
                    } label: {
                        Text("000")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(currentAmountVND > 0 ? Color.black.opacity(0.75) : Color.black.opacity(0.35))
                            .padding(.horizontal, 22)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.06))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(currentAmountVND <= 0)

                    Button {
                        appendZeros(6)
                        HapticManager.shared.selectionChanged()
                    } label: {
                        Text("000,000")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(currentAmountVND > 0 ? Color.black.opacity(0.75) : Color.black.opacity(0.35))
                            .padding(.horizontal, 22)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.06))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(currentAmountVND <= 0)
                }

                // Ô nhập Caption trực tiếp trên thẻ (Chuyển sang bàn phím chữ hệ thống mượt mà)
                HStack(spacing: 6) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.45))

                    TextField(LocalizationManager.shared.currentLanguage == .vietnamese ? "Thêm chi tiết..." : "Add caption...", text: $captionText)
                        .focused($focusedField, equals: .caption)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.85))
                        .submitLabel(.done)
                        .onSubmit {
                            focusedField = nil
                        }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.04))
                .clipShape(Capsule())
                .padding(.horizontal, 14)
                .contentShape(Rectangle())
                .onTapGesture {
                    focusedField = .caption
                    HapticManager.shared.selectionChanged()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(0.08), radius: 8, y: 3)
            .padding(10)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(.horizontal, 16)
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
    }

    private func handleAmountInputChanged(_ newValue: String) {
        let digits = newValue.filter { $0.isNumber }
        if digits.isEmpty {
            if !amountRawString.isEmpty {
                amountRawString = ""
            }
            return
        }

        // Bỏ số 0 thừa ở đầu (ví dụ "035" -> "35")
        guard let number = Int64(digits) else { return }
        let formatted = VNDFormatter.shared.formatWithoutSymbol(number)
        if amountRawString != formatted {
            amountRawString = formatted
        }
    }

    private func appendZeros(_ count: Int) {
        guard currentAmountVND > 0 else {
            // Khi rỗng hoặc bằng 0: Không tạo chuỗi số 0 vô nghĩa
            return
        }
        let multiplier: Int64 = count == 3 ? 1_000 : 1_000_000
        let newAmount = currentAmountVND * multiplier
        amountRawString = VNDFormatter.shared.formatWithoutSymbol(newAmount)
    }

    // MARK: - 2. Category & Wallet Pills Row (Ảnh 1)

    private var categoryAndWalletPillsRow: some View {
        HStack(spacing: 12) {
            // Pill Danh mục: Màu cam nhạt (Ảnh 1)
            Button {
                focusedField = nil
                showCategoryPicker = true
                HapticManager.shared.selectionChanged()
            } label: {
                HStack(spacing: 6) {
                    if let cat = selectedCategory {
                        Image(systemName: cat.symbolName)
                            .font(.system(size: 14, weight: .semibold))
                        Text(locManager.localizedCategoryName(cat.name))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    } else {
                        Text(locManager.t("cat_food"))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(Color(hex: "#D85827") ?? .orange)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Color(hex: "#FDE8DE") ?? Color.orange.opacity(0.15))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            // Pill Ví tiền: Màu xanh lá nhạt (Ảnh 1)
            Button {
                focusedField = nil
                showWalletPicker = true
                HapticManager.shared.selectionChanged()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "creditcard")
                        .font(.system(size: 14, weight: .semibold))
                    Text(selectedWallet?.name ?? (isVN ? "Ví tiền" : "Wallet"))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(Color(hex: "#2E7D46") ?? .green)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Color(hex: "#E2F4E7") ?? Color.green.opacity(0.15))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 3. Transaction Type Toggle Pill (Ảnh 1)

    private var transactionTypeTogglePill: some View {
        HStack(spacing: 12) {
            // Chi tiêu (Mũi tên chéo lên đỏ)
            Button {
                focusedField = nil
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    transactionType = .expense
                }
                HapticManager.shared.selectionChanged()
            } label: {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(transactionType == .expense ? Color.white : Color.black.opacity(0.35))
                    .frame(width: 44, height: 44)
                    .background(transactionType == .expense ? Color(hex: "#F05656") ?? .red : Color.clear)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            // Thu nhập (Mũi tên chéo xuống)
            Button {
                focusedField = nil
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    transactionType = .income
                }
                HapticManager.shared.selectionChanged()
            } label: {
                Image(systemName: "arrow.down.left")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(transactionType == .income ? Color.white : Color.black.opacity(0.35))
                    .frame(width: 44, height: 44)
                    .background(transactionType == .income ? Color(hex: "#2E7D46") ?? .green : Color.clear)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(5)
        .background(Color.white)
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
    }

    // MARK: - 4. Date Picker Pill (Ảnh 1)

    private var datePickerPill: some View {
        Button {
            focusedField = nil
            showDatePicker = true
            HapticManager.shared.selectionChanged()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 14, weight: .semibold))
                Text(DateHelpers.relativeDayString(from: spentAtDate))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(Color.black.opacity(0.75))
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.white)
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.05), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 5. Bottom Action Bar (Ảnh 1)

    private var bottomActionBar: some View {
        HStack {
            // Nút "Chụp lại" (trái)
            Button {
                focusedField = nil
                HapticManager.shared.selectionChanged()
                onRetake()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "camera.rotate")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.55))
                        .frame(width: 52, height: 52)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.05), radius: 4, y: 1)

                    Text(locManager.t("action_retake"))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.5))
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Nút Lưu Checkmark lớn ở chính giữa (Ảnh 1: Chỉ nút này mới lưu)
            Button {
                focusedField = nil
                saveExpense()
            } label: {
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 72, height: 72)

                    Circle()
                        .fill(currentAmountVND > 0 ? (Color(hex: "#2E7D46") ?? Color.brandGreen) : Color.black.opacity(0.2))
                        .frame(width: 62, height: 62)

                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(Color.white)
                    }
                }
                .shadow(color: Color.black.opacity(0.12), radius: 6, y: 3)
            }
            .buttonStyle(.plain)
            .disabled(isSaving || currentAmountVND <= 0)

            Spacer()

            // Nút "Chia sẻ" (phải)
            Button {
                focusedField = nil
                showShareSheet = true
                HapticManager.shared.selectionChanged()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.55))
                        .frame(width: 52, height: 52)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.05), radius: 4, y: 1)

                    Text(locManager.t("action_share"))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.5))
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 36)
    }

    // MARK: - Save Expense

    private func saveExpense() {
        guard !isSaving, currentAmountVND > 0 else { return }
        isSaving = true
        HapticManager.shared.savedExpense()

        // Ghi nhận chính xác UID và Session Token của phiên làm việc lúc bắt đầu lưu
        let targetOwnerUID = authService.currentOwnerID
        let startingSessionToken = authService.sessionToken

        Task {
            var imageFileName: String? = nil
            var thumbnailFileName: String? = nil

            if let image = capturedImage {
                do {
                    let (imgName, thumbName) = try await ImageStorageService.shared.save(image: image)
                    imageFileName = imgName
                    thumbnailFileName = thumbName
                } catch {
                    print("Lỗi lưu ảnh: \(error.localizedDescription)")
                }
            }

            await MainActor.run {
                // Kiểm tra an toàn: Nếu người dùng đã đăng xuất hoặc chuyển sang tài khoản khác, hủy lưu để tránh ghi nhầm
                guard authService.sessionToken == startingSessionToken && authService.currentOwnerID == targetOwnerUID else {
                    print("[SnapSpend] Phiên đăng nhập đã thay đổi trong khi lưu ảnh. Hủy lưu để bảo vệ dữ liệu.")
                    if let img = imageFileName, let thumb = thumbnailFileName {
                        Task.detached {
                            await ImageStorageService.shared.delete(imageFileName: img, thumbnailFileName: thumb)
                        }
                    }
                    isSaving = false
                    return
                }

                guard let category = selectedCategory ?? userCategories.first else {
                    if let img = imageFileName, let thumb = thumbnailFileName {
                        Task.detached {
                            await ImageStorageService.shared.delete(imageFileName: img, thumbnailFileName: thumb)
                        }
                    }
                    isSaving = false
                    return
                }

                let source = isFromLibrary ? "library" : (capturedImage != nil ? "camera" : "none")
                let captureDate: Date? = (capturedImage != nil && !isFromLibrary) ? Date.now : nil
                let targetWallet = selectedWallet ?? userWallets.first { $0.isDefault } ?? userWallets.first

                let newExpense = ExpenseItem(
                    amountVND: currentAmountVND,
                    category: category,
                    spentAt: spentAtDate,
                    title: category.name,
                    note: captionText,
                    type: transactionType,
                    wallet: targetWallet,
                    photoSource: source,
                    capturedAt: captureDate,
                    caption: captionText,
                    ownerUID: targetOwnerUID
                )
                newExpense.imageFileName = imageFileName
                newExpense.thumbnailFileName = thumbnailFileName

                modelContext.insert(newExpense)
                try? modelContext.save()

                // Kiểm tra ngưỡng cảnh báo ngân sách của user hiện tại
                let calendar = Calendar.current
                let y = calendar.component(.year, from: newExpense.spentAt)
                let m = calendar.component(.month, from: newExpense.spentAt)
                let matchingBudget = userBudgets.first { $0.year == y && $0.month == m }
                NotificationManager.shared.checkBudgetThresholds(
                    expenses: userExpenses + [newExpense],
                    budget: matchingBudget,
                    triggerExpense: newExpense
                )

                isSaving = false
                onSaveSuccess()
            }
        }
    }

    // MARK: - Modals & Pickers

    private var categorySelectionSheet: some View {
        NavigationStack {
            List(userCategories) { cat in
                Button {
                    selectedCategory = cat
                    showCategoryPicker = false
                    HapticManager.shared.selectionChanged()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: cat.symbolName)
                            .foregroundStyle(cat.color)
                            .frame(width: 28, height: 28)
                            .background(cat.color.opacity(0.15))
                            .clipShape(Circle())

                        Text(locManager.localizedCategoryName(cat.name))
                            .foregroundStyle(theme.textPrimary)

                        Spacer()

                        if selectedCategory?.id == cat.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(theme.primaryAction)
                        }
                    }
                }
            }
            .navigationTitle(isVN ? "Chọn danh mục" : "Select Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(locManager.t("action_done")) { showCategoryPicker = false }
                }
            }
        }
    }

    private var walletSelectionSheet: some View {
        NavigationStack {
            List(userWallets) { wallet in
                Button {
                    selectedWallet = wallet
                    showWalletPicker = false
                    HapticManager.shared.selectionChanged()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "creditcard")
                            .foregroundStyle(theme.primaryAction)

                        Text(wallet.name)
                            .foregroundStyle(theme.textPrimary)

                        Spacer()

                        if selectedWallet?.id == wallet.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(theme.primaryAction)
                        }
                    }
                }
            }
            .navigationTitle(isVN ? "Chọn ví" : "Select Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(locManager.t("action_done")) { showWalletPicker = false }
                }
            }
        }
    }

    private var datePickerSheet: some View {
        NavigationStack {
            VStack {
                DatePicker(isVN ? "Thời gian" : "Date & Time", selection: $spentAtDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
                    .padding()
                Spacer()
            }
            .navigationTitle(isVN ? "Chọn ngày giờ" : "Select Date & Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(locManager.t("action_done")) { showDatePicker = false }
                }
            }
        }
    }
}

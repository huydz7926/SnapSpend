import SwiftUI
import SwiftData
import Photos

// MARK: - PhotoSaver Helper

final class PhotoSaver: NSObject {
    var onSuccess: (() -> Void)?
    var onError: ((Error) -> Void)?

    func writeToPhotoAlbum(image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveCompleted), nil)
    }

    @objc func saveCompleted(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            onError?(error)
        } else {
            onSuccess?()
        }
    }
}

// MARK: - ExpenseDetailView (Chuẩn Ảnh 1)

struct ExpenseDetailView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var expense: ExpenseItem

    @Query(sort: \ExpenseCategory.sortOrder)
    private var categories: [ExpenseCategory]

    private var userCategories: [ExpenseCategory] {
        let uid = AuthService.shared.currentOwnerID
        return categories.filter { $0.isDefault || $0.ownerUID == uid }
    }

    @State private var fullImage: UIImage? = nil
    @State private var isLoadingImage: Bool = true
    @State private var showFullScreenPhoto = false
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var alertMessage: String? = nil

    private let theme = ThemeManager.shared
    private let locManager = LocalizationManager.shared

    private var isVN: Bool {
        locManager.currentLanguage == .vietnamese
    }

    var body: some View {
        VStack(spacing: 0) {
            // 1. Top Navigation Bar
            topNavigationBar
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 18) {
                    // 2. Thẻ ảnh lớn bo góc có số tiền đè lên ảnh
                    photoCardView
                        .padding(.horizontal, 16)

                    // 3. Các pill thông tin bên dưới ảnh (không có Ví)
                    infoPillsSection
                        .padding(.horizontal, 20)

                    // 4. Các nút tác vụ phụ (Lưu ảnh vào thư viện, Chia sẻ)
                    actionButtonsRow
                        .padding(.horizontal, 20)
                        .padding(.top, 4)

                    Spacer().frame(height: 24)
                }
                .padding(.top, 4)
            }
        }
        .background(theme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .task {
            await loadPhotoIfNeeded()
        }
        .fullScreenCover(isPresented: $showFullScreenPhoto) {
            if let img = fullImage {
                FullScreenImageViewer(image: img, date: expense.spentAt) {
                    showFullScreenPhoto = false
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditExpenseSheet(expense: expense, categories: userCategories)
        }
        .onChange(of: AuthService.shared.currentOwnerID) { _, _ in
            dismiss()
        }
        .confirmationDialog(
            isVN ? "Xác nhận xóa giao dịch?" : "Delete Transaction?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(isVN ? "Xóa giao dịch" : "Delete Transaction", role: .destructive) {
                deleteExpense()
            }
            Button(locManager.t("action_cancel"), role: .cancel) {}
        } message: {
            Text(isVN
                 ? "Khoản giao dịch và ảnh chụp liên quan sẽ bị xóa vĩnh viễn khỏi thiết bị."
                 : "This transaction and its associated photo will be permanently deleted.")
        }
        .alert(isVN ? "Thông báo" : "Notice", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK") {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    // MARK: - Top Navigation Bar (Ảnh 1)

    private var topNavigationBar: some View {
        HStack {
            // Nút Quay lại tròn
            Button {
                dismiss()
            } label: {
                Image(systemName: "arrow.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(theme.surface)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            Spacer()

            // Pill Tiêu đề: "Giao dịch ⌵"
            HStack(spacing: 4) {
                Text(isVN ? "Giao dịch" : "Transaction")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(theme.textPrimary)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(theme.surface)
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)

            Spacer()

            // Hai nút tròn Sửa & Xóa
            HStack(spacing: 8) {
                // Sửa
                Button {
                    showEditSheet = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(theme.surface)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                }
                .buttonStyle(.plain)

                // Xóa
                Button {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.red)
                        .frame(width: 44, height: 44)
                        .background(theme.surface)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Photo Card View (Ảnh 1: Ảnh lớn bo góc + Số tiền đè gần mép dưới)

    private var photoCardView: some View {
        ZStack(alignment: .bottom) {
            // Ảnh hoặc Placeholder
            Group {
                if let img = fullImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 390)
                        .clipped()
                } else if isLoadingImage {
                    Rectangle()
                        .fill(theme.surface)
                        .frame(height: 390)
                        .overlay(ProgressView())
                } else {
                    // Không có ảnh: Thẻ màu ấm với icon danh mục lớn
                    ZStack {
                        theme.surface
                        VStack(spacing: 12) {
                            Image(systemName: expense.category.symbolName)
                                .font(.system(size: 64, weight: .light))
                                .foregroundStyle(expense.category.color)
                            Text(expense.displayTitle)
                                .font(.headline)
                                .foregroundStyle(theme.textPrimary)
                            Text(isVN ? "Khoản chi không kèm ảnh" : "Expense without photo")
                                .font(.caption)
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                    .frame(height: 390)
                }
            }

            // Dải Gradient mờ mép dưới để số tiền luôn nổi bật trên mọi ảnh
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.15),
                    Color.black.opacity(0.75)
                ],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(height: 180)

            // Số tiền lớn đè ở gần mép dưới ảnh (ví dụ: -455.000 ₫)
            VStack(spacing: 6) {
                HStack(spacing: 2) {
                    Text(expense.isExpense ? "-\(formatRawAmount(expense.amountVND))" : "+\(formatRawAmount(expense.amountVND))")
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.white)

                    Text(" ₫")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .underline()
                        .foregroundStyle(Color.white)
                }
                .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 3)
            }
            .padding(.bottom, 24)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 6)
        .contentShape(Rectangle())
        .onTapGesture {
            if fullImage != nil {
                showFullScreenPhoto = true
            }
        }
    }

    private func formatRawAmount(_ val: Int64) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "."
        return f.string(from: NSNumber(value: val)) ?? "\(val)"
    }

    // MARK: - Info Pills Section (Ảnh 1)

    private var infoPillsSection: some View {
        VStack(spacing: 10) {
            // Hàng 1: Pill Danh mục (Không có Ví)
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: expense.category.symbolName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(expense.category.color)

                    Text(locManager.localizedCategoryName(expense.category.name))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(expense.category.color)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(expense.category.color.opacity(0.14))
                .clipShape(Capsule())

                Spacer()
            }

            // Hàng 2: Pill Ngày giờ + Pill Caption (nếu có)
            HStack(spacing: 8) {
                // Ngày giờ: "📅 Hôm qua, 23:07"
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.textSecondary)

                    Text(DateHelpers.formatRelativeDateTime(expense.spentAt))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(theme.surface)
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)

                // Caption: "🌐 Caption..."
                if !expense.displayCaption.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "globe")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.brandGreenLight)

                        Text(expense.displayCaption)
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(Color.brandGreenLight)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.brandGreenLight.opacity(0.12))
                    .clipShape(Capsule())
                }

                Spacer()
            }
        }
    }

    // MARK: - Action Buttons Row

    private var actionButtonsRow: some View {
        HStack(spacing: 12) {
            // Nút Lưu ảnh vào Thư viện
            if let img = fullImage {
                Button {
                    savePhotoToAlbum(image: img)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.to.line.circle.fill")
                        Text(locManager.t("action_save_photo"))
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(theme.primaryAction)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(theme.surface)
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
                }
                .buttonStyle(.plain)
            }

            // Nút Chia sẻ
            if let img = fullImage {
                ShareLink(
                    item: Image(uiImage: img),
                    preview: SharePreview("Chi tiêu: \(expense.amountVND.vndFormatted)", image: Image(uiImage: img))
                ) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                        Text(locManager.t("action_share"))
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(theme.surface)
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
    }

    // MARK: - Photo Actions & Helpers

    private func loadPhotoIfNeeded() async {
        guard let fileName = expense.imageFileName else {
            isLoadingImage = false
            return
        }

        let loaded = await ImageStorageService.shared.loadFullImage(fileName: fileName)
        await MainActor.run {
            self.fullImage = loaded
            self.isLoadingImage = false
        }
    }

    private func savePhotoToAlbum(image: UIImage) {
        let saver = PhotoSaver()
        saver.onSuccess = {
            alertMessage = "Đã lưu ảnh vào Thư viện ảnh thành công!"
            HapticManager.shared.notifySuccess()
        }
        saver.onError = { error in
            alertMessage = "Không thể lưu ảnh: \(error.localizedDescription)"
        }
        saver.writeToPhotoAlbum(image: image)
    }

    private func deleteExpense() {
        // Xóa ảnh vật lý khỏi đĩa Application Support
        let imgName = expense.imageFileName
        let thumbName = expense.thumbnailFileName
        Task {
            await ImageStorageService.shared.delete(imageFileName: imgName, thumbnailFileName: thumbName)
        }

        modelContext.delete(expense)
        try? modelContext.save()
        HapticManager.shared.deleted()
        dismiss()
    }
}

// MARK: - FullScreenImageViewer (Theo Thiết Kế Mẫu Ảnh 3)

struct FullScreenImageViewer: View {
    let image: UIImage
    var date: Date = Date.now
    var onDismiss: () -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var reactionText: String = ""
    @State private var tappedReaction: String? = nil

    private let emojisRow1 = ["💕", "😂", "🥰", "😱", "😍"]
    private let emojisRow2 = ["😋", "💛", "🫶", "🥳", "+"]

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "h:mm a"
        let str = formatter.string(from: date)
        return str.replacingOccurrences(of: "AM", with: "SA").replacingOccurrences(of: "PM", with: "CH")
    }

    var body: some View {
        ZStack {
            Color(hex: "#121212")?.ignoresSafeArea() ?? Color.black.ignoresSafeArea()

            VStack(spacing: 12) {
                // Mũi tên trượt xuống trên cùng (Ảnh 3)
                Button {
                    HapticManager.shared.selectionChanged()
                    onDismiss()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                // Khung Ảnh bo góc gọn gàng không bị tràn màn hình (Ảnh 3)
                ZStack(alignment: .bottom) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 390)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .shadow(color: Color.black.opacity(0.4), radius: 12, y: 4)

                    // Pill thời gian ở góc dưới ảnh: 🕒 12:41 SA (Ảnh 3)
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 13, weight: .bold))
                        Text(formattedTime)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.black.opacity(0.65))
                    .clipShape(Capsule())
                    .padding(.bottom, 14)
                }
                .padding(.horizontal, 16)
                .offset(y: max(0, dragOffset.height))
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            if gesture.translation.height > 0 {
                                dragOffset = gesture.translation
                            }
                        }
                        .onEnded { gesture in
                            if gesture.translation.height > 100 {
                                onDismiss()
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    dragOffset = .zero
                                }
                            }
                        }
                )

                Spacer(minLength: 0)

                // Vùng tương tác bên dưới ảnh (Ảnh 3: Avatar + 2 Hàng Emoji + Ô Tin nhắn)
                VStack(spacing: 12) {
                    // Avatar nhỏ
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 38, height: 38)
                        .overlay {
                            Image(systemName: "person.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Color.white.opacity(0.85))
                        }

                    // Hàng emoji 1
                    HStack(spacing: 18) {
                        ForEach(emojisRow1, id: \.self) { emoji in
                            Button {
                                HapticManager.shared.savedExpense()
                                tappedReaction = emoji
                            } label: {
                                Text(emoji)
                                    .font(.system(size: 26))
                                    .scaleEffect(tappedReaction == emoji ? 1.25 : 1.0)
                                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: tappedReaction)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Hàng emoji 2
                    HStack(spacing: 18) {
                        ForEach(emojisRow2, id: \.self) { emoji in
                            Button {
                                HapticManager.shared.savedExpense()
                                tappedReaction = emoji
                            } label: {
                                if emoji == "+" {
                                    Image(systemName: "face.smiling")
                                        .font(.system(size: 24))
                                        .foregroundStyle(Color.white.opacity(0.85))
                                } else {
                                    Text(emoji)
                                        .font(.system(size: 26))
                                        .scaleEffect(tappedReaction == emoji ? 1.25 : 1.0)
                                        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: tappedReaction)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Ô "Tin nhắn..."
                    HStack {
                        TextField("Tin nhắn...", text: $reactionText)
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(Color.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                    .padding(.horizontal, 24)
                    .padding(.bottom, 10)
                }
            }
        }
    }
}

// MARK: - EditExpenseSheet

struct EditExpenseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var expense: ExpenseItem
    let categories: [ExpenseCategory]

    @State private var amountString: String
    @State private var transactionType: TransactionType
    @State private var selectedCategory: ExpenseCategory
    @State private var spentAtDate: Date
    @State private var captionText: String

    enum EditField: Hashable {
        case amount
        case caption
    }
    @FocusState private var focusedField: EditField?

    init(expense: ExpenseItem, categories: [ExpenseCategory]) {
        self.expense = expense
        self.categories = categories
        _amountString = State(initialValue: VNDFormatter.shared.formatWithoutSymbol(expense.amountVND))
        _transactionType = State(initialValue: expense.type)
        _selectedCategory = State(initialValue: expense.category)
        _spentAtDate = State(initialValue: expense.spentAt)
        _captionText = State(initialValue: expense.caption)
    }

    var body: some View {
        let isVN = LocalizationManager.shared.currentLanguage == .vietnamese
        NavigationStack {
            Form {
                Section(isVN ? "Loại & Số tiền" : "Type & Amount") {
                    Picker(isVN ? "Loại giao dịch" : "Transaction Type", selection: $transactionType) {
                        Text(isVN ? "Khoản chi ↗" : "Expense ↗").tag(TransactionType.expense)
                        Text(isVN ? "Khoản thu ↙" : "Income ↙").tag(TransactionType.income)
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Text(isVN ? "Số tiền VND" : "Amount VND")
                        Spacer()
                        TextField("0", text: $amountString)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .amount)
                            .multilineTextAlignment(.trailing)
                            .font(.headline.weight(.bold))
                            .onChange(of: amountString) { _, newValue in
                                let digits = newValue.filter { $0.isNumber }
                                if let val = Int64(digits), val > 0 {
                                    let formatted = VNDFormatter.shared.formatWithoutSymbol(val)
                                    if amountString != formatted {
                                        amountString = formatted
                                    }
                                } else if digits.isEmpty {
                                    amountString = ""
                                }
                            }
                    }
                }

                Section(isVN ? "Danh mục" : "Category") {
                    Picker(isVN ? "Danh mục" : "Category", selection: $selectedCategory) {
                        ForEach(categories) { cat in
                            HStack {
                                Image(systemName: cat.symbolName)
                                    .foregroundStyle(cat.color)
                                Text(LocalizationManager.shared.localizedCategoryName(cat.name))
                            }
                            .tag(cat)
                        }
                    }
                }

                Section(isVN ? "Thời gian phát sinh" : "Date & Time") {
                    DatePicker(isVN ? "Thời điểm" : "Date & Time", selection: $spentAtDate, displayedComponents: [.date, .hourAndMinute])
                }

                Section(isVN ? "Caption / Ghi chú" : "Caption / Note") {
                    TextField(isVN ? "Viết caption cho bức ảnh..." : "Write a caption for this photo...", text: $captionText, axis: .vertical)
                        .focused($focusedField, equals: .caption)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle(isVN ? "Sửa giao dịch" : "Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button {
                        focusedField = nil
                        HapticManager.shared.selectionChanged()
                    } label: {
                        Text(LocalizationManager.shared.t("action_done"))
                            .font(.headline)
                            .foregroundStyle(Color.brandGreen)
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
                    Button(LocalizationManager.shared.t("action_cancel")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LocalizationManager.shared.t("action_save")) {
                        saveChanges()
                    }
                    .font(.body.weight(.bold))
                    .foregroundStyle(Color.brandGreen)
                }
            }
        }
    }

    private func saveChanges() {
        let clean = amountString.filter { $0.isNumber }
        if let newAmount = Int64(clean), newAmount > 0 {
            expense.amountVND = newAmount
        }
        expense.type = transactionType
        expense.category = selectedCategory
        expense.spentAt = spentAtDate
        expense.caption = captionText
        expense.note = captionText
        expense.markUpdated()

        try? modelContext.save()
        HapticManager.shared.savedExpense()
        dismiss()
    }
}

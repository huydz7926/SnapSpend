# SPEC.md — Ví Ảnh (Photo Expense Diary)
> Phiên bản: 1.0 MVP | Ngày: 2026-11-02  
> Được soạn bởi: Claude Opus 5.5 (Nhạc trưởng) + Gemini 3.8 Flash (UI Consultant)

---

## 1. TẦM NHÌN SẢN PHẨM

**Định vị:** "Nhật ký chi tiêu bằng ảnh" — ghi chi tiêu nhanh bằng cách chụp ảnh, không phải điền form.

**Đối tượng:** Sinh viên và người trẻ Việt (18–30 tuổi), ưu tiên trực quan, ngại giao diện tài chính phức tạp.

**USP (Unique Selling Point) vượt App Store Review Guideline 4.2:**
- Giao diện Polaroid card — cảm giác "album ký ức" thay vì spreadsheet
- Smart VND Chips — nhập tiền Việt Nam chỉ bằng 1–2 chạm
- Haptic Feedback — phản hồi xúc giác khi lưu, chọn danh mục, chạm ngưỡng ngân sách

---

## 2. QUYẾT ĐỊNH PHIÊN BẢN iOS TỐI THIỂU

**Chọn: iOS 17.0**

| Tiêu chí | iOS 16 | iOS 17 (chọn) | iOS 18 |
|---|---|---|---|
| SwiftData | ❌ Không có | ✅ Ra đời cùng iOS 17 | ✅ Cải thiện thêm |
| PhotosPicker (không cần quyền) | ⚠️ Hạn chế | ✅ Đầy đủ | ✅ |
| .scrollContentBackground | ✅ | ✅ | ✅ |
| Adoption rate (2025) | ~5% | ~85%+ | ~60% |

**Lý do:** SwiftData chỉ có từ iOS 17. Adoption rate iOS 17+ đã vượt 85% → không đáng hi sinh để hỗ trợ iOS 16.

---

### Ghi chú bổ sung về FAB (Issue 4 — đã đánh giá kỹ):

> **Quyết định cuối cùng về Center FAB:**  
> Gemini đề cập việc đè lên native TabView gây vấn đề VoiceOver và iOS 18 floating tab bar.  
> **Giải pháp:** Xây dựng **Custom TabBar hoàn toàn** (không dùng SwiftUI TabView mặc định) để kiểm soát hoàn toàn layout, accessibility và iOS version compatibility. Center button sẽ là UIButton riêng với proper accessibilityLabel.

```
NavigationStructure:
ContentView
└── CustomTabBarView (ZStack)
    ├── Trang nội dung (theo tab đang chọn)
    └── CustomTabBar (absolute bottom, safe area aware)
        ├── Tab: Tổng quan
        ├── Tab: Nhật ký  
        ├── AddButton (raised, NOT a real tab)
        ├── Tab: Ngân sách
        └── Tab: Cài đặt
```


### Kết quả đánh giá từ UI Consultant (Gemini):
- ✅ **4 tab + Hero Center Button** là cấu trúc tối ưu
- ✅ **FAB ở chính giữa Tab Bar** (như Instagram, BeReal) — tối ưu vùng ngón cái cả 2 tay
- ✅ **Không thêm tab Lịch** — tích hợp vào Nhật ký dưới dạng Segmented Control
- ✅ **2 cột** cho Polaroid Grid
- ✅ **3–4 Smart VND Chips ngang** trên inputAccessoryView

### Sơ đồ điều hướng:
```
TabBar (5 items):
├── [🏠] Tổng quan        ← Tab 1
├── [📔] Nhật ký          ← Tab 2 (Grid/List + Calendar toggle)
├── [➕] Thêm chi tiêu    ← CENTER HERO BUTTON (không phải tab thật)
├── [💰] Ngân sách        ← Tab 3
└── [⚙️] Cài đặt         ← Tab 4

Modal Flows (từ nút Thêm):
└── AddExpenseView (Sheet)
    ├── Step 1: Chọn/Chụp ảnh (hoặc bỏ qua)
    ├── Step 2: Nhập số tiền + Smart VND Chips
    ├── Step 3: Chọn danh mục + Tên/Ghi chú
    └── Action: Lưu → Haptic + Dismiss
```

---

## 4. CẤU TRÚC THƯ MỤC DỰ ÁN XCODE

```
ViAnh/
├── ViAnhApp.swift                    ← App entry point, ModelContainer setup
├── ContentView.swift                 ← TabView + Center FAB overlay
│
├── Models/                           ← SwiftData models
│   ├── ExpenseItem.swift             ← @Model Expense (ID, amount, category, date, imageFileName...)
│   ├── ExpenseCategory.swift         ← @Model Category (name, icon, color, isDefault)
│   └── MonthlyBudget.swift           ← @Model Budget (year, month, totalAmount, categoryBudgets)
│
├── Services/                         ← Business logic, tách khỏi View
│   ├── ImageStorageService.swift     ← Lưu/Xóa ảnh vật lý, tạo thumbnail JPEG
│   ├── BudgetCalculator.swift        ← Tính toán ngân sách, % sử dụng, trạng thái cảnh báo
│   └── CSVExportService.swift        ← Xuất CSV UTF-8 (Giai đoạn 5)
│
├── Views/
│   ├── Dashboard/
│   │   ├── DashboardView.swift       ← Tổng quan: tổng hôm nay, tháng, ngân sách còn lại
│   │   └── RecentExpenseRow.swift    ← Row component cho danh sách gần đây
│   │
│   ├── Journal/
│   │   ├── JournalView.swift         ← Tab Nhật ký: toggle Grid/List/Calendar
│   │   ├── ExpenseGridView.swift     ← LazyVGrid 2 cột Polaroid cards
│   │   ├── PolaroidCardView.swift    ← Card component: ảnh + tem giá + ngày
│   │   ├── ExpenseListView.swift     ← Danh sách chi tiết (list mode)
│   │   └── ExpenseDetailView.swift  ← Chi tiết 1 khoản + vuốt ngang
│   │
│   ├── AddExpense/
│   │   ├── AddExpenseView.swift      ← Sheet modal, điều phối các step
│   │   ├── ImagePickerStep.swift     ← Chụp/Chọn ảnh hoặc bỏ qua
│   │   ├── AmountInputStep.swift     ← Nhập tiền + Smart VND Chips
│   │   └── CategoryPickerStep.swift  ← Chọn danh mục + Tên/Ghi chú
│   │
│   ├── Budget/
│   │   ├── BudgetView.swift          ← Tab Ngân sách: danh sách tháng
│   │   ├── BudgetSetupView.swift     ← Tạo/Sửa ngân sách tổng + theo danh mục
│   │   └── BudgetProgressCard.swift  ← Card hiển thị % sử dụng + cảnh báo
│   │
│   ├── Settings/
│   │   ├── SettingsView.swift        ← Tab Cài đặt
│   │   ├── CategoryManagementView.swift ← Thêm/Sửa/Xóa danh mục
│   │   ├── DataPrivacyView.swift     ← Chính sách dữ liệu + Privacy Policy
│   │   └── AboutView.swift           ← Phiên bản app
│   │
│   └── Components/                   ← Reusable UI components
│       ├── SmartVNDChipsView.swift    ← Chip gợi ý mệnh giá
│       ├── BudgetStatusBadge.swift    ← Badge cảnh báo 80%/100%/vượt
│       ├── EmptyStateView.swift       ← Empty state với SF Symbols
│       └── AsyncThumbnailView.swift   ← Load thumbnail async từ disk
│
├── Utilities/
│   ├── VNDFormatter.swift            ← Format tiền VND: 35000 → "35.000 ₫"
│   ├── DateHelpers.swift             ← Calendar/TimeZone helpers, tháng boundary
│   └── HapticManager.swift           ← Wrapper UIImpactFeedbackGenerator
│
├── Preview Content/
│   └── PreviewData.swift             ← Sample data CHỈ dùng trong #Preview
│
└── Tests/
    └── ViAnhTests/
        ├── BudgetCalculatorTests.swift
        ├── DateHelperTests.swift
        └── CSVExportTests.swift
```

---

## 5. DATA SCHEMA (SwiftData)

### 5.1 Model: ExpenseItem

```swift
@Model
final class ExpenseItem {
    // Định danh
    var id: UUID                        // Primary key
    
    // Tiền tệ — DÙNG Int64 (đơn vị: đồng VND), TUYỆT ĐỐI KHÔNG DÙNG Double
    var amountVND: Int64               // Ví dụ: 35000 = 35.000 ₫
    
    // Phân loại
    var category: ExpenseCategory      // Quan hệ nhiều-một
    
    // Thời gian — phát sinh thực tế (người dùng chọn)
    var spentAt: Date                  // Mặc định = Date.now, được phép sửa
    
    // Ảnh — chỉ lưu tên file tương đối, KHÔNG lưu full path
    var imageFileName: String?         // Ví dụ: "img_ABC123.jpg"
    var thumbnailFileName: String?     // Ví dụ: "thumb_ABC123.jpg"
    
    // Metadata
    var title: String                  // Tên khoản chi (optional, default = "")
    var note: String                   // Ghi chú (optional, default = "")
    var createdAt: Date                // Thời điểm tạo bản ghi
    var updatedAt: Date                // Tự cập nhật khi sửa
    
    init(amountVND: Int64, category: ExpenseCategory, spentAt: Date = .now) {
        self.id = UUID()
        self.amountVND = amountVND
        self.category = category
        self.spentAt = spentAt
        self.title = ""
        self.note = ""
        self.createdAt = .now
        self.updatedAt = .now
    }
}
```

### 5.2 Model: ExpenseCategory

```swift
@Model
final class ExpenseCategory {
    var id: UUID
    var name: String                   // "Ăn uống", "Mua sắm", v.v.
    var symbolName: String             // SF Symbol name: "fork.knife", "cart", v.v.
    var colorHex: String               // Lưu màu dạng hex string để serialize an toàn
    var isDefault: Bool                // true = 8 danh mục mặc định, không được xóa tên
    var sortOrder: Int                 // Thứ tự hiển thị
    
    @Relationship(deleteRule: .nullify, inverse: \ExpenseItem.category)
    var expenses: [ExpenseItem] = []
    
    // 8 danh mục mặc định
    static let defaultCategories: [(name: String, symbol: String, color: String)] = [
        ("Ăn uống",   "fork.knife",      "#FF6B6B"),
        ("Mua sắm",   "bag",             "#4ECDC4"),
        ("Đi lại",    "car",             "#45B7D1"),
        ("Nhà ở",     "house",           "#96CEB4"),
        ("Học tập",   "book",            "#FFEAA7"),
        ("Sức khỏe",  "heart",           "#DDA0DD"),
        ("Giải trí",  "gamecontroller",  "#98D8C8"),
        ("Khác",      "ellipsis.circle", "#B0B0B0"),
    ]
}
```

### 5.3 Model: MonthlyBudget

```swift
// ⚠️ REVIEW FIX (Issue 1 + 2): Tách CategoryBudget thành entity riêng thay vì JSON string
// → Giữ type safety, hỗ trợ SwiftData query, tránh migration phức tạp
// → Thêm #Unique để đảm bảo không trùng (year, month)

@Model
final class MonthlyBudget {
    var id: UUID
    
    #Unique<MonthlyBudget>([\.year, \.month])  // Đảm bảo unique per tháng
    var year: Int                      // Ví dụ: 2026
    var month: Int                     // 1–12
    var totalBudgetVND: Int64?         // nil = chưa đặt ngân sách tổng
    
    @Relationship(deleteRule: .cascade, inverse: \CategoryBudget.monthlyBudget)
    var categoryBudgets: [CategoryBudget] = []  // FIX: Entity riêng thay vì JSON
    
    var createdAt: Date
    
    // QUAN TRỌNG: categoryBudgets là giới hạn con, KHÔNG cộng thêm vào totalBudget
}

@Model
final class CategoryBudget {
    var id: UUID
    var category: ExpenseCategory      // Quan hệ tới danh mục
    var amountVND: Int64               // Giới hạn ngân sách cho danh mục này
    var monthlyBudget: MonthlyBudget   // Back-reference
    
    init(category: ExpenseCategory, amountVND: Int64, monthlyBudget: MonthlyBudget) {
        self.id = UUID()
        self.category = category
        self.amountVND = amountVND
        self.monthlyBudget = monthlyBudget
    }
}
```

---

## 6. SERVICE CONTRACTS (Giao kèo API nội bộ)

### 6.1 ImageStorageService

```swift
// ⚠️ REVIEW FIX (Issue 3 + 5):
// - Lưu vào Application Support (KHÔNG phải Documents để tránh iCloud backup)
// - Gán isExcludedFromBackup = true trên thư mục ảnh
// - Dùng Image I/O downsampling để tránh OOM khi load ảnh lớn
// - NSCache cho thumbnail đã load
// - Xóa file vật lý đồng bộ với xóa SwiftData record

actor ImageStorageService {
    // Thư mục gốc: Application Support / ViAnh / Images/
    // → KHÔNG dùng Documents (sẽ bị iCloud backup)
    // → Gán .isExcludedFromBackup = true trên thư mục
    
    private let cache = NSCache<NSString, UIImage>()  // In-memory cache thumbnail
    
    // Lưu ảnh gốc + tạo thumbnail. Trả về (imageFileName, thumbnailFileName)
    func save(image: UIImage) async throws -> (imageFileName: String, thumbnailFileName: String)
    
    // Xóa cả ảnh gốc + thumbnail theo tên file
    // Gọi SAU KHI xóa SwiftData record để đảm bảo toàn vẹn
    func delete(imageFileName: String?, thumbnailFileName: String?) async
    
    // Đọc thumbnail (dùng Image I/O downsampling, có NSCache)
    func loadThumbnail(fileName: String) async -> UIImage?
    
    // Đọc ảnh gốc (dùng Image I/O downsampling theo screen size, không full RAM)
    func loadFullImage(fileName: String) async -> UIImage?
    
    // Constants
    static let jpegQuality: CGFloat = 0.8
    static let thumbnailSize: CGSize = CGSize(width: 300, height: 300)
    static let thumbnailQuality: CGFloat = 0.6
}
```

### 6.2 BudgetCalculator

```swift
struct BudgetCalculator {
    
    enum BudgetStatus {
        case notSet                          // Chưa đặt ngân sách
        case underEightyPercent(ratio: Double)  // < 80%
        case warningEightyPercent(ratio: Double) // 80% ≤ ratio < 100%
        case atLimit(ratio: Double)          // = 100%
        case overBudget(exceededVND: Int64)  // > 100%
    }
    
    // Tính tổng chi trong tháng/năm từ danh sách expenses
    // Dùng Calendar + TimeZone để tính đúng ranh giới tháng
    static func totalSpent(
        expenses: [ExpenseItem],
        year: Int,
        month: Int,
        calendar: Calendar = .current
    ) -> Int64
    
    // Tính trạng thái ngân sách tổng
    // KHÔNG BAO GIỜ chia cho 0 — trả về .notSet nếu budget == nil hoặc == 0
    static func budgetStatus(
        spent: Int64,
        budget: Int64?
    ) -> BudgetStatus
    
    // Tính trạng thái ngân sách theo danh mục
    static func categoryBudgetStatus(
        categoryId: UUID,
        expenses: [ExpenseItem],
        year: Int,
        month: Int,
        categoryBudget: Int64?
    ) -> BudgetStatus
    
    // Phân nhóm expenses theo tháng để hiển thị section header
    static func groupByMonth(
        expenses: [ExpenseItem],
        calendar: Calendar = .current
    ) -> [(key: DateComponents, value: [ExpenseItem])]
    
    // Tính chi tiêu theo danh mục (cho biểu đồ)
    static func spentByCategory(
        expenses: [ExpenseItem],
        year: Int,
        month: Int
    ) -> [UUID: Int64]
}
```

### 6.3 VNDFormatter

```swift
extension Int64 {
    // 35000 → "35.000 ₫"
    var vndFormatted: String
    
    // 35000 → "35k" (dùng cho chip gợi ý)
    var vndShortFormatted: String
}

struct SmartVNDSuggestion {
    // Input: "35" → Output: [35_000, 350_000, 3_500_000]
    // Input: "1" → Output: [1_000, 10_000, 100_000]
    // Input: "" hoặc "0" → Output: []
    static func suggestions(for rawInput: String) -> [Int64]
}
```

---

## 7. WIREFRAME MÔ TẢ (Text)

### 7.1 Tab: Tổng quan (Dashboard)

```
┌─────────────────────────────────┐
│ Ví Ảnh                    [Bell] │ ← Navigation Bar
├─────────────────────────────────┤
│                                 │
│  Tháng 11, 2026                 │
│                                 │
│  ┌──────────┐  ┌──────────┐     │
│  │ Hôm nay  │  │ Tháng này│     │
│  │ 145.000₫ │  │ 2.3tr ₫  │     │
│  └──────────┘  └──────────┘     │
│                                 │
│  Ngân sách còn lại              │
│  ██████████░░░░  78%            │
│  Còn lại: 700.000 ₫             │
│                                 │
│  Chi tiêu theo danh mục         │
│  [Donut Chart — Swift Charts]   │
│                                 │
│  Gần đây                        │
│  ┌─────────────────────────┐    │
│  │ 🍜 Ăn trưa   35.000₫   │    │
│  │ 🚌 Xe buýt   15.000₫   │    │
│  │ 📚 Sách      120.000₫  │    │
│  └─────────────────────────┘    │
│                                 │
├─────────────────────────────────┤
│ [🏠]  [📔]  [⊕]  [💰]  [⚙️] │ ← Tab Bar + Center FAB
└─────────────────────────────────┘
```

### 7.2 Sheet: Thêm Chi Tiêu

```
Step 1 — Ảnh:
┌─────────────────────────────────┐
│ Hủy          Ảnh chi tiêu       │
├─────────────────────────────────┤
│  ┌───────────────────────────┐  │
│  │                           │  │
│  │      [Camera Preview]     │  │
│  │      hoặc ảnh đã chọn     │  │
│  │                           │  │
│  └───────────────────────────┘  │
│                                 │
│   [📷 Chụp ảnh]  [🖼 Chọn ảnh] │
│                                 │
│       [Bỏ qua, nhập thủ công →] │
└─────────────────────────────────┘

Step 2 — Số tiền:
┌─────────────────────────────────┐
│ ← Quay lại     Số tiền          │
├─────────────────────────────────┤
│                                 │
│  Ảnh nhỏ (nếu có)              │
│                                 │
│          350.000 ₫              │ ← Large, centered
│    ___________________________   │
│                                 │
│  [35.000₫]  [350.000₫]  [3.5tr] │ ← Smart VND Chips (trên keyboard)
│ ─────────────────────────────── │
│  [1][2][3]                      │
│  [4][5][6]                      │ ← Number keyboard
│  [7][8][9]                      │
│  [.][0][⌫]                     │
└─────────────────────────────────┘

Step 3 — Danh mục & Lưu:
┌─────────────────────────────────┐
│ ← Quay lại  Chi tiết & Lưu     │
├─────────────────────────────────┤
│  Danh mục:                      │
│  [🍜 Ăn uống]  [🛍 Mua sắm]   │
│  [🚗 Đi lại]   [🏠 Nhà ở]     │
│  [📚 Học tập]  [❤️ Sức khỏe]  │
│  [🎮 Giải trí] [• Khác]        │
│                                 │
│  Tên khoản chi (tuỳ chọn)      │
│  [___________________________]  │
│                                 │
│  Ngày giờ                       │
│  [2/11/2026  14:30  ▾]         │
│                                 │
│  Ghi chú (tuỳ chọn)            │
│  [___________________________]  │
│                                 │
│       [        Lưu        ]     │ ← Primary button
└─────────────────────────────────┘
```

### 7.3 Tab: Nhật Ký / Album

```
┌─────────────────────────────────┐
│ Nhật ký            [🔍][☰/⊞]  │ ← Grid/List toggle
├─────────────────────────────────┤
│ [🔍 Tìm kiếm...]               │
│ [Tất cả ▾]  [Tháng 11 ▾]      │ ← Filter pills
│                                 │
│ Tháng 11, 2026 · 2.300.000 ₫   │ ← Section header + total
│ ┌──────────┐  ┌──────────┐     │
│ │  [ảnh]   │  │  [ảnh]   │     │ ← Polaroid cards
│ │          │  │          │     │
│ │ 35.000₫  │  │ 120.000₫ │     │
│ │ Hôm nay  │  │ Hôm nay  │     │
│ └──────────┘  └──────────┘     │
│                                 │
│ Tháng 10, 2026 · 1.800.000 ₫   │
│ ┌──────────┐  ┌──────────┐     │
│ │  [🚗]   │  │  [ảnh]   │     │ ← No-image placeholder
│ │          │  │          │     │
│ │ 15.000₫  │  │ 250.000₫ │     │
│ └──────────┘  └──────────┘     │
│                                 │
├─────────────────────────────────┤
│ [🏠]  [📔]  [⊕]  [💰]  [⚙️] │
└─────────────────────────────────┘
```

### 7.4 Tab: Ngân Sách

```
┌─────────────────────────────────┐
│ Ngân sách              [+ Đặt] │
├─────────────────────────────────┤
│ Tháng 11, 2026                  │
│                                 │
│ Tổng tháng                      │
│ ████████████░░░  78%  2.3/3tr  │
│ Còn lại: 700.000 ₫              │
│                                 │
│ Theo danh mục                   │
│ ┌─────────────────────────────┐ │
│ │ 🍜 Ăn uống                 │ │
│ │ ██████░░░░  60%  600/1tr   │ │
│ └─────────────────────────────┘ │
│ ┌─────────────────────────────┐ │
│ │ ⚠️ 🛍 Mua sắm [80%+]       │ │
│ │ ████████░░  82%  410/500k  │ │
│ └─────────────────────────────┘ │
│ ┌─────────────────────────────┐ │
│ │ 🚨 🎮 Giải trí [Vượt!]     │ │
│ │ ██████████  115%  230/200k │ │
│ └─────────────────────────────┘ │
├─────────────────────────────────┤
│ [🏠]  [📔]  [⊕]  [💰]  [⚙️] │
└─────────────────────────────────┘
```

---

## 8. THIẾT KẾ MÀUN SẮC & ACCESSIBILITY

### Bảng màu đã điều chỉnh theo WCAG 2.1 AA:

```swift
extension Color {
    // Brand Green (đã tăng độ đậm để đạt 4.5:1 contrast trên nền trắng)
    static let brandGreen = Color(hex: "#2E7D32")      // Text/Icon trên nền trắng
    static let brandGreenLight = Color(hex: "#4CAF50")  // Nền button lớn + chữ trắng
    
    // Semantic colors (tự adapt Light/Dark mode)
    static let appBackground = Color(.systemBackground)
    static let cardBackground = Color(.secondarySystemBackground)
    static let labelPrimary = Color(.label)
    static let labelSecondary = Color(.secondaryLabel)
    
    // Budget status colors (LUÔN kèm icon/text, KHÔNG dùng màu đơn thuần)
    static let budgetSafe = Color(hex: "#2E7D32")
    static let budgetWarning = Color(hex: "#E65100")   // Orange, contrast cao
    static let budgetOver = Color(hex: "#B71C1C")      // Red, contrast cao
}
```

### Accessibility Requirements:
- ✅ Dynamic Type: Tất cả Text dùng `.font(.body)`, `.font(.headline)`, v.v. (không hard-code size)
- ✅ VoiceOver: Mỗi card, button, badge phải có `.accessibilityLabel` rõ ràng bằng tiếng Việt
- ✅ Budget warning: Luôn có icon (⚠️/🚨) + chữ ([80%+]/[Vượt!]) — KHÔNG chỉ dùng màu đỏ
- ✅ Tối thiểu tap target: 44×44 pt cho tất cả interactive elements

---

## 9. TRẠNG THÁI BIÊN (EDGE CASES)

| Tình huống | Xử lý |
|---|---|
| Chưa có chi tiêu nào | Empty State: SF Symbol + tiêu đề + CTA button |
| Người dùng từ chối Camera | Ẩn nút "Chụp ảnh", hiện nút "Chọn từ thư viện" + link đến Settings |
| Ảnh không tải được | Hiện placeholder với category icon + màu nền |
| Chưa đặt ngân sách | Hiện lời mời "Đặt ngân sách tháng" — KHÔNG coi = 0 |
| Ngân sách = 0 (guard) | BudgetCalculator trả .notSet — KHÔNG chia cho 0 |
| Xóa danh mục đang dùng | Alert xác nhận, chuyển expenses sang "Khác" |
| Lỗi lưu SwiftData | Alert lỗi + gợi ý khởi động lại app |
| Chuyển tháng lúc 23:59→00:00 | Dùng Calendar.current để tính startOf/endOfMonth |

---

## 10. ROADMAP SAU MVP (CHỈ GHI, TUYỆT ĐỐI CHƯA VIẾT CODE)

1. **Đánh giá "đáng tiền"** — Review món đồ sau thời gian sử dụng
2. **Monthly Recap** — Ảnh tổng kết tháng để share, tùy chọn ẩn số tiền
3. **OCR Scan** — Quét hóa đơn, tự điền số tiền
4. **Widget** — Home Screen widget tổng chi hôm nay
5. **iCloud Sync** — CloudKit + sao lưu ảnh
6. **Recurring Expense** — Chi tiêu định kỳ tự động
7. **Wishlist** — Danh sách muốn mua

---

## 11. CHECKLIST NGHIỆM THU TỔNG (Acceptance Criteria)

- [ ] Thêm chi tiêu có/không có ảnh → data giữ nguyên sau kill app
- [ ] Sửa số tiền/ngày/danh mục → cập nhật ngay ở Album + Dashboard + Budget
- [ ] Xóa chi tiêu → tổng tiền cập nhật, file ảnh+thumbnail bị xóa khỏi disk
- [ ] Lọc tháng → chính xác tại giao thừa 23:59→00:00
- [ ] Budget: 4 trạng thái đều hiển thị đúng (notSet, <80%, 80-100%, >100%)
- [ ] Từ chối Camera → app không crash, vẫn cho chọn ảnh từ thư viện
- [ ] CSV xuất đúng UTF-8, tiếng Việt, xử lý đúng ký tự đặc biệt
- [ ] Unit Test pass: BudgetCalculator, DateHelpers, CSVExport

---

## 12. KẾ HOẠCH TRIỂN KHAI (6 Giai đoạn ban đầu)

| Giai đoạn | Nội dung | File chính |
|---|---|---|
| **G1** (✅ Đã xong) | Nền tảng dữ liệu, định dạng tiền, Dock điều hướng | Models/, ThemeManager, FloatingPillDockView |
| **G2** (✅ Đã xong) | Trang chủ và Lịch Ảnh Kỷ Niệm | Views/Dashboard/, MonthGridBuilder |
| **G3** (✅ Đã xong) | Camera và nhập tiền trên ảnh | Services/CameraService, ExpenseCaptureView |
| **G4** (✅ Đã xong) | Thống kê Ngày / Tháng / Năm (Swift Charts) | Views/Analytics/AnalyticsView |
| **G5** (✅ Đã xong) | Đa ngân sách và cảnh báo | Services/NotificationManager, BudgetProgressCard |
| **G6** (✅ Đã xong) | Tài khoản, Đa Theme, Ví, StoreKit & Phát hành | SettingsView, WalletManagementView |

---

## 13. KẾ HOẠCH NÂNG CẤP SNAPSPEND MỚI (Tháng 11/2026)

Theo yêu cầu thiết kế mới từ người dùng (kết hợp phong cách Locket & SnapSpend):
- **Ảnh 1**: Mẫu màn chi tiết giao dịch với ảnh lớn, số tiền đè lên ảnh kèm gradient, pill danh mục, pill ngày/giờ, pill caption, bỏ pill Ví tiền.
- **Ảnh 2**: Mẫu màn Kỷ niệm với lịch thumbnail theo tháng, badge số ảnh và thẻ thống kê "📸 … ảnh | 🔥 Chuỗi … ngày".

### Lộ trình 5 đợt triển khai:

- **Đợt 1 (Đang triển khai)**:
  - Lưu và đọc lại ảnh: JPEG & Thumbnail lưu vào Application Support, đường dẫn tương đối trong SwiftData. Phóng to ảnh, chia sẻ, lưu vào thư viện ảnh Photos.
  - Màn chi tiết giao dịch theo **Ảnh 1**: Nút back tròn, pill tiêu đề `Giao dịch ⌵`, nút sửa/xóa, ảnh lớn bo góc có số tiền đè lên ảnh kèm gradient mờ, pill danh mục, pill ngày/giờ, pill caption, bỏ pill Ví tiền.
  - Chế độ Ngày / Tháng hoạt động chuẩn xác trên Trang chủ.
  - Lịch Kỷ niệm theo **Ảnh 2**: Đủ 7 cột, ô có ảnh hiện thumbnail + badge số ảnh, chạm xem toàn bộ ảnh/giao dịch trong ngày, ngày trống có nút `+` giữ nguyên ngày đã chọn, cuộn xem tháng trước & quay lại hôm nay.
  - Thẻ thống kê `"📸 … ảnh | 🔥 Chuỗi … ngày"` tính đúng quy tắc chuỗi liên tiếp và ảnh chụp thật sự.
- **Đợt 2**: Camera lớn (khung vuông bo góc Locket), ultra-wide 0.5x, bàn phím iPhone hệ thống và caption sau chụp.
- **Đợt 3**: Bỏ quản lý ví/tài khoản, bố trí Cài đặt và dock, sửa Dark Mode, đặt tên SnapSpend.
- **Đợt 4**: Quy đổi tiền tệ toàn app và chuyển ngôn ngữ Việt/Anh.
- **Đợt 5**: Ngân sách mượt mà, danh mục tùy chỉnh và hoàn thiện chuyển động.

---

## 14. NÂNG CẤP ĐỢT A & ĐỢT B (Tháng 11/2026)

### Đợt A (✅ Hoàn thành):
1. **Khung Camera đưa lên cao**:
   - Khung ngắm đưa lên sát nút Hủy và safe area (giảm khoảng trống trên).
   - Tỷ lệ gần vuông bo góc 28pt, responsive theo chiều cao màn hình khả dụng bằng GeometryReader (chạy tốt từ iPhone SE đến iPhone 15 Pro Max).
   - Nút Flash và Đảo camera nằm trực tiếp trong khung preview: góc trên trái và phải, inset 14pt, hit target tối thiểu 44 × 44 pt, nền tối bán trong suốt.
   - Hỗ trợ zoom 0.5x Ultra-Wide thật trên camera sau iPhone 15 Pro Max (Triple Camera/Dual Wide), đảo camera cập nhật capabilities.
   - Flash điều khiển phần cứng thật sự khi chụp ảnh (`settings.flashMode`).
2. **Sửa dứt điểm lỗi nhập tiền bấm Xong nhảy tab**:
   - Sử dụng `@FocusState` phân biệt rõ `amount` và `caption`.
   - Nút "Xong" trên thanh bàn phím hệ thống (`ToolbarItemGroup(placement: .keyboard)`) chỉ đóng bàn phím (`focusedField = nil`), tuyệt đối không dismiss màn hình, không kích hoạt submit nhầm và không nhảy tab.
   - Ô nhập caption đặt inline trực tiếp trên thẻ trắng bên dưới nút nhân nhanh (không dùng sheet phụ gây xung đột dismiss).
   - Chạm vào khoảng trắng ngoài ô nhập đóng bàn phím (`focusedField = nil`).
   - Chuyển đổi trực tiếp giữa ô tiền và ô caption đổi mượt mà giữa bàn phím số và bàn phím chữ.
   - Chỉ nút Lưu (✓) mới lưu giao dịch; chỉ nút Hủy mới thoát luồng.

### Đợt B (Kế hoạch Xác thực Đa phương thức):
1. **Khảo sát hệ thống**: Dự án hiện tại hoạt động 100% offline-first cục bộ (Local SwiftData + File Storage). Chưa có backend xác thực.
2. **Đề xuất giải pháp**: **Firebase Authentication** hoặc **Supabase Auth**. Khuyến nghị **Firebase Authentication** vì:
   - Hỗ trợ toàn diện cả 4 phương thức: Sign in with Apple (native iOS), Facebook Login, Email/Password, và Phone Number SMS OTP (+84).
   - Cơ chế Guest Mode (Anonymous Authentication) cho phép gắn (link) dữ liệu khách hiện có vào tài khoản chính thức sau khi đăng nhập mà không làm gián đoạn hay mất dữ liệu người dùng.
   - SDK iOS chính thức (`FirebaseAuth`) quản lý Keychain token an toàn và tự động khôi phục phiên.
   - Đáp ứng yêu cầu xóa tài khoản theo Apple App Store Guideline 5.1.1(v) thông qua API `user.delete()`.
3. **Chi phí & Cấu hình dịch vụ**:
   - Apple Developer Program: \$99/năm (yêu cầu cấu hình Sign in with Apple capability trên App ID).
   - Meta for Developers: Miễn phí (tạo App, lấy App ID, Client Token, cấu hình URL Schemes).
   - Firebase Auth: Gói Spark (miễn phí) hỗ trợ không giới hạn Email/Apple/Facebook và 10.000 lượt xác thực Phone OTP/tháng.

---

*Tài liệu này được cập nhật đồng bộ cho SnapSpend (ViAnh).*  
*Cập nhật lần cuối: 2026-11-03*

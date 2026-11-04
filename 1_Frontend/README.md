# 🎨 PHẦN 1: FRONTEND (TẦNG GIAO DIỆN & TRẢI NGHIỆM NGƯỜI DÙNG)

> **Dự án:** SnapSpend (Ứng dụng Quản lý Thu Chi & Nhật Ký Hình Ảnh)  
> **Nền tảng:** iOS 17.0+ | **Ngôn ngữ:** Swift 5.10 / Swift 6  
> **Framework:** SwiftUI (Declarative UI)  
> **Phong cách thiết kế:** Warm Cream & Locket-style interactive experience  

---

## 1. Triết lý Thiết kế (UI/UX Architecture)

Giao diện của **SnapSpend** được thiết kế dựa trên tiêu chuẩn thiết kế hiện đại của Apple Human Interface Guidelines kết hợp phong cách tương tác một chạm của Locket:
- **Tone màu chủ đạo:** Nền Warm Cream `#FAF6F0`, thẻ giao dịch màu trắng tinh khôi bo góc mềm mại 20–24 pt, đổ bóng mờ tinh tế (Drop Shadow Radius 10, Opacity 0.05).
- **Quy tắc tốc độ 3 giây:** Mở app → Bấm dấu `[+]` tại Floating Dock → Chụp ảnh hóa đơn/khoảnh khắc → Chạm chip số tiền gợi ý → Bấm Lưu. Thao tác hoàn toàn bằng một tay.
- **Màu sắc trạng thái:**
  - ↗ **Khoản chi (Expense):** Màu đỏ hồng dịu `#E05353`.
  - ↙ **Khoản thu (Income):** Màu xanh lá sinh thái `#2E7D32`.
  - 🌟 **Hành động chính:** Xanh lá đậm `#1B4D3E`.
- **Phản hồi xúc giác & Chuyển động:** Tích hợp `HapticManager` với rung phản hồi nhẹ (`UIImpactFeedbackGenerator`), animation lò xo mượt mà `.spring(response: 0.35, dampingFraction: 0.8)`.

---

## 2. Bản đồ Cấu trúc Module Frontend

Toàn bộ mã nguồn giao diện nằm trong thư mục `ViAnh/Views/`, `ViAnh/Components/` và `ViAnh/Utilities/`:

```
1_Frontend/
├── Views/
│   ├── Dashboard/          # Màn hình Trang chủ & Trung tâm điều khiển
│   │   ├── DashboardView.swift              # View gốc Dashboard
│   │   ├── DashboardHeaderView.swift        # Header chào hỏi, avatar, chuỗi ngày streak
│   │   ├── DashboardToolbarView.swift       # Thanh công cụ chuyển đổi Tháng/Năm
│   │   ├── DashboardFilterSheet.swift       # Bộ lọc giao dịch theo danh mục/ví/thời gian
│   │   ├── TransactionSummaryCard.swift     # Thẻ thống kê Tổng thu - Tổng chi - Số dư
│   │   ├── MemoryCalendarView.swift         # Lịch ảnh kỷ niệm (Avatar/Ảnh thu nhỏ theo ngày)
│   │   ├── MonthGridBuilder.swift           # Thuật toán vẽ lưới ngày trong tháng
│   │   └── RecentExpenseRow.swift           # Dòng hiển thị khoản chi gần đây
│   │
│   ├── AddExpense/         # Quy trình Ghi chép Thu Chi 3 bước
│   │   ├── AddExpenseView.swift             # Điều phối Wizard nhập liệu
│   │   ├── CameraPreviewView.swift          # Live Camera Viewfinder (hỗ trợ 0.5x, Flash)
│   │   ├── ExpenseCaptureView.swift         # Chụp ảnh, gắn nhãn vị trí & thời gian thực
│   │   ├── AmountInputStep.swift            # Bàn phím số chuyên biệt + Chip tiền thông minh
│   │   ├── CategoryPickerStep.swift         # Chọn danh mục (Ăn uống, Mua sắm, Di chuyển...)
│   │   └── ImagePickerStep.swift            # Chọn ảnh từ Thư viện (PhotosPicker)
│   │
│   ├── Journal/            # Nhật ký & Kỷ niệm hình ảnh
│   │   ├── JournalView.swift                # Danh sách nhật ký cuộn theo dòng thời gian
│   │   ├── MemoriesView.swift               # Album ảnh kỷ niệm dạng lưới Pinterest
│   │   ├── ExpenseGridView.swift            # Lưới xem ảnh đa cột
│   │   ├── ExpenseListView.swift            # Danh sách dạng bảng sao kê
│   │   ├── ExpenseDetailView.swift          # Màn hình xem chi tiết khoản chi & sửa/xóa
│   │   └── PolaroidCardView.swift           # Thẻ ảnh phong cách Polaroid kèm caption viết tay
│   │
│   ├── Budget/             # Quản lý Ngân sách thông minh
│   │   ├── BudgetView.swift                 # Tổng quan ngân sách tháng
│   │   ├── BudgetSetupView.swift            # Màn hình cài đặt/chỉnh sửa ngân sách
│   │   └── BudgetProgressCard.swift         # Thanh tiến độ phần trăm đã tiêu (Đổi màu cảnh báo)
│   │
│   ├── Analytics/          # Báo cáo & Thống kê trực quan
│   │   └── AnalyticsView.swift              # Biểu đồ phân bổ chi tiêu, so sánh các tháng
│   │
│   ├── Settings/           # Thiết lập hệ thống & Hồ sơ
│   │   ├── SettingsView.swift               # Danh mục cài đặt chính
│   │   ├── CategoryManagementView.swift     # Thêm/Sửa/Xóa danh mục chi tiêu cá nhân
│   │   ├── WalletManagementView.swift       # Quản lý nhiều tài khoản/ví tiền
│   │   ├── DataPrivacyView.swift            # Chính sách quyền riêng tư & Hỗ trợ (huytx3z3@gmail.com)
│   │   └── AboutView.swift                  # Thông tin phiên bản & Đội ngũ phát triển
│   │
│   └── Auth/               # Giao diện Chào mừng & Đăng nhập
│       └── AuthWelcomeView.swift            # Đăng nhập Apple, Google, Email, Khách
│
├── Components/             # Thành phần giao diện dùng chung (Design System)
│   ├── UserAvatarView.swift                 # Avatar tròn đồng bộ, fallback chữ cái pastel
│   ├── AvatarCropView.swift                 # Cắt ảnh đại diện vuông/tròn (Zoom & Pan mượt mà)
│   ├── SmartVNDChipsView.swift              # Chip gợi ý số tiền nhanh (10k, 20k, 50k, 100k, 500k)
│   ├── FloatingPillDockView.swift           # Thanh điều hướng nổi hình viên thuốc 5 tab
│   ├── BudgetStatusBadge.swift              # Huy hiệu trạng thái An toàn / Cảnh báo / Vượt mức
│   ├── AsyncThumbnailView.swift             # Tải ảnh thumbnail nền bất đồng bộ, không giật lag
│   └── EmptyStateView.swift                 # Giao diện minh họa khi chưa có dữ liệu
│
└── Utilities/              # Tiện ích bổ trợ Frontend
    ├── ThemeManager.swift                   # Quản lý giao diện Sáng / Tối / Tự động
    ├── HapticManager.swift                  # Phản hồi rung vật lý cho từng tương tác
    ├── VNDFormatter.swift                   # Định dạng tiền tệ Việt Nam Đồng (35.000 ₫)
    └── DateHelpers.swift                    # Xử lý thời gian, định dạng ngày tháng tiếng Việt
```

---

## 3. Điểm nhấn Kỹ thuật nổi bật trong Frontend

1. **Floating Pill Dock (Thanh điều hướng nổi):**
   - Đặt nổi trên nội dung với hiệu ứng Ultra-thin Material (kính mờ Blur).
   - Nút `[+]` ở vị trí trung tâm nổi bật, hỗ trợ thao tác ngón cái tay phải thuận tiện nhất.
2. **AvatarCropView thông minh:**
   - Cho phép người dùng phóng to (Pinch-to-zoom từ 1x đến 4x) và di chuyển (Pan gesture) ảnh trong khung tròn.
   - Xử lý chuẩn hóa hướng ảnh (`UIImage.normalized()`) và nén ngoài luồng giao diện chính (`Task.detached`), không làm khựng màn hình.
3. **Smart VND Chips (Bàn phím nhập tiền nhanh):**
   - Tự động cộng dồn số tiền khi bấm nhiều lần (ví dụ: bấm 50k + 20k = 70.000 ₫).
   - Tích hợp công tắc chuyển đổi nhanh giữa Khoản Chi (Expense) và Khoản Thu (Income).
4. **Khả năng tiếp cận & Quốc tế hóa:**
   - Hỗ trợ song ngữ hoàn chỉnh **Tiếng Việt** và **Tiếng Anh** thông qua `LocalizationManager`.
   - Hỗ trợ đầy đủ **Dark Mode** và nhãn đọc màn hình cho người khiếm thị (**VoiceOver**).


# 💾 PHẦN 2: BACKEND (TẦNG DỮ LIỆU, LƯU TRỮ & LOGIC NGHIỆP VỤ)

> **Dự án:** SnapSpend  
> **Công nghệ lõi:** SwiftData (iOS 17+ Modern Persistence) | Core Data Engine | FileManager Sandbox  
> **Cơ chế lưu trữ:** Cơ sở dữ liệu quan hệ cục bộ (On-device Relational DB) + Local Blob Storage + Firebase Sync Ready  

---

## 1. Kiến trúc Tầng Dữ liệu (Persistence Architecture)

SnapSpend áp dụng mô hình **Local-First Architecture** (Ưu tiên lưu trữ cục bộ trên thiết bị):
1. **Truy vấn tức thì:** Tốc độ đọc ghi tính bằng mili-giây, ứng dụng hoạt động mượt mà 100% ngay cả khi không có kết nối Internet hoặc ở chế độ máy bay.
2. **Bảo mật tuyệt đối:** Dữ liệu tài chính và hình ảnh riêng tư của người dùng được lưu trữ trong phân vùng Sandbox bảo vệ của hệ điều hành iOS (`NSSearchPathForDirectoriesInDomains`).
3. **Sẵn sàng đồng bộ Đám mây (Cloud Sync Ready):** Toàn bộ schema đều có trường `ownerUID` (Firebase UID) để sẵn sàng đồng bộ hai chiều với Firebase Firestore và Cloud Storage khi người dùng kết nối mạng.

---

## 2. Bản đồ Cấu trúc Module Backend

Toàn bộ mã nguồn dữ liệu nằm trong thư mục `ViAnh/Models/` và các Service quản lý dữ liệu trong `ViAnh/Services/`:

```
2_Backend/
├── Models/                 # Thực thể dữ liệu (SwiftData @Model Schemas)
│   ├── ExpenseItem.swift            # Bảng Giao dịch thu/chi chính kèm ảnh & định danh chủ sở hữu
│   ├── ExpenseCategory.swift        # Bảng Danh mục chi tiêu (Ăn uống, Giải trí, Lương...)
│   ├── MonthlyBudget.swift          # Bảng Ngân sách chi tiêu thiết lập theo từng tháng
│   └── Wallet.swift                 # Bảng Ví tiền / Tài khoản thanh toán (Tiền mặt, Thẻ, Momo...)
│
└── Services/               # Quản lý Xử lý Logic Nghiệp vụ & Lưu trữ
    ├── ImageStorageService.swift    # Quản lý tệp hình ảnh hóa đơn trên đĩa Sandbox
    ├── BudgetCalculator.swift       # Tính toán tỷ lệ chi tiêu, cảnh báo vượt ngưỡng ngân sách
    ├── CategoryManager.swift        # Khởi tạo 8 danh mục mặc định & quản lý danh mục người dùng
    ├── WalletManager.swift          # Quản lý số dư, chuyển tiền giữa các ví
    ├── StreakService.swift          # Tính toán chuỗi ngày ghi chép liên tục (Gamification)
    └── DataOwnerMigrationService.swift # Dịch vụ phân loại và di chuyển dữ liệu an toàn theo UID
```

---

## 3. Thiết kế Lược đồ Cơ sở Dữ liệu (Data Schema Detail)

### 3.1. Entity: `ExpenseItem` (Khoản Giao dịch)
| Trường dữ liệu | Kiểu dữ liệu | Ý nghĩa & Quy tắc nghiệp vụ |
|---|---|---|
| `id` | `UUID` (Primary Key) | Mã định danh duy nhất của giao dịch |
| `ownerUID` | `String` (Indexed) | **Định danh chủ sở hữu (Firebase UID)**. Đảm bảo dữ liệu tài khoản A hoàn toàn tách biệt với tài khoản B |
| `amount` | `Double` | Giá trị giao dịch tính bằng VND (ví dụ: `35000.0`) |
| `note` | `String` | Ghi chú mô tả khoản chi (ví dụ: "Cà phê sáng cùng đồng nghiệp") |
| `date` | `Date` | Thời gian phát sinh giao dịch |
| `isIncome` | `Bool` | `false`: Khoản chi (↘) \| `true`: Khoản thu (↗) |
| `categoryID` | `String` | Khóa ngoại liên kết tới danh mục |
| `walletID` | `String` | Khóa ngoại liên kết tới ví thanh toán |
| `imagePath` | `String?` | Tên tệp ảnh hóa đơn lưu trữ cục bộ |
| `latitude` / `longitude` | `Double?` | Tọa độ GPS nơi phát sinh chi tiêu (tùy chọn) |

### 3.2. Entity: `MonthlyBudget` (Ngân sách Tháng)
- **Thuộc tính:** `id: UUID`, `ownerUID: String`, `month: Int`, `year: Int`, `totalLimit: Double`, `createdAt: Date`.
- **Cơ chế:** Mỗi tài khoản chỉ có 1 ngân sách duy nhất cho mỗi tháng (`year-month`). Cho phép theo dõi hạn mức chi và tính phần trăm tiêu hao theo thời gian thực.

### 3.3. Entity: `ExpenseCategory` & `Wallet`
- Cung cấp sẵn các danh mục và ví tiền hệ thống mặc định (`isDefault = true`).
- Người dùng có thể tự tạo thêm danh mục và ví riêng với cờ sở hữu `ownerUID`.

---

## 4. Dịch vụ Lưu trữ Tệp Ảnh: `ImageStorageService`

- **Tối ưu hóa dung lượng:** Hóa đơn chụp từ camera có kích thước lớn (> 10MB) được nén và downsample ngoài luồng chính về kích thước tiêu chuẩn (độ phân giải tối đa 1600px, chất lượng nén JPEG 0.85).
- **Phân tách theo phiên làm việc:** Ảnh được lưu trong thư mục `SnapSpend_Images/` của Documents Directory với tên định danh UUID duy nhất.
- **Xóa rác tự động:** Khi người dùng xóa một khoản chi tiêu, `ImageStorageService.deleteImage()` sẽ lập tức giải phóng tệp ảnh tương ứng trên ổ cứng, tránh gây lãng phí dung lượng thiết bị.


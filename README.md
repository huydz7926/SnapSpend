# SnapSpend

**Ứng dụng iOS ghi chép chi tiêu bằng hình ảnh, kết hợp quản lý ngân sách và nhật ký cá nhân.**

SwiftUI · SwiftData · Swift Concurrency · Swift Testing · iOS 17+

SnapSpend hướng đến việc ghi nhớ một khoản chi qua cả số tiền và ngữ cảnh hình ảnh. Người dùng chụp hoặc chọn ảnh, nhập số tiền, chọn danh mục và xem lại lịch sử dưới dạng nhật ký hình ảnh trực quan.

> **Trạng thái:** Đang phát triển và kiểm thử beta. Bản 1.0.0 (1) đã được đóng gói và thử nghiệm trên TestFlight; đang chuẩn bị các bước hoàn thiện cho App Store.

---

## Demo
<p align="center">
  <img src="Docs/Screenshots/TrangChu.png" width="220" alt="Trang chủ" />
  <img src="Docs/Screenshots/Camera.png" width="220" alt="Thêm chi tiêu" />
  <img src="Docs/Screenshots/KyNiem.png" width="220" alt="Nhật ký ảnh" />
  <img src="Docs/Screenshots/NganSach.png" width="220" alt="Ngân sách" />
</p>

Các luồng hoạt động chính trong ứng dụng:
- **Tạo khoản chi có ảnh:** Chụp hoặc chọn ảnh → Gợi ý số tiền VND thông minh → Chọn danh mục → Lưu nhanh trong 3 giây.
- **Xem nhật ký & Thư viện ảnh:** Lịch sử chi tiêu kết hợp ảnh theo phong cách Polaroid / Locket.
- **Theo dõi ngân sách:** Hạn mức chi tiêu hàng tháng, tỷ lệ phần trăm đã dùng và các trạng thái cảnh báo trực quan.
- **Đa tài khoản & Bảo vệ dữ liệu:** Phân tách dữ liệu giao dịch, ngân sách, danh mục và avatar theo người dùng (`ownerUID`).

*Lưu ý khi quay demo hoặc chụp ảnh màn hình:* Sử dụng dữ liệu mẫu và che thông tin cá nhân. Giao diện SnapSpend giữ định hướng màu chủ đạo **Warm Cream và xanh lá đậm** (`#1B4D3E`).

---

## Tính Năng

Phạm vi tính năng được đối chiếu trực tiếp với mã nguồn ứng dụng (chi tiết trạng thái kiểm thử tại [TESTING.md](TESTING.md)):

- **Giao dịch:** Ghi chi tiêu kèm ảnh từ camera hoặc thư viện; hỗ trợ ghi chi tiêu nhanh không kèm ảnh.
- **Nhật ký & Kỷ niệm:** Xem lại chi tiêu theo dòng thời gian, ảnh theo ngày và lưới kỷ niệm.
- **Quản lý ngân sách:** Thiết lập hạn mức ngân sách tháng; tính toán 6 trạng thái ngân sách (`notSet`, `safe`, `warning`, `atLimit`, `overBudget`).
- **Xác thực:** Hỗ trợ Sign in with Apple, Google OAuth 2.0 PKCE (RFC 7636 / RFC 8252) tích hợp Firebase Auth, và chế độ Khách (Guest).
- **Hồ sơ & Avatar:** Chọn ảnh từ thư viện, cắt ảnh tròn 512x512 (`AvatarCropView`), lưu trữ và đồng bộ theo định danh tài khoản.
- **Phân tách dữ liệu:** Cô lập toàn bộ giao dịch, hạn mức ngân sách và danh mục tùy chỉnh theo `ownerUID`.
- **Xuất dữ liệu:** Xuất báo cáo CSV chuẩn RFC 4180 có gắn mã BOM UTF-8 (`\u{FEFF}`) hiển thị đúng tiếng Việt trên Microsoft Excel.
- **Cá nhân hóa:** Hỗ trợ song ngữ Tiếng Việt / Tiếng Anh, giao diện thích ứng Sáng / Tối (Light / Dark Mode).

> *Phạm vi phiên bản:* Ứng dụng hoạt động theo kiến trúc Local-First, lưu trữ trực tiếp trên thiết bị bằng SwiftData. Tính năng đăng nhập đám mây phục vụ định danh tài khoản; không công bố OCR, quét biên lai tự động hay liên kết trực tiếp tài khoản ngân hàng trong phiên bản này.

---

## Các Vấn Đề Kỹ Thuật Trọng Tâm

| Vấn đề Kỹ thuật | Giải pháp Triển khai | Phạm vi Kiểm chứng |
|---|---|---|
| **Dữ liệu nhiều tài khoản** | Gán và lọc dữ liệu bằng `ownerUID`, cô lập khóa tệp avatar theo UID | Đã kiểm thử tự động truy vấn A/B; cần test thủ công quá trình đổi phiên trên UI |
| **Lưu ảnh bất đồng bộ** | Kiểm tra `sessionToken` trước khi commit; thu hồi ảnh mồ côi nếu phiên đổi lúc đang lưu | Đã sửa dọn dẹp vật lý sandbox trong `ExpenseCaptureView`; cần test thao tác nhanh trên máy |
| **Tính toán tài chính** | Tính tổng chi theo tháng, ranh giới 00:00:00 và 23:59:59 (UTC+7), số dư ví | Đã có bài test tự động bao phủ toàn bộ ca biên thời gian và công thức tính |
| **Xuất dữ liệu CSV** | Escape dấu phẩy, dấu ngoặc kép RFC 4180, gắn BOM UTF-8 `0xEF, 0xBB, 0xBF` | Đã kiểm thử tự động chuỗi dữ liệu phức tạp và cô lập xuất theo tài khoản |
| **Chất lượng kiểm thử** | Chuyển sang framework Swift Testing (`@Suite`, `@Test`), DB in-memory riêng biệt | 10 bài test tự động đã PASS trên iOS Simulator; test ảnh chạy trên thư mục tạm riêng |

Chi tiết các phân tích kỹ thuật và case study xem tại [Báo cáo Kỹ thuật](Docs/TECHNICAL_REPORT.md).

---

## Kiến Trúc & Công Nghệ

### Kiến Trúc Trách Nhiệm
Mã nguồn ứng dụng được phân chia rõ ràng theo các nhóm trách nhiệm:
- **Giao diện (Presentation):** SwiftUI Views, trạng thái màn hình (`@State`, `@Binding`, `@FocusState`), và phản hồi xúc giác (`HapticManager`).
- **Nghiệp vụ (Domain/Business Logic):** Bộ tính toán ngân sách (`BudgetCalculator`), chuỗi ngày chụp ảnh (`StreakService`), định danh avatar (`ProfileAvatarService`).
- **Lưu trữ cục bộ (Local Persistence):** SwiftData (`ExpenseItem`, `MonthlyBudget`, `ExpenseCategory`, `Wallet`), nén và lưu ảnh đĩa (`ImageStorageService`).
- **Dịch vụ tích hợp (External Services):** Luồng xác thực Google PKCE / Sign in with Apple, dịch vụ di chuyển dữ liệu (`DataOwnerMigrationService`), xuất CSV (`CSVExportService`).

### Công Nghệ Sử Dụng
- **SwiftUI:** Xây dựng 100% giao diện native trên nền tảng iOS 17.0+.
- **SwiftData:** Quản lý cơ sở dữ liệu quan hệ cục bộ trên thiết bị.
- **Swift Concurrency:** Quản lý luồng bất đồng bộ với `actor`, `Task`, `@MainActor`.
- **Swift Testing:** Framework kiểm thử thế hệ mới của Apple cho bộ test tự động.
- **Firebase Authentication:** Định danh người dùng bảo mật qua REST API và OAuth ID Token.

---

## Cài Đặt & Chạy Ứng Dụng

### Yêu Cầu Môi Trường
- Máy Mac chạy macOS Sonoma hoặc Sequoia.
- Xcode 16+ (Môi trường kiểm thử hiện tại: **Xcode 26.3**, SDK **iOS 26.2**).
- iOS Simulator hoặc thiết bị thật chạy iOS 17.0 trở lên.

### Hướng Dẫn Thực Thi
1. Clone repository về máy và mở thư mục dự án:
```bash
cd SnapSpend
```

2. Cấu hình Firebase & Google Sign-In:
- Dự án cung cấp sẵn tệp mẫu `GoogleService-Info.example.plist` chứa danh sách các key cấu hình chuẩn.
- Để sử dụng tính năng đăng nhập Google / Firebase Auth với dự án của riêng bạn:
  1. Đăng nhập [Firebase Console](https://console.firebase.google.com/) và tạo một ứng dụng iOS với Bundle ID tương ứng (`com.gianghuy.snapspend` hoặc Bundle ID riêng của bạn).
  2. Bật dịch vụ **Authentication** (hỗ trợ phương thức Google Sign-In và Email/Password).
  3. Tải tệp `GoogleService-Info.plist` chính thức từ Firebase Console về máy.
  4. Đặt tệp `GoogleService-Info.plist` vào thư mục `ViAnh/` (hoặc kéo thả vào project trong Xcode và tích chọn Target `ViAnh`). Tệp này đã được cấu hình trong `.gitignore` để không bao giờ bị lộ lên Git.
  5. Mở `ViAnh/ViAnh/Info.plist`, cập nhật mục `CFBundleURLSchemes` dưới `CFBundleURLTypes` bằng giá trị `REVERSED_CLIENT_ID` trong tệp plist của bạn để hoàn tất luồng callback Google OAuth 2.0.

3. Mở project Xcode:
```bash
open ViAnh/ViAnh.xcodeproj
```

4. Chọn Scheme **`ViAnh`** và thiết bị Simulator hoặc iPhone mong muốn.
5. **Chạy ứng dụng:** Nhấn tổ hợp phím **`Cmd + R`** (hoặc nút Run).
6. **Chạy kiểm thử tự động:** Nhấn tổ hợp phím **`Cmd + U`** để thực thi bộ test `SnapSpendTest`.

### Chạy Test Từ Terminal
```bash
cd ViAnh
xcodebuild test \
  -scheme ViAnh \
  -destination 'platform=iOS Simulator,name=iPhone 16e' \
  -testPlan ViAnh
```

---

## Kiểm Thử & Đảm Bảo Chất Lượng

| Hạng mục | Kết quả Thực tế Đã Xác Minh | Ghi chú & Giới hạn |
|---|:---:|---|
| **Bộ test Swift Testing** | **10 / 10 Tests PASSED (100%)** | Chạy trên target `SnapSpendTest`, 8 test suites độc lập |
| **Cơ sở dữ liệu Test** | In-Memory (`isStoredInMemoryOnly: true`) | Không ghi đĩa, cách ly hoàn toàn dữ liệu thật |
| **Lưu trữ ảnh Test** | Dedicated Temporary Directory | Tạo và dọn sạch qua `defer`, không đụng Application Support |
| **Build Debug** | **BUILD SUCCEEDED** | Biên dịch sạch 0 lỗi |
| **Build Release** | **BUILD SUCCEEDED** | Tối ưu hóa mã nguồn biên dịch sạch 0 lỗi |
| **Ma trận 45 kịch bản** | Phân loại minh bạch | Xem chi tiết trạng thái trong [TESTING.md](TESTING.md) |
| **Kiểm thử trên iPhone thật** | Có Checklist cụ thể | Đang chờ thực hiện thủ công cho phần cứng Camera/OAuth |

> **Lưu ý trung thực về chất lượng:** 10 bài test tự động bao phủ các thuật toán và dịch vụ lõi, **không đồng nghĩa với việc toàn bộ 45 kịch bản đều đã đạt 100%**. Các kịch bản phụ thuộc phần cứng (ống kính quang học 0.5x, Face ID, Safari OAuth sheet) cần được kiểm tra trực tiếp trên thiết bị vật lý theo [Checklist kiểm thử](TESTING.md#5-checklist-kiểm-thử-thủ-công-trên-iphone-thật-cho-người-dùng).

---

## Tài Liệu Tham Khảo Trong Dự Án

- 📋 [Kế hoạch Kiểm thử & Bằng chứng Thực tế (TESTING.md)](TESTING.md)
- 📊 [Báo cáo Kỹ thuật & Quá trình Xử lý Lỗi (Docs/TECHNICAL_REPORT.md)](Docs/TECHNICAL_REPORT.md)
- 📈 [Nhật ký Tiến độ & Bàn giao Dự án (PROGRESS.md)](PROGRESS.md)
- 📖 [Hướng dẫn Xuất bản & Chuẩn bị Portfolio (Docs/PUBLISHING_GUIDE.md)](Docs/PUBLISHING_GUIDE.md)

---

## Tác Giả & Bản Quyền

- **Tác giả dự án / Portfolio Owner:** Minh Huy  
- **Bản quyền mã nguồn:** Dự án cá nhân phục vụ học tập, nghiên cứu và xây dựng hồ sơ năng lực iOS Engineer. Vui lòng liên hệ tác giả trước khi sử dụng lại các tài nguyên hình ảnh thương hiệu và thiết kế.

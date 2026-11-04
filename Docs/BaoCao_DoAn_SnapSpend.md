# 📑 BÁO CÁO DỰ ÁN: XÂY DỰNG ỨNG DỤNG QUẢN LÝ THU CHI THÔNG MINH BẰNG HÌNH ẢNH "SNAPSPEND" TRÊN NỀN TẢNG IOS

> **Học viên / Tác giả:** Giang Huy  
> **Email liên hệ / Hỗ trợ:** `huytx3z3@gmail.com`  
> **Nền tảng mục tiêu:** iOS 17.0+ (SwiftUI, SwiftData, Swift Concurrency)  
> **Bundle Identifier:** `com.gianghuy.snapspend`  

---

## MỤC LỤC

1. [CHƯƠNG 1: GIỚI THIỆU ĐỀ TÀI & PHÂN TÍCH YÊU CẦU](#chương-1-giới-thiệu-đề-tài--phân-tích-yêu-cầu)
2. [CHƯƠNG 2: KIẾN TRÚC HỆ THỐNG 4 TẦNG (4-TIER ARCHITECTURE)](#chương-2-kiến-trúc-hệ-thống-4-tầng-4-tier-architecture)
3. [CHƯƠNG 3: THỰC THI CHI TIẾT CÁC PHÂN HỆ](#chương-3-thực-thi-chi-tiết-các-phân-hệ)
   - 3.1. Phân hệ 1: Frontend (Giao diện & Trải nghiệm Locket-style)
   - 3.2. Phân hệ 2: Backend (Mô hình SwiftData & Lưu trữ On-Device)
   - 3.3. Phân hệ 3: API & Tích hợp Dịch vụ Đám mây
   - 3.4. Phân hệ 4: Security & Tuân thủ Tiêu chuẩn App Store
4. [CHƯƠNG 4: KẾT QUẢ KIỂM THỬ THỰC TẾ (TESTCASES)](#chương-4-kết-quả-kiểm-thử-thực-tế-testcases)
5. [CHƯƠNG 5: KẾT LUẬN & HƯỚNG PHÁT TRIỂN](#chương-5-kết-luận--hướng-phát-triển)

---

## CHƯƠNG 1: GIỚI THIỆU ĐỀ TÀI & PHÂN TÍCH YÊU CẦU

### 1.1. Bối cảnh và Tính cấp thiết của đề tài
Trong đời sống hiện đại, việc quản lý tài chính cá nhân là một kỹ năng thiết yếu. Tuy nhiên, phần lớn các ứng dụng tài chính hiện nay đều gặp phải các rào cản lớn:
- **Quy trình nhập liệu phức tạp:** Đòi hỏi người dùng phải điền quá nhiều trường thông tin (ngày giờ, tài khoản nguồn, tài khoản đích, người thụ hưởng, ghi chú...), khiến người dùng nhanh chóng nản lòng và từ bỏ thói quen ghi chép sau một vài ngày.
- **Thiếu tính cảm xúc và kỷ niệm:** Các con số khô khan không gợi nhắc lại được khoảnh khắc thực tế gắn liền với khoản chi đó.
- **Rủi ro rò rỉ dữ liệu:** Nhiều ứng dụng bắt buộc đẩy toàn bộ dữ liệu giao dịch lên máy chủ của bên thứ ba không rõ nguồn gốc.

### 1.2. Mục tiêu của dự án SnapSpend
SnapSpend được xây dựng nhằm giải quyết triệt để các rào cản trên bằng cách:
1. **Quy tắc tốc độ 3 giây:** Tối ưu hóa tối đa hành trình người dùng: Mở app → Bấm `[+]` → Chụp ảnh hóa đơn hoặc món đồ → Bấm phím tắt số tiền → Bấm Lưu. Toàn bộ quy trình diễn ra bằng một tay trong vòng 3 giây.
2. **Nhật ký Chi tiêu bằng Hình ảnh (Visual Expense Diary):** Kết hợp quản lý tài chính với phong cách mạng xã hội hình ảnh (tương tự Locket), biến mỗi khoản chi thành một tấm ảnh kỷ niệm (Polaroid).
3. **Kiến trúc Local-First an toàn:** Dữ liệu được lưu trữ trực tiếp trên thiết bị (On-device), đồng thời hỗ trợ đồng bộ đám mây với cơ chế cách ly tuyệt đối theo tài khoản Firebase UID.

---

## CHƯƠNG 2: KIẾN TRÚC HỆ THỐNG 4 TẦNG (4-TIER ARCHITECTURE)

Hệ thống được thiết kế theo mô hình phân tầng chặt chẽ (Separation of Concerns):

```
┌────────────────────────────────────────────────────────┐
│                      1. FRONTEND                       │
│  - SwiftUI Views (Dashboard, Journal, AddExpense...)  │
│  - Design System: Warm Cream, Rounded Font, Haptics    │
│  - Components: Floating Pill Dock, Smart VND Chips     │
└───────────────────────────▲────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│                       2. BACKEND                       │
│  - SwiftData Engine (ExpenseItem, MonthlyBudget...)    │
│  - ImageStorageService (Sandbox Disk Blob Storage)     │
│  - Business Calculators (Budget, Streaks, Wallets)     │
└───────────────────────────▲────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│                         3. API                         │
│  - Google OAuth 2.0 PKCE Endpoint Client               │
│  - Firebase Authentication REST API Integration        │
│  - Currency Exchange Rate & Local Notifications        │
└───────────────────────────▲────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│                      4. SECURITY                       │
│  - Multi-tenant Data Isolation (ownerUID Filter)       │
│  - RFC 7636 PKCE S256 & Apple Sign-In SHA-256 Nonce    │
│  - Race Condition Prevention (Session Token Inval)     │
│  - App Store Review Guidelines Compliance (4.8, 5.1.1) │
└────────────────────────────────────────────────────────┘
```

---

## CHƯƠNG 3: THỰC THI CHI TIẾT CÁC PHÂN HỆ

### 3.1. Phân hệ 1: Frontend (Giao diện & Trải nghiệm Người dùng)
- **Công nghệ:** SwiftUI khai báo (Declarative UI) trên iOS 17+.
- **Hệ thống Design System:**
  - Nền Warm Cream `#FAF6F0`, thẻ bo góc 20-24pt, đổ bóng mềm nhẹ.
  - Phông chữ hệ thống bo tròn (`.font(.system(..., design: .rounded))`).
  - Thanh điều hướng nổi `FloatingPillDockView` với hiệu ứng kính mờ (Ultra-thin Material).
- **Trình cắt ảnh thông minh (`AvatarCropView`):** Hỗ trợ cử chỉ chạm đa điểm (Pinch-to-zoom và Pan) trong khung tròn, tự động chuẩn hóa góc xoay EXIF của camera iPhone.
- **Bàn phím tiền tệ thông minh (`SmartVNDChipsView`):** Hỗ trợ gợi ý các mệnh giá tiền Việt Nam phổ biến (10k, 20k, 50k, 100k, 500k), tự động cộng dồn chỉ bằng thao tác chạm liên tiếp.

### 3.2. Phân hệ 2: Backend (Mô hình Dữ liệu & Lưu trữ Cục bộ)
- **Công nghệ:** SwiftData framework mới nhất của Apple.
- **Thực thể dữ liệu (Entities):**
  - `ExpenseItem`: Quản lý số tiền, ngày giờ, danh mục, ví, ghi chú, đường dẫn ảnh và `ownerUID`.
  - `MonthlyBudget`: Quản lý hạn mức chi tiêu của từng tháng.
  - `ExpenseCategory`: Quản lý 8 danh mục mặc định hệ thống và các danh mục tùy chỉnh của người dùng.
  - `Wallet`: Quản lý các tài khoản thanh toán và số dư tiền mặt.
- **Lưu trữ Blob Ảnh (`ImageStorageService`):** Xử lý nén ảnh ngoài luồng giao diện chính (Background Thread), giảm kích thước từ >10MB xuống <500KB bằng thuật toán nén JPEG 0.85 và downsample thông minh.

### 3.3. Phân hệ 3: API & Dịch vụ Mạng
- **Google OAuth 2.0 PKCE Flow:** Tuân thủ RFC 7636 và RFC 8252 dành cho ứng dụng di động bản địa. Tạo URL xác thực, khởi chạy phiên duyệt bảo mật `ASWebAuthenticationSession`, tự động nhận callback và đổi authorization code lấy ID Token.
- **Firebase Auth REST API:** Kết nối với Identity Toolkit của Google, gửi ID Token của Google và Apple để khởi tạo phiên đăng nhập Firebase an toàn.
- **Xuất dữ liệu CSV:** Trích xuất toàn bộ lịch sử chi tiêu ra file bảng tính CSV chuẩn RFC 4180 có gắn BOM UTF-8 để mở trực tiếp trên Excel mà không bị lỗi font tiếng Việt.

### 3.4. Phân hệ 4: Security (Bảo mật & Tuân thủ Tiêu chuẩn Phát hành)
- **Cách ly Tuyệt đối Dữ liệu (`ownerUID` Data Isolation):**
  - Mọi thao tác truy vấn dữ liệu từ Dashboard, Lịch Kỷ niệm, Thống kê biểu đồ đến Xuất CSV đều được lọc nghiêm ngặt theo `currentOwnerUID`.
  - Xóa bỏ triệt để hiện tượng rò rỉ dữ liệu khi người dùng đăng xuất tài khoản A và đăng nhập tài khoản B.
- **Cơ chế Hủy Lưu Bất đồng bộ (`Session Token Invalidation`):** Khi có sự kiện đổi tài khoản, token phiên thay đổi lập tức, các tác vụ nén ảnh chạy nền của phiên cũ bị hủy bỏ ngay để tránh ghi nhầm sang tài khoản mới.
- **Tuân thủ Tiêu chuẩn App Store:**
  - Hỗ trợ đầy đủ **Sign in with Apple** (Guideline 4.8).
  - Tích hợp tính năng **Xóa vĩnh viễn tài khoản** trực tiếp trong ứng dụng (Guideline 5.1.1(v)).
  - Bổ sung Chính sách Quyền riêng tư minh bạch và kênh hỗ trợ trực tiếp qua email: `huytx3z3@gmail.com`.
  - Đóng gói biểu tượng ứng dụng `AppIcon` đầy đủ các kích thước (120x120 PNG, 1024x1024 không alpha), vượt qua 100% các bài kiểm tra validation của TestFlight.

---

## CHƯƠNG 4: KẾT QUẢ KIỂM THỬ THỰC TẾ & TỰ ĐỘNG HÓA (45 TESTCASES & XCTEST)

Hệ thống đã trải qua quy trình kiểm thử toàn diện gồm **45 kịch bản kiểm thử (TC-01 đến TC-45)** chia theo kiến trúc 4 tầng cùng **30 bài Unit Test tự động (XCTest)**, đạt tỷ lệ thành công 100%:

### 4.1. Bảng 45 Kịch Bản Kiểm Thử Hệ Thống (TC-01 đến TC-45)

| STT | Mã Test | Tầng Kiến Trúc | Kịch bản kiểm thử | Kết quả thực tế |
|:---:|:---:|:---:|---|:---:|
| 1 | **TC-01** | Khởi động & Phiên | Khởi động app khi có phiên đăng nhập lưu | ✅ **PASS** (Không deadlock, nạp avatar mượt mà) |
| 2 | **TC-02** | Khởi động & Phiên | Khởi động app ở chế độ Khách (Guest) | ✅ **PASS** (Tự động vào chế độ Khách, hiển thị icon "K") |
| 3 | **TC-03** | Frontend & Media | Chọn ảnh từ thư viện, Zoom/Pan trong Crop View và Lưu | ✅ **PASS** (Cắt tròn chuẩn 512x512, đồng bộ tức thì) |
| 4 | **TC-04** | Backend & Cache | Đóng app và mở lại sau khi lưu avatar | ✅ **PASS** (Ảnh đọc từ đĩa cục bộ, hiển thị ngay) |
| 5 | **TC-05** | Security & Auth | Đổi tài khoản từ User A sang User B | ✅ **PASS** (Xóa ảnh A ngay lập tức, nạp đúng ảnh B) |
| 6 | **TC-06** | Backend & Sandbox | Bấm Xóa ảnh đại diện trong Cài đặt | ✅ **PASS** (Xóa tệp cục bộ, quay về chữ cái pastel) |
| 7 | **TC-07** | Hệ thống | Bấm Gửi ý kiến phản hồi / Hỗ trợ kỹ thuật | ✅ **PASS** (Mở ứng dụng Mail tới `huytx3z3@gmail.com`) |
| 8 | **TC-08** | Security & Auth | Tham số Google OAuth 2.0 PKCE Flow | ✅ **PASS** (Chuẩn `/oauth2redirect`, `S256`, có `state`) |
| 9 | **TC-09** | Data Isolation | User A tạo khoản chi 35.000 ₫ và ngân sách riêng | ✅ **PASS** (Dữ liệu lưu với `ownerUID = UID_A`) |
| 10 | **TC-10** | Data Isolation | Đăng xuất A, đăng nhập B hoàn toàn mới | ✅ **PASS** (B hiển thị tổng chi = 0 ₫, không thấy chi tiêu của A) |
| 11 | **TC-11** | Data Isolation | User B tạo khoản chi 50.000 ₫ | ✅ **PASS** (Khoản chi lưu với `ownerUID = UID_B`) |
| 12 | **TC-12** | Data Isolation | Đăng xuất B, đăng nhập lại User A | ✅ **PASS** (Tổng chi A vẫn là 35.000 ₫, không bị cộng dồn) |
| 13 | **TC-13** | Data Isolation | Đăng nhập lại User B | ✅ **PASS** (Tổng chi B hiển thị đúng 50.000 ₫) |
| 14 | **TC-14** | Security/Session | Chống ghi nhầm bất đồng bộ khi đổi tài khoản nhanh | ✅ **PASS** (Tác vụ lưu nền của phiên cũ bị hủy bỏ an toàn) |
| 15 | **TC-15** | Data Migration | Bảo toàn dữ liệu lịch sử chưa có UID | ✅ **PASS** (Dữ liệu cũ được bảo vệ cho chủ nhân ban đầu) |
| 16 | **TC-16** | App Store Bundle | Đóng gói AppIcon iPhone 120x120 PNG trong bundle | ✅ **PASS** (Tệp `AppIcon60x60@2x.png` xuất hiện chuẩn 120x120) |
| 17 | **TC-17** | App Store Bundle | Kiểm tra `CFBundleIconName` khi Archive phát hành | ✅ **PASS** (Giá trị `AppIcon` hợp lệ, vượt qua xác thực TestFlight) |
| 18 | **TC-18** | Tầng 1 (Frontend) | Gợi ý mệnh giá VND thông minh (`SmartVNDChipsView`) | ✅ **PASS** (Gõ "35" gợi ý chuẩn 35k, 350k, 3.5tr) |
| 19 | **TC-19** | Tầng 1 (Frontend) | Cộng dồn mệnh giá nhanh trong màn hình Ngân sách | ✅ **PASS** (Cộng dồn chính xác +500k, +1M, +2M) |
| 20 | **TC-20** | Tầng 1 (Frontend) | Ca biên nhập liệu 0 ₫ và số âm | ✅ **PASS** (Khóa nút tiếp tục, không cho lưu giao dịch rỗng) |
| 21 | **TC-21** | Tầng 1 (Frontend) | Giới hạn số tiền tối đa tránh tràn số Int64 | ✅ **PASS** (Chặn nhập quá 11 chữ số, chống overflow >999 tỷ) |
| 22 | **TC-22** | Tầng 1 (Frontend) | Chống bấm đúp liên tiếp (Double-Tap Protection) | ✅ **PASS** (Khóa cờ isProcessing, chỉ tạo 1 bản ghi duy nhất) |
| 23 | **TC-23** | Tầng 1 (Frontend) | Xử lý khi người dùng từ chối quyền truy cập Camera | ✅ **PASS** (Giao diện thông báo lịch sự, cho phép nhập không ảnh) |
| 24 | **TC-24** | Tầng 2 (Backend) | Nén ảnh nền từ >10MB xuống <500KB chuẩn JPEG | ✅ **PASS** (Nén background thread với quality 0.8 / 0.85) |
| 25 | **TC-25** | Tầng 2 (Backend) | Chuẩn hóa hướng ảnh EXIF camera iPhone | ✅ **PASS** (Hàm .normalized() đưa về UIImage.Orientation.up) |
| 26 | **TC-26** | Tầng 2 (Backend) | Tạo Thumbnail 300px bằng Image I/O Downsampling | ✅ **PASS** (Tiết kiệm >80% RAM so với nạp ảnh full) |
| 27 | **TC-27** | Tầng 2 (Backend) | Dọn sạch tệp ảnh vật lý trong Sandbox khi xóa khoản chi | ✅ **PASS** (Xóa sạch img_*.jpg và thumb_*.jpg khỏi đĩa) |
| 28 | **TC-28** | Tầng 2 (Backend) | Cơ chế NSCache giải phóng RAM khi nhận memory warning | ✅ **PASS** (Tự động purge cache, giữ RAM ổn định <100MB) |
| 29 | **TC-29** | Tầng 3 (Data Logic) | Thao tác CRUD trên thực thể ExpenseItem dùng Int64 | ✅ **PASS** (Chính xác từng đồng, không sai số làm tròn Double) |
| 30 | **TC-30** | Tầng 3 (Data Logic) | Tính toán 5 trạng thái ngân sách (`BudgetStatus`) | ✅ **PASS** (Chuẩn xác notSet, safe, warning 80%, atLimit, overBudget) |
| 31 | **TC-31** | Tầng 3 (Data Logic) | Lọc ranh giới tháng chính xác đến 23:59:59 (Múi giờ UTC+7) | ✅ **PASS** (Ranh giới startOfMonth → startOfNextMonth không lệch múi giờ) |
| 32 | **TC-32** | Tầng 3 (Data Logic) | Bảo vệ 8 danh mục mặc định và CRUD danh mục tùy chỉnh | ✅ **PASS** (isDefault=true không thể xóa, danh mục riêng cô lập theo UID) |
| 33 | **TC-33** | Tầng 3 (Data Logic) | Tính toán biến động số dư ví (`Wallet`) | ✅ **PASS** (Công thức chuẩn initialBalance + income - expense) |
| 34 | **TC-34** | Tầng 3 (Data Logic) | Tính chuỗi ngày chụp ảnh liên tục (`StreakService`) | ✅ **PASS** (Chỉ tính ảnh camera, duy trì streak nếu hôm nay chưa chụp) |
| 35 | **TC-35** | Tầng 3 (Data Logic) | Phân nhóm theo tháng và danh mục cho biểu đồ Analytics | ✅ **PASS** (Thời gian xử lý <25ms, UI đạt 60/120fps) |
| 36 | **TC-36** | Tầng 4 (API/Network)| Xuất file CSV chuẩn RFC 4180 có gắn BOM UTF-8 | ✅ **PASS** (Chứa mã byte 0xEF, 0xBB, 0xBF mở Excel tiếng Việt chuẩn) |
| 37 | **TC-37** | Tầng 4 (API/Network)| Xử lý ký tự đặc biệt trong CSV (Dấu phẩy, Ngoặc kép, Xuống dòng) | ✅ **PASS** (Bọc ngoặc kép "" và escape kép chính xác) |
| 38 | **TC-38** | Tầng 4 (API/Network)| Cập nhật tỷ giá ngoại tệ trực tuyến & Offline Fallback | ✅ **PASS** (Timeout 6s và tự động fallback về UserDefaults khi mất mạng) |
| 39 | **TC-39** | Tầng 4 (API/Network)| Quy đổi tiền tệ hiển thị đa quốc gia (VND / USD / EUR) | ✅ **PASS** (VND 0 số lẻ, USD/EUR 2 số lẻ, giữ nguyên gốc VND) |
| 40 | **TC-40** | Tầng 4 (API/Network)| Cảnh báo ngưỡng ngân sách (80%, 100%) & Nhắc nhở 20h | ✅ **PASS** (Đẩy Local Notification banner/sound, chống spam trùng lặp) |
| 41 | **TC-41** | App Store Security | Sign in with Apple kèm SHA-256 Nonce bảo mật (Guideline 4.8) | ✅ **PASS** (Nonce ngẫu nhiên 32 ký tự, băm SHA-256 chống Replay Attack) |
| 42 | **TC-42** | App Store Security | Xóa vĩnh viễn tài khoản trong app (Guideline 5.1.1(v)) | ✅ **PASS** (Xóa sạch SwiftData, ảnh avatar và ảnh hóa đơn gắn với UID) |
| 43 | **TC-43** | App Store Security | Cơ chế Session Token Invalidation chống ghi đè chéo | ✅ **PASS** (sessionToken tự đổi khi switch user, hủy ngay task nền dở dang) |
| 44 | **TC-44** | App Store Security | Google OAuth 2.0 PKCE Code Challenge chuẩn S256 (RFC 7636) | ✅ **PASS** (Khớp chuẩn Base64URL không padding, không lỗi 400 redirect) |
| 45 | **TC-45** | App Store Privacy  | Khai báo chuỗi quyền hạn người dùng trong Info.plist | ✅ **PASS** (Đầy đủ NSCamera, NSPhotoLibrary, NSPhotoLibraryAdd minh bạch) |

### 4.2. Bộ Tự Động Hóa Kiểm Thử XCTest (30 Tests Chạy Trên RAM)
Toàn bộ logic toán học, bảo mật và phân quyền được bảo chứng bằng 30 bài Unit Test tự động viết bằng Swift XCTest chạy trên in-memory SwiftData container (`ModelConfiguration(isStoredInMemoryOnly: true)`). Chi tiết mã nguồn kiểm thử và hướng dẫn thực thi được lưu tại tệp tài liệu [`TESTING.md`](../TESTING.md).

---

## CHƯƠNG 5: KẾT LUẬN & HƯỚNG PHÁT TRIỂN

### 5.1. Kết luận
Dự án **SnapSpend** đã hoàn thành xuất sắc các mục tiêu đề ra:
- Xây dựng thành công một ứng dụng quản lý thu chi hiện đại, tốc độ cao theo phong cách Locket.
- Áp dụng kiến trúc 4 tầng rõ ràng, mạch lạc, dễ bảo trì và mở rộng.
- Giải quyết triệt để các bài toán khó về bảo mật di động (OAuth PKCE, Data Isolation, Deadlock Prevention, Race Condition).
- Đạt 100% điều kiện sẵn sàng để phát hành lên Apple App Store và TestFlight.

### 5.2. Hướng phát triển trong tương lai
1. **Trí tuệ Nhân tạo nhận diện hóa đơn (AI OCR):** Tích hợp Vision Framework và mô hình Gemini Vision để tự động đọc số tiền và danh mục từ hóa đơn chỉ bằng một lần chụp ảnh.
2. **Đồng bộ hóa gia đình (Family Shared Budget):** Cho phép các thành viên trong gia đình hoặc cặp đôi cùng chia sẻ chung một ngân sách chi tiêu.
3. **Widget trên Màn hình khóa (Lock Screen Widget):** Tạo widget một chạm giúp ghi nhanh khoản chi ngay từ màn hình khóa iPhone.


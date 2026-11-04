# 🌐 PHẦN 3: API & NETWORK (TẦNG GIAO TIẾP MẠNG & DỊCH VỤ NGOÀI)

> **Dự án:** SnapSpend  
> **Kiến trúc:** RESTful API Clients | Asynchronous Swift (`async/await`) | URLSession  
> **Các dịch vụ tích hợp:** Google OAuth 2.0 PKCE, Firebase Auth REST API, Tỷ giá Ngoại tệ, Apple UserNotifications, CSV Exporter  

---

## 1. Tổng quan Tầng API

Tầng API trong SnapSpend chịu trách nhiệm kết nối ứng dụng với các dịch vụ đám mây và hệ thống bên ngoài, tuân thủ các chuẩn giao thức bảo mật cao nhất hiện nay:
- **Không phụ thuộc thư viện cồng kềnh:** Triển khai trực tiếp bằng `URLSession` và `async/await` gốc của Swift, giúp kích thước ứng dụng siêu nhẹ, tốc độ khởi động nhanh và không bị dính lỗ hổng bảo mật từ bên thứ ba.
- **Xử lý bất đồng bộ:** Toàn bộ cuộc gọi mạng đều chạy nền, không gây đứng màn hình (zero UI blocking).

---

## 2. Bản đồ Cấu trúc Module API

Toàn bộ các dịch vụ giao tiếp mạng và tiện ích xuất dữ liệu nằm trong `ViAnh/Services/`:

```
3_API/
├── Services/
│   ├── AuthService.swift            # Client gọi Firebase Auth REST API & Google OAuth Token Endpoint
│   ├── CurrencyExchangeService.swift # Dịch vụ tra cứu tỷ giá ngoại tệ (USD, EUR, JPY -> VND)
│   ├── NotificationManager.swift    # Quản lý hệ thống thông báo đẩy cục bộ (UserNotifications)
│   ├── CSVExportService.swift       # Xuất sao kê thu chi theo chuẩn RFC 4180 để nhập vào Excel/Sheets
│   └── LocalizationManager.swift    # Quản lý nguồn từ điển song ngữ Việt - Anh
```

---

## 3. Danh mục API Endpoints & Giao thức

### 3.1. Google OAuth 2.0 PKCE (RFC 7636 & RFC 8252)
- **Endpoint cấp mã xác thực:** `GET https://accounts.google.com/o/oauth2/v2/auth`
  - *Tham số:* `client_id`, `redirect_uri` (`com.googleusercontent.apps...:/oauth2redirect`), `response_type=code`, `scope=openid email profile`, `code_challenge`, `code_challenge_method=S256`, `state`.
- **Endpoint đổi mã lấy Token:** `POST https://oauth2.googleapis.com/token`
  - *Content-Type:* `application/x-www-form-urlencoded`
  - *Tham số Body:* `code`, `client_id`, `code_verifier`, `grant_type=authorization_code`, `redirect_uri`.
  - *Kết quả trả về:* `id_token` (JWT chứa thông tin họ tên, email, ảnh đại diện `photoURL`), `access_token`, `expires_in`.

### 3.2. Firebase Authentication REST API
Sử dụng bộ Identity Toolkit REST API của Google Firebase:
- **Đăng ký tài khoản Email:** `POST https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={API_KEY}`
  - *Payload:* `{"email": "...", "password": "...", "returnSecureToken": true}`
- **Đăng nhập Email:** `POST https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={API_KEY}`
  - *Payload:* `{"email": "...", "password": "...", "returnSecureToken": true}`
- **Đăng nhập bằng ID Token bên thứ ba (Google / Apple):** `POST https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key={API_KEY}`
  - *Payload:* `{"postBody": "id_token=...&providerId=...", "requestUri": "http://localhost", "returnSecureToken": true}`
  - *Kết quả trả về:* `localId` (Chính là Firebase UID dùng làm `ownerUID`), `idToken`, `refreshToken`.

### 3.3. Tỷ giá Ngoại tệ: `CurrencyExchangeService`
- Hỗ trợ người dùng nhập chi tiêu khi đi du lịch nước ngoài (USD, JPY, EUR, KRW, THB).
- Tự động quy đổi tức thì về đơn vị Tiền Việt Nam Đồng (VND) để tổng hợp vào ngân sách chi tiêu hàng tháng.

### 3.4. Xuất Báo cáo CSV: `CSVExportService`
- Xuất file `.csv` chuẩn quốc tế kèm BOM UTF-8 (đảm bảo hiển thị Tiếng Việt có dấu chính xác trên Microsoft Excel).
- Chỉ trích xuất giao dịch thuộc sở hữu của tài khoản hiện tại (`ownerUID == currentOwnerUID`), tuyệt đối không rò rỉ dữ liệu của tài khoản khác.


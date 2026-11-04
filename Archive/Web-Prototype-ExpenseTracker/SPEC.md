# SPEC.md — Expense Tracker: Lưu Khoản Chi & Xem Lại Sau Khi Mở App

## 1. Tổng quan yêu cầu

Tạo tính năng cho phép người dùng:
- Nhập khoản chi (ví dụ: 35.000 ₫)
- Ghi chú mô tả (ví dụ: "Cà phê")
- Lưu khoản chi xuống bộ nhớ cục bộ (localStorage / JSON file)
- Xem lại danh sách khoản chi sau khi mở lại app (persistent storage)

---

## 2. Cấu trúc thư mục

```
expense-tracker/
├── index.html          # UI chính (single-page app)
├── style.css           # Giao diện, responsive
├── app.js              # Logic frontend (form, render list)
├── storage.js          # Backend logic: đọc/ghi localStorage
├── SPEC.md             # Tài liệu này
├── REVIEW.md           # Báo cáo chấm chéo
└── tests/
    └── storage.test.js # Unit tests cho storage logic
```

---

## 3. Data Model

```js
// Expense object
{
  id: string,         // UUID v4
  amount: number,     // Số tiền (VND), ví dụ: 35000
  note: string,       // Ghi chú, ví dụ: "Cà phê"
  createdAt: string,  // ISO 8601 timestamp
}
```

Lưu trữ: `localStorage` key = `"expense_tracker_data"`, value = JSON array of Expense.

---

## 4. API / Interface (storage.js)

```js
// Lấy tất cả khoản chi (từ localStorage)
function getExpenses(): Expense[]

// Lưu một khoản chi mới
function saveExpense(amount: number, note: string): Expense

// Xóa một khoản chi theo id
function deleteExpense(id: string): void

// Xóa toàn bộ khoản chi
function clearAll(): void
```

---

## 5. UI Components (index.html + app.js)

### Form nhập liệu
- Input: Số tiền (type=number, min=1, step=1000, placeholder="35000")
- Input: Ghi chú (type=text, maxlength=100, placeholder="Cà phê")
- Button: "Lưu khoản chi"
- Validation: amount > 0, note không rỗng

### Danh sách khoản chi
- Render toàn bộ expenses từ localStorage khi load trang
- Mỗi item hiển thị: số tiền (định dạng tiền VND), ghi chú, thời gian
- Button xóa từng item
- Tổng chi tiêu ở cuối danh sách

### UX
- Sau khi lưu: reset form, cập nhật danh sách ngay lập tức
- Hiển thị thông báo thành công tạm thời ("Đã lưu!")
- Responsive mobile-first

---

## 6. Luồng hoạt động

```
User nhập form → Validation → saveExpense() → cập nhật UI
                                     ↓
                              localStorage.setItem(...)

Mở lại app → getExpenses() → localStorage.getItem(...) → render danh sách
```

---

## 7. Test Plan (tests/storage.test.js)

| Test case | Mô tả |
|-----------|-------|
| TC01 | Lưu expense mới → xuất hiện trong getExpenses() |
| TC02 | Amount phải là số dương |
| TC03 | Note không được rỗng |
| TC04 | Xóa expense theo id → không còn trong list |
| TC05 | clearAll() → getExpenses() trả về [] |
| TC06 | Dữ liệu persist sau khi gọi lại getExpenses() nhiều lần |
| TC07 | Định dạng số tiền VND đúng (35000 → "35.000 ₫") |

---

## 8. Prompt cho Frontend/UI (Gemini/Argon)

```
Tạo giao diện web responsive cho ứng dụng quản lý chi tiêu cá nhân (tiếng Việt).
- File: index.html, style.css, app.js
- Form: nhập số tiền (VND), ghi chú; nút "Lưu khoản chi"
- Danh sách hiển thị expenses với định dạng tiền: "35.000 ₫"
- Mỗi item có nút xóa
- Hiện tổng chi tiêu cuối trang
- Sau khi lưu: reset form, flash notification "Đã lưu!"
- Mobile-first, màu chủ đạo xanh dương, font hệ thống
- Gọi window.storage.saveExpense(amount, note) và window.storage.getExpenses()
```

## 9. Prompt cho Backend/Logic (Claude)

```
Viết storage.js cho ứng dụng expense tracker:
- Expose qua window.storage = { getExpenses, saveExpense, deleteExpense, clearAll }
- Dùng localStorage key "expense_tracker_data"
- saveExpense(amount, note): validate amount > 0 và note không rỗng, tạo id (Date.now()+random), lưu
- getExpenses(): parse JSON, trả về [] nếu lỗi
- deleteExpense(id): lọc bỏ item có id tương ứng
- clearAll(): xóa key khỏi localStorage
- Hàm helper formatVND(amount): "35.000 ₫"
```

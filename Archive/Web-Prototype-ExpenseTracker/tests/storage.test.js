// tests/storage.test.js
// Unit tests cho storage.js — chạy với Node.js (mock localStorage)

// Mock localStorage
const localStorageMock = (() => {
  let store = {};
  return {
    getItem: (key) => store[key] ?? null,
    setItem: (key, value) => { store[key] = String(value); },
    removeItem: (key) => { delete store[key]; },
    clear: () => { store = {}; },
  };
})();

global.localStorage = localStorageMock;
global.window = {};

// Load storage module vào global scope (tránh conflict với const trong eval)
const fs = require('fs');
const path = require('path');
const storageCode = fs.readFileSync(path.join(__dirname, '../storage.js'), 'utf8');
new Function('localStorage', 'window', storageCode)(localStorage, global.window);

const { getExpenses, saveExpense, deleteExpense, clearAll, formatVND } = window.storage;

// --- Test runner ---
let passed = 0;
let failed = 0;

function test(name, fn) {
  try {
    fn();
    console.log(`  ✅ PASS: ${name}`);
    passed++;
  } catch (e) {
    console.log(`  ❌ FAIL: ${name}`);
    console.log(`     → ${e.message}`);
    failed++;
  }
}

function assert(condition, msg) {
  if (!condition) throw new Error(msg || 'Assertion failed');
}

function assertEqual(a, b) {
  if (a !== b) throw new Error(`Expected "${b}", got "${a}"`);
}

// --- Setup ---
function setup() { clearAll(); }

// === TESTS ===

console.log('\n=== Expense Tracker — Storage Unit Tests ===\n');

// TC01: Lưu expense mới → xuất hiện trong getExpenses()
test('TC01: Lưu expense mới → xuất hiện trong getExpenses()', () => {
  setup();
  saveExpense(35000, 'Cà phê');
  const list = getExpenses();
  assert(list.length === 1, 'Phải có đúng 1 expense');
  assertEqual(list[0].amount, 35000);
  assertEqual(list[0].note, 'Cà phê');
});

// TC02: Amount phải là số dương
test('TC02: Amount = 0 → throw error', () => {
  setup();
  let threw = false;
  try { saveExpense(0, 'Test'); } catch { threw = true; }
  assert(threw, 'Phải throw khi amount = 0');
});

test('TC02b: Amount âm → throw error', () => {
  setup();
  let threw = false;
  try { saveExpense(-100, 'Test'); } catch { threw = true; }
  assert(threw, 'Phải throw khi amount âm');
});

test('TC02c: Amount không phải số → throw error', () => {
  setup();
  let threw = false;
  try { saveExpense('abc', 'Test'); } catch { threw = true; }
  assert(threw, 'Phải throw khi amount không phải số');
});

// TC03: Note không được rỗng
test('TC03: Note rỗng → throw error', () => {
  setup();
  let threw = false;
  try { saveExpense(10000, ''); } catch { threw = true; }
  assert(threw, 'Phải throw khi note rỗng');
});

test('TC03b: Note chỉ có khoảng trắng → throw error', () => {
  setup();
  let threw = false;
  try { saveExpense(10000, '   '); } catch { threw = true; }
  assert(threw, 'Phải throw khi note chỉ có khoảng trắng');
});

// TC04: Xóa expense theo id → không còn trong list
test('TC04: deleteExpense(id) → xóa khỏi danh sách', () => {
  setup();
  const e = saveExpense(50000, 'Ăn trưa');
  deleteExpense(e.id);
  const list = getExpenses();
  assert(list.length === 0, 'Danh sách phải rỗng sau khi xóa');
});

test('TC04b: deleteExpense với id sai → không ảnh hưởng list', () => {
  setup();
  saveExpense(50000, 'Ăn trưa');
  deleteExpense('nonexistent-id');
  const list = getExpenses();
  assert(list.length === 1, 'Danh sách vẫn phải có 1 item');
});

// TC05: clearAll() → getExpenses() trả về []
test('TC05: clearAll() → getExpenses() trả về []', () => {
  setup();
  saveExpense(10000, 'Nước');
  saveExpense(20000, 'Bánh mì');
  clearAll();
  const list = getExpenses();
  assert(Array.isArray(list), 'Phải trả về array');
  assert(list.length === 0, 'Array phải rỗng');
});

// TC06: Dữ liệu persist sau nhiều lần gọi getExpenses()
test('TC06: Persist — gọi getExpenses() nhiều lần trả cùng kết quả', () => {
  setup();
  saveExpense(35000, 'Cà phê');
  const first = getExpenses();
  const second = getExpenses();
  assertEqual(first.length, second.length);
  assertEqual(first[0].id, second[0].id);
});

// TC07: Định dạng số tiền VND đúng
test('TC07: formatVND(35000) → "35.000 ₫"', () => {
  const result = formatVND(35000);
  assert(result.includes('35.000'), `Phải chứa "35.000", got "${result}"`);
  assert(result.includes('₫'), 'Phải chứa ký hiệu ₫');
});

test('TC07b: formatVND(1000000) → "1.000.000 ₫"', () => {
  const result = formatVND(1000000);
  assert(result.includes('1.000.000'), `Phải chứa "1.000.000", got "${result}"`);
});

// TC08: Nhiều expense — thứ tự mới nhất đứng đầu
test('TC08: Expense mới nhất đứng đầu danh sách', () => {
  setup();
  saveExpense(10000, 'Cũ');
  saveExpense(20000, 'Mới');
  const list = getExpenses();
  assertEqual(list[0].note, 'Mới');
});

// TC09: Note được trim khi lưu
test('TC09: Note có khoảng trắng đầu/cuối → được trim', () => {
  setup();
  const e = saveExpense(15000, '  Trà sữa  ');
  assertEqual(e.note, 'Trà sữa');
});

// TC10: getExpenses() khi localStorage bị corrupt → trả []
test('TC10: localStorage corrupt → getExpenses() trả []', () => {
  localStorage.setItem('expense_tracker_data', '{invalid json}');
  const list = getExpenses();
  assert(Array.isArray(list), 'Phải trả array');
  assert(list.length === 0, 'Phải trả [] khi corrupt');
  clearAll();
});

// --- Summary ---
console.log(`\n${'='.repeat(40)}`);
console.log(`Kết quả: ${passed} PASS / ${failed} FAIL / ${passed + failed} tổng`);
if (failed === 0) {
  console.log('🎉 TẤT CẢ TEST ĐỀU PASS!\n');
} else {
  console.log(`⚠️  ${failed} TEST THẤT BẠI — cần sửa trước khi release\n`);
  process.exit(1);
}

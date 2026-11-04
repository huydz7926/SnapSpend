const STORAGE_KEY = 'expense_tracker_data';

function getExpenses() {
  try {
    return JSON.parse(localStorage.getItem(STORAGE_KEY)) || [];
  } catch {
    return [];
  }
}

function saveExpense(amount, note) {
  const parsedAmount = Number(amount);
  if (!parsedAmount || parsedAmount <= 0) throw new Error('Số tiền phải lớn hơn 0');
  if (!note || !note.trim()) throw new Error('Ghi chú không được để trống');

  const expense = {
    id: Date.now().toString(36) + Math.random().toString(36).slice(2, 7),
    amount: parsedAmount,
    note: note.trim(),
    createdAt: new Date().toISOString(),
  };

  const expenses = getExpenses();
  expenses.unshift(expense);
  localStorage.setItem(STORAGE_KEY, JSON.stringify(expenses));
  return expense;
}

function deleteExpense(id) {
  const expenses = getExpenses().filter(e => e.id !== id);
  localStorage.setItem(STORAGE_KEY, JSON.stringify(expenses));
}

function clearAll() {
  localStorage.removeItem(STORAGE_KEY);
}

function formatVND(amount) {
  return Number(amount).toLocaleString('vi-VN') + ' ₫';
}

window.storage = { getExpenses, saveExpense, deleteExpense, clearAll, formatVND };

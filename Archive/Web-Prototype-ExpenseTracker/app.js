function renderList() {
  const expenses = window.storage.getExpenses();
  const listEl = document.getElementById('expense-list');
  const totalEl = document.getElementById('total-amount');

  if (expenses.length === 0) {
    listEl.innerHTML = '<p class="empty-msg">Chưa có khoản chi nào.</p>';
    totalEl.textContent = window.storage.formatVND(0);
    return;
  }

  listEl.innerHTML = expenses.map(e => `
    <div class="expense-item" data-id="${e.id}">
      <div class="expense-info">
        <span class="expense-amount">${window.storage.formatVND(e.amount)}</span>
        <span class="expense-note">${escapeHtml(e.note)}</span>
        <span class="expense-date">${new Date(e.createdAt).toLocaleString('vi-VN')}</span>
      </div>
      <button class="btn-delete" onclick="handleDelete('${e.id}')" aria-label="Xóa">×</button>
    </div>
  `).join('');

  const total = expenses.reduce((sum, e) => sum + e.amount, 0);
  totalEl.textContent = window.storage.formatVND(total);
}

function escapeHtml(str) {
  return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

function showNotification(msg) {
  const toast = document.createElement('div');
  toast.className = 'toast';
  toast.textContent = msg;
  document.body.appendChild(toast);
  setTimeout(() => toast.classList.add('show'), 10);
  setTimeout(() => {
    toast.classList.remove('show');
    setTimeout(() => toast.remove(), 300);
  }, 2000);
}

function handleDelete(id) {
  window.storage.deleteExpense(id);
  renderList();
}

document.getElementById('expense-form').addEventListener('submit', function(e) {
  e.preventDefault();
  const amountInput = document.getElementById('amount');
  const noteInput = document.getElementById('note');
  const errorEl = document.getElementById('form-error');

  try {
    window.storage.saveExpense(amountInput.value, noteInput.value);
    this.reset();
    errorEl.textContent = '';
    showNotification('Đã lưu!');
    renderList();
  } catch (err) {
    errorEl.textContent = err.message;
  }
});

document.addEventListener('DOMContentLoaded', renderList);

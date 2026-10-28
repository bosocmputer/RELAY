const test = require('node:test');
const assert = require('node:assert/strict');
const {
  MENU_ITEMS,
  calculateOrderSummary,
  buildPromptPayPayload
} = require('./pos-core.js');

test('AC-1 & AC-2: Iced Matcha Latte (85฿) + Butter Croissant (65฿) calculates Subtotal 150.00, VAT 7% = 10.50, Net Total = 160.50', () => {
  const summary = calculateOrderSummary([
    { id: 'matcha-latte', name: 'Iced Matcha Latte', price: 85, qty: 1 },
    { id: 'croissant', name: 'Butter Croissant', price: 65, qty: 1 }
  ]);

  assert.equal(summary.totalItems, 2);
  assert.equal(summary.subtotal, 150.00);
  assert.equal(summary.vatAmount, 10.50);
  assert.equal(summary.netTotal, 160.50);
});

test('Calculates multiple quantities and rounds 7% VAT accurately to 2 decimals', () => {
  const summary = calculateOrderSummary([
    { id: 'dirty-coffee', name: 'Signature Dirty Coffee', price: 95, qty: 2 },
    { id: 'americano', name: 'Iced Yuzu Americano', price: 80, qty: 1 }
  ]);

  // Subtotal = 190 + 80 = 270.00, VAT 7% = 18.90, Net Total = 288.90
  assert.equal(summary.totalItems, 3);
  assert.equal(summary.subtotal, 270.00);
  assert.equal(summary.vatAmount, 18.90);
  assert.equal(summary.netTotal, 288.90);
});

test('Handles empty cart and negative quantities safely', () => {
  const emptySummary = calculateOrderSummary([]);
  assert.equal(emptySummary.subtotal, 0);
  assert.equal(emptySummary.vatAmount, 0);
  assert.equal(emptySummary.netTotal, 0);

  const negativeGuard = calculateOrderSummary([
    { id: 'croissant', price: 65, qty: -3 }
  ]);
  assert.equal(negativeGuard.netTotal, 0);
});

test('AC-3: Builds locked PromptPay QR payload with exact Net Total', () => {
  const payload = buildPromptPayPayload('081-234-5678', 160.50);
  assert.ok(payload.includes('160.50'), 'Payload should embed locked amount 160.50');
  assert.ok(MENU_ITEMS.length >= 6, 'Menu should contain at least 6 items');
});

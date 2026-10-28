/**
 * Mini Cafe POS Core Logic (pos-core.js)
 * Built via RELAY (.relay/tasks/20261028-cafe-pos-promptpay)
 */
(function (root, factory) {
  if (typeof module === 'object' && module.exports) {
    module.exports = factory();
  } else {
    root.CafePosCore = factory();
  }
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  const VAT_RATE = 0.07;

  const MENU_ITEMS = [
    { id: 'matcha-latte', name: 'Iced Matcha Latte', category: 'Coffee & Tea', price: 85, icon: 'cup-soda' },
    { id: 'dirty-coffee', name: 'Signature Dirty Coffee', category: 'Coffee & Tea', price: 95, icon: 'coffee' },
    { id: 'americano', name: 'Iced Yuzu Americano', category: 'Coffee & Tea', price: 80, icon: 'sparkles' },
    { id: 'croissant', name: 'Butter Croissant', category: 'Bakery', price: 65, icon: 'croissant' },
    { id: 'basque-cake', name: 'Burnt Basque Cheesecake', category: 'Bakery', price: 120, icon: 'cake-slice' },
    { id: 'espresso-shot', name: 'Hot Double Espresso', category: 'Coffee & Tea', price: 60, icon: 'flame' }
  ];

  function roundCurrency(value) {
    return Math.round((Number(value) + Number.EPSILON) * 100) / 100;
  }

  /**
   * Calculates Subtotal, VAT 7%, and Net Total from cart items.
   * @param {Array<{id: string, name: string, price: number, qty: number}>} cartItems
   */
  function calculateOrderSummary(cartItems) {
    if (!Array.isArray(cartItems) || cartItems.length === 0) {
      return {
        totalItems: 0,
        subtotal: 0,
        vatRate: VAT_RATE,
        vatAmount: 0,
        netTotal: 0
      };
    }

    let totalItems = 0;
    let rawSubtotal = 0;

    for (const item of cartItems) {
      const price = Math.max(0, Number(item.price) || 0);
      const qty = Math.max(0, Math.floor(Number(item.qty) || 0));
      totalItems += qty;
      rawSubtotal += price * qty;
    }

    const subtotal = roundCurrency(rawSubtotal);
    const vatAmount = roundCurrency(subtotal * VAT_RATE);
    const netTotal = roundCurrency(subtotal + vatAmount);

    return {
      totalItems,
      subtotal,
      vatRate: VAT_RATE,
      vatAmount,
      netTotal
    };
  }

  /**
   * Builds a deterministic PromptPay QR payload string with locked amount.
   * @param {string} promptPayId - Merchant PromptPay ID (e.g. '081-234-5678')
   * @param {number} netTotal - Locked net amount including 7% VAT
   */
  function buildPromptPayPayload(promptPayId, netTotal) {
    const cleanId = String(promptPayId || '0899998888').replace(/[^0-9]/g, '');
    const formattedAmount = roundCurrency(Math.max(0, Number(netTotal) || 0)).toFixed(2);
    return `00020101021229370016A00000067701011101130066${cleanId.slice(-9)}5303764540${formattedAmount.length}${formattedAmount}5802TH6304CAFE`;
  }

  return {
    VAT_RATE,
    MENU_ITEMS,
    roundCurrency,
    calculateOrderSummary,
    buildPromptPayPayload
  };
});

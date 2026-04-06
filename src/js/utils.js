export function escapeHtml(unsafe) {
    if (unsafe == null) return '';
    return String(unsafe)
         .replace(/&/g, "&amp;")
         .replace(/</g, "&lt;")
         .replace(/>/g, "&gt;")
         .replace(/"/g, "&quot;")
         .replace(/'/g, "&#039;");
}

export function formatNumber(num, decimals = 2) {
    if (num == null) return '--';
    const parsed = Number(num);
    if (isNaN(parsed)) return '--';
    return parsed.toLocaleString('pt-BR', { minimumFractionDigits: decimals, maximumFractionDigits: decimals });
}

/**
 * Formats a value as BRL Currency.
 * Improves readability by encapsulating the lengthy toLocaleString call.
 */
export function formatCurrency(value) {
    if (value == null || isNaN(Number(value))) return 'R$ 0,00';
    return Number(value).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
}

/**
 * Formats a weight value (in kg) to Tons (divided by 1000).
 * Improves readability by encapsulating the division and toLocaleString call.
 */
export function formatTons(weightInKg, decimals = 1) {
    if (weightInKg == null || isNaN(Number(weightInKg))) return '0,0 Ton';
    return (Number(weightInKg) / 1000).toLocaleString('pt-BR', { minimumFractionDigits: decimals, maximumFractionDigits: decimals }) + ' Ton';
}

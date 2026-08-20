// 货币格式化：按用户 currency 使用 Intl.NumberFormat，替代模板中硬编码的 $ 前缀。
// 与移动端行为对齐：统一保留 2 位小数（JPY 等无小数货币也显示 .00，保持报表一致）。
// currency 由后端校验为 3 位大写 ISO 4217（如 USD/EUR/GBP），非法值回退 USD。
export function money(value, currency = 'USD') {
  const n = Number(value) || 0
  try {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency,
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    }).format(n)
  } catch (_) {
    return `$${n.toFixed(2)}`
  }
}

export function fmtHours(h) {
  return `${(Number(h) || 0).toFixed(1)}h`
}

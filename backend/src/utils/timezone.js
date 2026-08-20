const { DateTime } = require('luxon');

// 默认时区：美东（Freelance Hub 主目标用户群集中在美东/美西，存盘一律 UTC 毫秒，展示与归档按用户时区）
const DEFAULT_TIMEZONE = 'America/New_York';

/**
 * 规范化时区标识：无效/缺失时回退到默认时区，防止 luxon 抛错导致报表生成失败。
 * 接受 IANA 时区标识（如 'America/New_York'、'Europe/London'、'Asia/Shanghai'）。
 */
function normalizeTimezone(tz) {
  if (!tz || typeof tz !== 'string') return DEFAULT_TIMEZONE;
  const dt = DateTime.now().setZone(tz);
  if (!dt || !dt.isValid) {
    return DEFAULT_TIMEZONE;
  }
  return tz;
}

/**
 * 返回某月在该时区下的 UTC 毫秒边界 [start, end)。
 * 例：getMonthBounds(2026, 1, 'America/New_York')
 *   → start = 2026-01-01 00:00 EST = 2026-01-01 05:00 UTC = 1735707600000
 *   → end   = 2026-02-01 00:00 EST = 2026-02-01 05:00 UTC = 1738386000000
 *
 * DST 自动处理：luxon 内置 IANA 时区规则，会自动应用当月正确的偏移。
 */
function getMonthBounds(year, month, timezone) {
  const tz = normalizeTimezone(timezone);
  const start = DateTime.fromObject(
    { year, month, day: 1, hour: 0, minute: 0, second: 0, millisecond: 0 },
    { zone: tz }
  ).toMillis();

  const endYear = month === 12 ? year + 1 : year;
  const endMonth = month === 12 ? 1 : month + 1;
  const end = DateTime.fromObject(
    { year: endYear, month: endMonth, day: 1, hour: 0, minute: 0, second: 0, millisecond: 0 },
    { zone: tz }
  ).toMillis();

  return { start, end };
}

/**
 * 返回某年在该时区下的 UTC 毫秒边界 [start, end)。
 */
function getYearBounds(year, timezone) {
  const tz = normalizeTimezone(timezone);
  const start = DateTime.fromObject(
    { year, month: 1, day: 1, hour: 0, minute: 0, second: 0, millisecond: 0 },
    { zone: tz }
  ).toMillis();
  const end = DateTime.fromObject(
    { year: year + 1, month: 1, day: 1, hour: 0, minute: 0, second: 0, millisecond: 0 },
    { zone: tz }
  ).toMillis();
  return { start, end };
}

/**
 * 将 UTC 毫秒时间戳按用户时区格式化为 'YYYY-MM-DD' 字符串。
 * 用于 dailyHoursTrend 等按日分组的报表。
 */
function formatDateKey(timestamp, timezone) {
  const tz = normalizeTimezone(timezone);
  return DateTime.fromMillis(timestamp, { zone: tz }).toFormat('yyyy-MM-dd');
}

/**
 * 返回时间戳在该时区下的月份索引（0-11）。
 * 用于月度趋势/季度归类。
 */
function getMonthIndex(timestamp, timezone) {
  const tz = normalizeTimezone(timezone);
  return DateTime.fromMillis(timestamp, { zone: tz }).month - 1;
}

/**
 * 返回时间戳在该时区下的季度索引（0-3，对应 Q1-Q4）。
 * Q1 = 1-3月, Q2 = 4-6月, Q3 = 7-9月, Q4 = 10-12月
 */
function getQuarterIndex(timestamp, timezone) {
  const tz = normalizeTimezone(timezone);
  const month = DateTime.fromMillis(timestamp, { zone: tz }).month;
  return Math.floor((month - 1) / 3);
}

module.exports = {
  DEFAULT_TIMEZONE,
  normalizeTimezone,
  getMonthBounds,
  getYearBounds,
  formatDateKey,
  getMonthIndex,
  getQuarterIndex,
};

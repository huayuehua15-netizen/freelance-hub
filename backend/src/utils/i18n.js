/**
 * 后端简易 i18n：基于 JSON 字典的 t(key, lang, params) 查找。
 *
 * 设计取舍：
 * - 不引入 i18next：后端错误消息量小（~30 条）且无复数/性别需求，自研够用。
 * - 占位符语法统一为 {name}，与 mobile/web 一致，便于跨端对照。
 * - 缺失翻译时回退到英文，再回退到 key 本身，避免前端显示 key。
 */
const en = require('../locales/en.json');
const zh = require('../locales/zh.json');

const messages = { en, zh };

/**
 * 按点分路径取嵌套值。例如 getNested({a:{b:1}}, ['a','b']) => 1。
 */
function getNested(obj, path) {
  let cur = obj;
  for (const seg of path) {
    if (cur == null || typeof cur !== 'object') return undefined;
    cur = cur[seg];
  }
  return cur;
}

/**
 * 翻译键。
 * @param {string} key   点分键名，例如 'errors.auth.invalidCredentials'
 * @param {string} lang  'en' | 'zh'，缺省 'en'
 * @param {object} params  占位符替换，例如 {name: 'Tom'} => "Hello, {name}" -> "Hello, Tom"
 * @returns {string}  翻译文本；缺失时回退到英文，再回退到 key 本身
 */
function t(key, lang = 'en', params = {}) {
  const segs = String(key).split('.');
  let s =
    getNested(messages[lang], segs) ??
    getNested(messages.en, segs) ??
    key;
  if (typeof s !== 'string') return key;
  if (params) {
    for (const [k, v] of Object.entries(params)) {
      s = s.replaceAll(`{${k}}`, String(v));
    }
  }
  return s;
}

module.exports = { t };

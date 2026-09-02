import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

/// PDF 中文字体加载（B4 修复）。
///
/// Flutter `pdf` 包默认只内嵌 Latin 字体，中文用户的备注/tag/商户名在
/// PDF 中会渲染为空白/豆腐块。这里加载 Noto Sans SC 子集字体
/// （GB2312 全量汉字 + ASCII，约 3.3MB，OFL 开源许可，可商用），
/// 通过 `pw.ThemeData.withFont` 注入两个报表的 Document。
///
/// 命名采用 `CjkFont` 而非 `PdfFont`：与 `pdf` 包内置 `PdfFont` 类避免冲突。
class CjkFont {
  static pw.Font? _cjkFont;

  static Future<pw.Font> getCjkFont() async {
    _cjkFont ??= pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansSC-Subset.otf'),
    );
    return _cjkFont!;
  }
}

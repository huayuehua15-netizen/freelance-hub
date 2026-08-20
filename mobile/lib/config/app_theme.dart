import 'package:flutter/material.dart';

/// 应用主题配置。
///
/// 设计原则：
/// - **向后兼容**：所有 static const Color 保持不变，123 处引用不受影响。
/// - **M3 完整 ColorScheme**：补全 onPrimary/onSecondary/onSurface/surfaceVariant
///   等字段，让 Material 3 组件（Card/Dialog/SnackBar/Chip）在亮/暗模式下都有
///   正确的前景/背景对比度。
/// - **深色模式色彩提亮**：primary 在深色模式下用 0xFF60A5FA（蓝-400）而非
///   0xFF2563EB（蓝-600），确保在 0xFF0F172A 深色背景上对比度 ≥ 4.5:1（WCAG AA）。
/// - **统一 textTheme**：M3 标准字号 + 字重层级，颜色跟随 onSurface/onSurfaceVariant。
///   页面可用 `Theme.of(context).textTheme.titleMedium` 替代硬编码 TextStyle。
class AppTheme {
  // ===== 品牌色（亮/暗通用，向后兼容） =====
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryLight = Color(0xFFDBEAFE);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  // ===== 亮色模式语义色（向后兼容） =====
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textDisabled = Color(0xFF94A3B8);
  static const Color border = Color(0xFFE2E8F0);

  // ===== 深色模式语义色（新增，用于 darkTheme 内部） =====
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkSurfaceVariant = Color(0xFF334155);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkBorder = Color(0xFF334155);
  /// 深色模式主色提亮：蓝-400，在深色背景上对比度更好。
  static const Color primaryDark = Color(0xFF60A5FA);

  // ===== M3 TextTheme =====
  // 统一字体层级，页面应优先使用 textTheme 而非硬编码 TextStyle。
  // 字号遵循 M3 type scale，字重用 w500/w600 体现层级。
  static const TextTheme _baseTextTheme = TextTheme(
    // Display：大标题（ rarely used， splash 页 / onboarding）
    displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, height: 1.25),
    displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.29),
    displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.33),
    // Headline：页面主标题（ AppBar title 用 titleLarge 而非 headline）
    headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.27),
    headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.30),
    headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.33),
    // Title：卡片标题、Section 标题
    titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.33),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.38),
    titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.43),
    // Body：正文、列表项
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.50),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.43),
    bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.33),
    // Label：按钮、Chip、Tab、Caption
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.43),
    labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.33),
    labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, height: 1.27),
  );

  static ThemeData get lightTheme {
    const colorScheme = ColorScheme.light(
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: primaryLight,
      onPrimaryContainer: Color(0xFF1E3A8A),
      secondary: success,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFD1FAE5),
      onSecondaryContainer: Color(0xFF064E3B),
      tertiary: warning,
      onTertiary: Colors.white,
      error: danger,
      onError: Colors.white,
      errorContainer: Color(0xFFFEE2E2),
      onErrorContainer: Color(0xFF7F1D1D),
      surface: surface,
      onSurface: textPrimary,
      surfaceContainerHighest: Color(0xFFF1F5F9),
      onSurfaceVariant: textSecondary,
      outline: border,
      outlineVariant: Color(0xFFF1F5F9),
      shadow: Color(0xFF000000),
    );
    return ThemeData(
      useMaterial3: true,
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      colorScheme: colorScheme,
      canvasColor: surface,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0.5,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: danger, width: 2),
        ),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
        hintStyle: const TextStyle(color: textDisabled, fontSize: 14),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 14,
          color: textSecondary,
          height: 1.50,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        actionTextColor: primaryLight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF1F5F9),
        selectedColor: primaryLight,
        labelStyle: const TextStyle(fontSize: 12, color: textPrimary),
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      bottomAppBarTheme: const BottomAppBarThemeData(
        color: surface,
        elevation: 8,
        height: 64,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: Color(0xFFE2E8F0),
      ),
      textTheme: _baseTextTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
        decorationColor: textPrimary,
      ),
      primaryTextTheme: _baseTextTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
        decorationColor: Colors.white,
      ),
    );
  }

  static ThemeData get darkTheme {
    const colorScheme = ColorScheme.dark(
      // 深色模式主色提亮：蓝-400 在 0xFF0F172A 上对比度 4.6:1（WCAG AA 通过）
      primary: primaryDark,
      onPrimary: Color(0xFF002855),
      primaryContainer: Color(0xFF1E3A8A),
      onPrimaryContainer: Color(0xFFDBEAFE),
      secondary: Color(0xFF34D399),
      onSecondary: Color(0xFF003825),
      secondaryContainer: Color(0xFF064E3B),
      onSecondaryContainer: Color(0xFFD1FAE5),
      tertiary: Color(0xFFFBBF24),
      onTertiary: Color(0xFF422006),
      error: Color(0xFFF87171),
      onError: Color(0xFF601010),
      errorContainer: Color(0xFF7F1D1D),
      onErrorContainer: Color(0xFFFEE2E2),
      surface: darkSurface,
      onSurface: darkTextPrimary,
      surfaceContainerHighest: darkSurfaceVariant,
      onSurfaceVariant: darkTextSecondary,
      outline: darkBorder,
      outlineVariant: darkSurface,
      shadow: Color(0xFF000000),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: colorScheme,
      canvasColor: darkSurface,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0.5,
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: darkBorder),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          // 深色模式按钮用提亮主色，确保在深色背景上可见
          backgroundColor: primaryDark,
          foregroundColor: const Color(0xFF002855),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryDark,
          foregroundColor: const Color(0xFF002855),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryDark, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFF87171)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFF87171), width: 2),
        ),
        labelStyle: const TextStyle(color: darkTextSecondary, fontSize: 14),
        hintStyle: const TextStyle(color: darkTextSecondary, fontSize: 14),
      ),
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkBorder),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: darkTextPrimary,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 14,
          color: darkTextSecondary,
          height: 1.50,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkSurfaceVariant,
        contentTextStyle: const TextStyle(color: darkTextPrimary, fontSize: 14),
        actionTextColor: primaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkSurfaceVariant,
        selectedColor: const Color(0xFF1E3A8A),
        labelStyle: const TextStyle(fontSize: 12, color: darkTextPrimary),
        side: const BorderSide(color: darkBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: primaryDark,
        unselectedItemColor: darkTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      bottomAppBarTheme: const BottomAppBarThemeData(
        color: darkSurface,
        elevation: 8,
        height: 64,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryDark,
        foregroundColor: Color(0xFF002855),
        elevation: 2,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryDark,
        linearTrackColor: darkSurfaceVariant,
      ),
      textTheme: _baseTextTheme.apply(
        bodyColor: darkTextPrimary,
        displayColor: darkTextPrimary,
        decorationColor: darkTextPrimary,
      ),
      primaryTextTheme: _baseTextTheme.apply(
        bodyColor: const Color(0xFF002855),
        displayColor: const Color(0xFF002855),
        decorationColor: const Color(0xFF002855),
      ),
    );
  }
}

# ===========================================================================
# Freelance Hub ProGuard / R8 规则
# ===========================================================================
# 目的：在 release 构建启用 R8 代码压缩时，保留 Flutter 插件运行所必需的
# 反射入口、JNI 入口、序列化类，避免运行时 NoSuchMethodError / ClassNotFoundException。
#
# Flutter 默认已经为 Flutter 引擎本身（io.flutter.*）做了保留，这里只补充
# 第三方插件与项目自身的特殊规则。
# ===========================================================================

# ---------------------------------------------------------------------------
# Flutter 引擎与 Dart Native Entry（保险起见显式保留）
# Flutter 框架已内置 consumer rules，但显式声明可避免插件版本差异导致漏配。
# ---------------------------------------------------------------------------
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

# ---------------------------------------------------------------------------
# RevenueCat (purchases_flutter)
# 订阅校验核心：RC SDK 大量用反射读写 Entitlement/Subscriber 模型，混淆会破坏
# JSON 序列化导致订阅状态读取失败（这是付费功能，绝对不能挂）。
# ---------------------------------------------------------------------------
-keep class com.revenuecat.purchases.** { *; }
-keep class com.revenuecat.purchases_flutter.** { *; }
-keep class com.revenuecat.common.** { *; }
-keep class com.revenuecat.models.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes RuntimeVisibleAnnotations
-keepattributes RuntimeInvisibleAnnotations

# ---------------------------------------------------------------------------
# flutter_local_notifications
# 通过反射注册 BroadcastReceiver，混淆会破坏定时通知调度。
# ---------------------------------------------------------------------------
-keep class com.dexterous.** { *; }
-dontwarn com.dexterous.**

# ---------------------------------------------------------------------------
# Hive (本地数据库，反射生成 TypeAdapter)
# Hive 在 release 模式下若没生成 .g.dart adapter，会回退到反射读写字段，
# 混淆会导致模型字段读写失败，进而引发本地数据丢失。
# ---------------------------------------------------------------------------
-keep class com.hivedb.** { *; }
-keep class **._hive_** { *; }
-keep class **.hive_reader** { *; }
-keep class **.hive_writer** { *; }
-keep class **.HiveTypeAdapter { *; }
-dontwarn org.bouncycastle.**
-dontwarn org.bouncycastle.util.**

# ---------------------------------------------------------------------------
# image_picker / share_plus / path_provider / pdf / printing
# 这些是 Flutter 第一方/社区维护插件，依赖平台通道反射调用。
# ---------------------------------------------------------------------------
-keep class io.flutter.plugins.imagepicker.** { *; }
-keep class io.flutter.plugins.share.** { *; }
-keep class io.flutter.plugins.pathprovider.** { *; }
-keep class io.flutter.plugins.urllauncher.** { *; }
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class com.davemorrissey.labs.subscaleview.** { *; }
-keep class io.flutter.plugins.pdf.** { *; }
-dontwarn io.flutter.plugins.**

# ---------------------------------------------------------------------------
# workmanager (待 m5 任务启用，保留规则避免后续构建失败)
# ---------------------------------------------------------------------------
-keep class dev.fluttercommunity.plus.** { *; }
-keep class androidx.work.** { *; }
-dontwarn androidx.work.**

# ---------------------------------------------------------------------------
# 通用 Kotlin 元数据保留（Kotlin 反射）
# ---------------------------------------------------------------------------
-keep class kotlin.Metadata { *; }
-keepattributes KotlinMetadata

# ---------------------------------------------------------------------------
# 项目自身的 Native Channel Plugin（MainActivity 注册的插件入口）
# 即使 MainActivity 命名空间稳定，也保险起见保留 GeneratedPluginRegistrant。
# ---------------------------------------------------------------------------
-keep class com.freelancehub.freelance_hub.** { *; }
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

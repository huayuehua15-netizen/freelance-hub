import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_info.dart';
import '../models/client_project.dart';
import '../models/time_log.dart';
import '../models/expense_log.dart';
import '../models/tax_category.dart';

class HiveService {
  static const String userBox = 'user_info';
  static const String projectBox = 'client_project';
  static const String timeLogBox = 'time_log';
  static const String expenseBox = 'expense_log';
  static const String taxCategoryBox = 'tax_category';
  static const String configBox = 'app_config';

  // Hive 加密密钥在 flutter_secure_storage 中的存储键。
  // 该密钥首次启动生成一次，之后复用；明文落盘的财务数据用此密钥加密，
  // 防止 root 设备或 adb backup 提取完整客户账本。
  static const String _hiveCipherKeyStorageKey = 'hive_cipher_key_v1';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  /// 从安全存储读取或生成 32 字节 AES 密钥。
  /// 密钥只生成一次并持久化，保证 App 升级后仍能解密旧数据。
  static Future<Uint8List> _loadOrCreateCipherKey() async {
    final stored = await _secureStorage.read(key: _hiveCipherKeyStorageKey);
    if (stored != null && stored.isNotEmpty) {
      // 存储格式：逗号分隔的字节值，还原成 Uint8List
      final parts = stored.split(',').map((s) => int.parse(s)).toList();
      return Uint8List.fromList(parts);
    }
    // 密码学安全随机源：Random.secure() 由操作系统提供熵（Android Keystore/Linux /dev/urandom），
    // 不可预测，杜绝攻击者通过安装时间暴力推算密钥。
    final key = _generateSecureKey();
    await _secureStorage.write(
      key: _hiveCipherKeyStorageKey,
      value: key.join(','),
    );
    return key;
  }

  /// 用 Random.secure() 生成 32 字节 AES 密钥（HiveAesCipher 要求 16/24/32 字节）。
  static Uint8List _generateSecureKey() {
    final random = Random.secure();
    return Uint8List.fromList(List<int>.generate(32, (_) => random.nextInt(256)));
  }

  static Future<void> init() async {
    await Hive.initFlutter();

    // 注册Adapter
    Hive.registerAdapter(UserInfoAdapter());
    Hive.registerAdapter(ClientProjectAdapter());
    Hive.registerAdapter(TimeLogAdapter());
    Hive.registerAdapter(ExpenseLogAdapter());
    Hive.registerAdapter(TaxCategoryAdapter());

    // 加载加密密钥：敏感业务 Box 全部用 AES 加密，
    // 防止明文落盘的工时/金额/客户信息被 adb backup 或 root 设备提取。
    Uint8List cipherKey;
    try {
      cipherKey = await _loadOrCreateCipherKey();
    } catch (e) {
      // 安全存储读取失败的兜底：用一次性密码学安全随机密钥加密（数据在本会话仍可用，
      // 但重启后旧密钥无法恢复会丢失——优于明文裸奔）。
      debugPrint('Failed to load Hive cipher key, generating ephemeral: $e');
      cipherKey = _generateSecureKey();
    }
    final cipher = HiveAesCipher(cipherKey);

    // 打开Box：业务数据 Box 加密；configBox 仅存非敏感的计时器状态/同步游标，无需加密
    await Future.wait([
      Hive.openBox<UserInfo>(userBox, encryptionCipher: cipher),
      Hive.openBox<ClientProject>(projectBox, encryptionCipher: cipher),
      Hive.openBox<TimeLog>(timeLogBox, encryptionCipher: cipher),
      Hive.openBox<ExpenseLog>(expenseBox, encryptionCipher: cipher),
      Hive.openBox<TaxCategory>(taxCategoryBox, encryptionCipher: cipher),
      Hive.openBox(configBox),
    ]);

    await _initDefaultTaxCategories();
  }

  static Future<void> _initDefaultTaxCategories() async {
    final box = Hive.box<TaxCategory>(taxCategoryBox);
    if (box.isEmpty) {
      final defaults = TaxCategory.getDefaultCategories();
      for (final cat in defaults) {
        await box.put(cat.categoryId, cat);
      }
    }
  }

  // 便捷获取Box
  static Box<UserInfo> get userBoxInstance => Hive.box<UserInfo>(userBox);
  static Box<ClientProject> get projectBoxInstance => Hive.box<ClientProject>(projectBox);
  static Box<TimeLog> get timeLogBoxInstance => Hive.box<TimeLog>(timeLogBox);
  static Box<ExpenseLog> get expenseBoxInstance => Hive.box<ExpenseLog>(expenseBox);
  static Box<TaxCategory> get taxCategoryBoxInstance => Hive.box<TaxCategory>(taxCategoryBox);
  static Box get configBoxInstance => Hive.box(configBox);
}

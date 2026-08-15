import 'package:hive/hive.dart';

part 'user_info.g.dart';

@HiveType(typeId: 0)
class UserInfo extends HiveObject {
  @HiveField(0)
  String userId;

  @HiveField(1)
  String userName;

  @HiveField(2)
  String userEmail;

  @HiveField(3)
  String currency;

  @HiveField(4)
  String timezone;

  @HiveField(5)
  bool isPremium;

  @HiveField(6)
  String premiumType; // free / monthly / annual

  @HiveField(7)
  int? expireTime;

  @HiveField(8)
  int? trialEndTime;

  @HiveField(9)
  int lastSyncTime;

  @HiveField(10)
  int createdAt;

  @HiveField(11)
  int updatedAt;

  UserInfo({
    required this.userId,
    this.userName = '',
    this.userEmail = '',
    this.currency = 'USD',
    this.timezone = 'America/New_York',
    this.isPremium = false,
    this.premiumType = 'free',
    this.expireTime,
    this.trialEndTime,
    this.lastSyncTime = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 序列化为 JSON（会话持久化到 shared_preferences 用）
  Map<String, dynamic> toJson() => {
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
        'currency': currency,
        'timezone': timezone,
        'isPremium': isPremium,
        'premiumType': premiumType,
        'expireTime': expireTime,
        'trialEndTime': trialEndTime,
        'lastSyncTime': lastSyncTime,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory UserInfo.fromJson(Map<String, dynamic> json) => UserInfo(
        userId: json['userId'] as String,
        userName: (json['userName'] as String?) ?? '',
        userEmail: (json['userEmail'] as String?) ?? '',
        currency: (json['currency'] as String?) ?? 'USD',
        timezone: (json['timezone'] as String?) ?? 'America/New_York',
        isPremium: (json['isPremium'] as bool?) ?? false,
        premiumType: (json['premiumType'] as String?) ?? 'free',
        expireTime: (json['expireTime'] as num?)?.toInt(),
        trialEndTime: (json['trialEndTime'] as num?)?.toInt(),
        lastSyncTime: (json['lastSyncTime'] as num?)?.toInt() ?? 0,
        createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
        updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
      );
}

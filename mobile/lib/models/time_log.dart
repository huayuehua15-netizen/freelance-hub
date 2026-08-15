import 'package:hive/hive.dart';

part 'time_log.g.dart';

@HiveType(typeId: 2)
class TimeLog extends HiveObject {
  @HiveField(0)
  String timeLogId;

  @HiveField(1)
  String projectId;

  @HiveField(2)
  int startTime; // 毫秒时间戳 UTC

  @HiveField(3)
  int? endTime;

  @HiveField(4)
  double duration; // 小时

  @HiveField(5)
  bool isBillable;

  @HiveField(6)
  double billableAmount;

  @HiveField(7)
  String tag;

  @HiveField(8)
  String note;

  @HiveField(9)
  bool isDeleted;

  @HiveField(10)
  int syncStatus;

  @HiveField(11)
  int? serverUpdateTime;

  @HiveField(12)
  int createdAt;

  @HiveField(13)
  int updatedAt;

  TimeLog({
    required this.timeLogId,
    required this.projectId,
    required this.startTime,
    this.endTime,
    this.duration = 0,
    this.isBillable = true,
    this.billableAmount = 0,
    this.tag = '',
    this.note = '',
    this.isDeleted = false,
    this.syncStatus = 0,
    this.serverUpdateTime,
    required this.createdAt,
    required this.updatedAt,
  });
}

import 'package:hive/hive.dart';

part 'client_project.g.dart';

@HiveType(typeId: 1)
class ClientProject extends HiveObject {
  @HiveField(0)
  String projectId;

  @HiveField(1)
  String clientName;

  @HiveField(2)
  String clientEmail;

  @HiveField(3)
  String projectName;

  @HiveField(4)
  double hourlyRate;

  @HiveField(5)
  String currency;

  @HiveField(6)
  String status; // active / archived / completed

  @HiveField(7)
  bool isDeleted;

  @HiveField(8)
  int syncStatus; // 0=待同步 1=已同步 2=冲突

  @HiveField(9)
  int? serverUpdateTime;

  @HiveField(10)
  int createdAt;

  @HiveField(11)
  int updatedAt;

  ClientProject({
    required this.projectId,
    required this.clientName,
    this.clientEmail = '',
    required this.projectName,
    required this.hourlyRate,
    this.currency = 'USD',
    this.status = 'active',
    this.isDeleted = false,
    this.syncStatus = 0,
    this.serverUpdateTime,
    required this.createdAt,
    required this.updatedAt,
  });
}

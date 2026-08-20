/// Free 版数据可见范围门禁。
///
/// 付费墙承诺「Free 仅当月数据」——此前仅在文案层面承诺，列表/详情/导出
/// 全部放行历史数据（免费版反而拿到比 Monthly 更大的数据出口）。
/// 本工具集中实现该限制：所有免费用户可见的工时/开支列表与导出一律
/// 经过此过滤；报表/同步/Web 已有各自的权限拦截，不经此处。
class FreeTierGate {
  /// 时间戳是否落在当前自然月（按设备本地时区，与仪表盘口径一致）。
  static bool isCurrentMonth(int timestampMs) {
    final d = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month;
  }

  /// 免费版过滤后的可见记录集合。isFree 为 false 时原样返回（付费用户）。
  static List<T> visible<T>(List<T> records, bool isFree, int Function(T) timestampOf) {
    if (!isFree) return records;
    return records.where((r) => isCurrentMonth(timestampOf(r))).toList();
  }
}

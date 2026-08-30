/// إحصائيات لوحة تحكم المدير، قادمة من نقطة نهاية تجميعية في الـ API
/// (مثلاً: GET /api/dashboard/stats)
class DashboardStats {
  final int doctorsCount;
  final int nursesCount;
  final int presentCount;
  final int absentCount;

  DashboardStats({
    required this.doctorsCount,
    required this.nursesCount,
    required this.presentCount,
    required this.absentCount,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    int count(String key) => (json[key] as num?)?.toInt() ?? 0;

    return DashboardStats(
      doctorsCount: count('doctors_count'),
      nursesCount: count('nurses_count'),
      presentCount: count('present_count'),
      absentCount: count('absent_count'),
    );
  }

  factory DashboardStats.empty() => DashboardStats(
        doctorsCount: 0,
        nursesCount: 0,
        presentCount: 0,
        absentCount: 0,
      );
}

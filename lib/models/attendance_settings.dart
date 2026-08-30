class AttendanceSettings {
  final String centerName;
  final double centerLatitude;
  final double centerLongitude;
  final double allowedRadiusMeters;
  final String qrCode;

  const AttendanceSettings({
    required this.centerName,
    required this.centerLatitude,
    required this.centerLongitude,
    required this.allowedRadiusMeters,
    required this.qrCode,
  });

  factory AttendanceSettings.fromMap(Map<String, dynamic> map) {
    final latitude = (map['center_lat'] as num?)?.toDouble();
    final longitude = (map['center_lng'] as num?)?.toDouble();
    if (latitude == null || longitude == null) {
      throw const FormatException('موقع المركز غير مضبوط في Supabase');
    }

    return AttendanceSettings(
      centerName: map['center_name']?.toString() ?? 'الإسعاف المركزي',
      centerLatitude: latitude,
      centerLongitude: longitude,
      allowedRadiusMeters:
          (map['allowed_radius_meters'] as num?)?.toDouble() ?? 200,
      qrCode: map['qr_code']?.toString() ?? '',
    );
  }
}
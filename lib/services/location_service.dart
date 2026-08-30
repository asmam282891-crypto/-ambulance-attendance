import 'dart:math';
import 'package:geolocator/geolocator.dart';
import '../models/attendance_settings.dart';

/// يتحقق من موقع الموظف مقابل إحداثيات مركز الإسعاف،
/// ويحدد ما إذا كان داخل النطاق المسموح به لتسجيل الحضور.
class LocationService {
  LocationService._();

  static Future<Position> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('يرجى تفعيل خدمة الموقع لإتمام تسجيل الحضور');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('تم رفض إذن الوصول للموقع');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('إذن الموقع مرفوض بشكل دائم، فعّله من الإعدادات');
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  static double distanceFromCenterMeters(
    Position position,
    AttendanceSettings settings,
  ) {
    return Geolocator.distanceBetween(
      settings.centerLatitude,
      settings.centerLongitude,
      position.latitude,
      position.longitude,
    );
  }

  static bool isWithinRange(
    Position position,
    AttendanceSettings settings,
  ) {
    return distanceFromCenterMeters(position, settings) <=
        settings.allowedRadiusMeters;
  }
}

/// دالة مساعدة بسيطة في حال احتجت حساب المسافة دون مكتبة خارجية.
double haversineMeters(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const earthRadius = 6371000.0;
  final dLat = _deg2rad(lat2 - lat1);
  final dLon = _deg2rad(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_deg2rad(lat1)) *
          cos(_deg2rad(lat2)) *
          sin(dLon / 2) *
          sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadius * c;
}

double _deg2rad(double deg) => deg * (pi / 180);

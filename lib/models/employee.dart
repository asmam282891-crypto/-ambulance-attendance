/// يمثل هذا النموذج صف الموظف من جدول public.employees في Supabase.
/// id هنا هو نفسه uuid مستخدم المصادقة (auth.users.id).
class Employee {
  final String id;
  final String fullName;
  final String role; // 'doctor' | 'nurse' | 'admin' | 'paramedic' | 'secretary' | 'driver' | 'pharmacist'
  final String? jobTitle;
  final String? avatarUrl;
  final bool isCheckedIn;
  final String? checkInTime; // زمن الحضور

  Employee({
    required this.id,
    required this.fullName,
    required this.role,
    this.avatarUrl,
    this.jobTitle,
    this.isCheckedIn = false,
    this.checkInTime,
  });

  factory Employee.fromMap(
    Map<String, dynamic> map, {
    bool? isCheckedIn,
    String? checkInTime,
  }) {
    // تنسيق وقت الحضور إن وجد في البيانات
    String? formattedTime = checkInTime;
    final rawTime = map['check_in_time'] ?? map['checked_in_at'];
    
    if (formattedTime == null && rawTime != null) {
      final dateTime = DateTime.tryParse(rawTime.toString())?.toLocal();
      if (dateTime != null) {
        final hour = dateTime.hour.toString().padLeft(2, '0');
        final minute = dateTime.minute.toString().padLeft(2, '0');
        formattedTime = '$hour:$minute';
      }
    }

    final bool statusFromMap = map['is_checked_in'] == true || 
                               map['status'] == 'present' || 
                               map['status'] == 'checked_in';

    return Employee(
      id: map['id']?.toString() ?? '',
      fullName: map['full_name'] ?? map['name'] ?? '',
      role: map['role'] ?? 'employee',
      jobTitle: map['job_title']?.toString(),
      avatarUrl: map['avatar_url'],
      isCheckedIn: isCheckedIn ?? statusFromMap,
      checkInTime: formattedTime,
    );
  }

  // دعم للـ fromJson لتطابق الاسم المستخدم في الشاشة
  factory Employee.fromJson(Map<String, dynamic> json) => Employee.fromMap(json);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'role': role,
      'avatar_url': avatarUrl,
      'is_checked_in': isCheckedIn,
      'check_in_time': checkInTime,
    };
  }

  Employee copyWith({
    bool? isCheckedIn,
    String? checkInTime,
  }) {
    return Employee(
      id: id,
      fullName: fullName,
      role: role,
      avatarUrl: avatarUrl,
      jobTitle: jobTitle,
      isCheckedIn: isCheckedIn ?? this.isCheckedIn,
      checkInTime: checkInTime ?? this.checkInTime,
    );
  }

  bool get isAdmin =>
      role.toLowerCase() == 'admin' ||
      jobTitle?.trim() == 'مدير النظام';

  String get roleLabel {
    if (isAdmin) return 'مدير';

    switch (role) {
      case 'doctor':
        return 'طبيب';
      case 'nurse':
        return 'ممرض/ة';
      case 'admin':
        return 'مدير';
      case 'paramedic':
        return 'مسعف';
      case 'secretary':
        return 'سكرتارية';
      case 'driver':
        return 'سائق';
      case 'pharmacist':
        return 'صيدلي';
      default:
        return jobTitle?.trim().isNotEmpty == true ? jobTitle!.trim() : 'موظف';
    }
  }

  String get title {
    if (role == 'doctor') return 'د. $fullName';
    return fullName;
  }
}

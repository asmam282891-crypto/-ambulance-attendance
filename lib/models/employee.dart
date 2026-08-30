/// يمثل هذا النموذج صف الموظف من جدول public.employees في Supabase.
/// id هنا هو نفسه uuid مستخدم المصادقة (auth.users.id).
class Employee {
  final String id;
  final String fullName;
  final String role; // 'doctor' | 'nurse' | 'admin'
  final String? avatarUrl;
  final bool isCheckedIn;

  Employee({
    required this.id,
    required this.fullName,
    required this.role,
    this.avatarUrl,
    this.isCheckedIn = false,
  });

  factory Employee.fromMap(Map<String, dynamic> map, {bool isCheckedIn = false}) {
    return Employee(
      id: map['id'].toString(),
      fullName: map['full_name'] ?? '',
      role: map['role'] ?? 'employee',
      avatarUrl: map['avatar_url'],
      isCheckedIn: isCheckedIn,
    );
  }

  Employee copyWith({bool? isCheckedIn}) {
    return Employee(
      id: id,
      fullName: fullName,
      role: role,
      avatarUrl: avatarUrl,
      isCheckedIn: isCheckedIn ?? this.isCheckedIn,
    );
  }

  String get roleLabel {
    switch (role) {
      case 'doctor':
        return 'طبيب';
      case 'nurse':
        return 'ممرض/ة';
      case 'admin':
        return 'مدير';
      default:
        return 'موظف';
    }
  }

  String get title {
    if (role == 'doctor') return 'د. $fullName';
    return fullName;
  }
}

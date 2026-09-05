import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_text_field.dart';

class AddUserScreen extends StatefulWidget {
  const AddUserScreen({super.key});

  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _employeeNumberController = TextEditingController();
  final _departmentController = TextEditingController();
  final _phoneController = TextEditingController();
  final _customJobTitleController = TextEditingController();

  String _jobTitle = 'مسعف';
  String _role = 'paramedic';
  bool _isCustomJobTitle = false;
  bool _isSubmitting = false;

  static const _jobTitles = <String, String>{
    'طبيب': 'doctor',
    'ممرض': 'nurse',
    'ممرضة': 'nurse',
    'مسعف': 'paramedic',
    'سكرتارية': 'secretary',
    'سائق': 'driver',
    'صيدلي': 'pharmacist',
    'أخرى': 'employee',
    'مدير النظام': 'admin',
  };

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _employeeNumberController.dispose();
    _departmentController.dispose();
    _phoneController.dispose();
    _customJobTitleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final jobTitle = _isCustomJobTitle
          ? _customJobTitleController.text.trim()
          : _jobTitle;
      final role = _isCustomJobTitle ? 'employee' : _role;

      await SupabaseService.instance.createAttendanceUser(
        username: _usernameController.text,
        password: _passwordController.text,
        fullName: _fullNameController.text,
        employeeNumber: _employeeNumberController.text,
        jobTitle: jobTitle,
        role: role,
        department: _departmentController.text,
        phone: _phoneController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إنشاء المستخدم وربطه بنظام الحضور ✅')),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } catch (_) {
      if (!mounted) return;
      _showError('تعذّر إنشاء المستخدم، حاول مجددًا');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.danger,
      ),
    );
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return 'أدخل $label';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('إضافة مستخدم')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'بيانات مستخدم نظام الحضور',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'سيتمكن المستخدم من تسجيل الدخول باسم المستخدم وكلمة المرور.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              AppTextField(
                label: 'الاسم الكامل',
                controller: _fullNameController,
                icon: Icons.badge_outlined,
                validator: (value) => _required(value, 'الاسم الكامل'),
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'اسم المستخدم',
                controller: _usernameController,
                icon: Icons.person_outline,
                validator: (value) => _required(value, 'اسم المستخدم'),
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'كلمة المرور',
                controller: _passwordController,
                obscureText: true,
                icon: Icons.lock_outline,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'أدخل كلمة المرور';
                  }
                  if (value.length < 6) {
                    return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'الرقم الوظيفي',
                controller: _employeeNumberController,
                icon: Icons.numbers,
                validator: (value) => _required(value, 'الرقم الوظيفي'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _jobTitle,
                decoration: const InputDecoration(labelText: 'المسمى الوظيفي'),
                items: _jobTitles.keys
                    .map(
                      (title) => DropdownMenuItem(
                        value: title,
                        child: Text(title),
                      ),
                    )
                    .toList(),
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() {
                          _jobTitle = value;
                          _role = _jobTitles[value]!;
                          _isCustomJobTitle = value == 'أخرى';
                        });
                      },
              ),
              if (_isCustomJobTitle) ...[
                const SizedBox(height: 16),
                AppTextField(
                  label: 'اكتب اسم الوظيفة',
                  controller: _customJobTitleController,
                  icon: Icons.work_outline,
                  validator: (value) {
                    final title = value?.trim() ?? '';
                    if (title.isEmpty) return 'أدخل اسم الوظيفة';
                    if (title.length < 2) return 'اسم الوظيفة قصير جدًا';
                    if (title.length > 100) {
                      return 'اسم الوظيفة يجب ألا يتجاوز 100 حرف';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 16),
              AppTextField(
                label: 'القسم (اختياري)',
                controller: _departmentController,
                icon: Icons.business_outlined,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'رقم الهاتف (اختياري)',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                icon: Icons.phone_outlined,
              ),
              const SizedBox(height: 26),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.4,
                        ),
                      )
                    : const Text('إنشاء المستخدم'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
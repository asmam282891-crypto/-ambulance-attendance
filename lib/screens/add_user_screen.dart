import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_text_field.dart';
import '../l10n/app_localizations.dart';

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

  String _jobTitle = 'paramedic';
  String _role = 'paramedic';
  bool _isCustomJobTitle = false;
  bool _isSubmitting = false;

  static const _jobTitles = <String>[
    'doctor',
    'nurse',
    'paramedic',
    'secretary',
    'driver',
    'pharmacist',
    'employee',
    'admin',
  ];

  String _jobTitleLabel(BuildContext context, String role) {
    switch (role) {
      case 'doctor':
        return context.tr('roleDoctor');
      case 'nurse':
        return context.tr('roleNurse');
      case 'paramedic':
        return context.tr('roleParamedic');
      case 'secretary':
        return context.tr('roleSecretary');
      case 'driver':
        return context.tr('roleDriver');
      case 'pharmacist':
        return context.tr('rolePharmacist');
      case 'admin':
        return context.tr('roleAdmin');
      default:
        return context.tr('roleEmployee');
    }
  }

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
          : _jobTitleLabel(context, _role);
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
        SnackBar(content: Text(context.tr('userCreated'))),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } catch (_) {
      if (!mounted) return;
      _showError(context.tr('createUserFailed'));
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
    if (value == null || value.trim().isEmpty) {
      return context.tr('enterField', {'field': label});
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLocaleController.instance.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('addUserTitle')),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                context.tr('attendanceUserData'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                context.tr('loginInstruction'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              AppTextField(
                label: context.tr('fullName'),
                controller: _fullNameController,
                icon: Icons.badge_outlined,
                validator: (value) => _required(value, context.tr('fullName')),
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: context.tr('username'),
                controller: _usernameController,
                icon: Icons.person_outline,
                validator: (value) => _required(value, context.tr('username')),
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: context.tr('password'),
                controller: _passwordController,
                obscureText: true,
                icon: Icons.lock_outline,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return context.tr('enterField', {'field': context.tr('password')});
                  }
                  if (value.length < 6) {
                    return context.tr('passwordMin');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: context.tr('employeeNumber'),
                controller: _employeeNumberController,
                icon: Icons.numbers,
                validator: (value) =>
                    _required(value, context.tr('employeeNumber')),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _jobTitle,
                decoration: InputDecoration(
                  labelText: context.tr('jobTitleLabel'),
                ),
                items: _jobTitles
                    .map(
                      (role) => DropdownMenuItem(
                        value: role,
                        child: Text(_jobTitleLabel(context, role)),
                      ),
                    )
                    .toList(),
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() {
                          _jobTitle = value;
                          _role = value;
                          _isCustomJobTitle = value == 'employee';
                        });
                      },
              ),
              if (_isCustomJobTitle) ...[
                const SizedBox(height: 16),
                AppTextField(
                  label: context.tr('customJobTitle'),
                  controller: _customJobTitleController,
                  icon: Icons.work_outline,
                  validator: (value) {
                    final title = value?.trim() ?? '';
                    if (title.isEmpty) {
                      return context.tr(
                        'enterField',
                        {'field': context.tr('jobTitle')},
                      );
                    }
                    if (title.length < 2) return context.tr('jobTitleShort');
                    if (title.length > 100) {
                      return context.tr('jobTitleMax');
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 16),
              AppTextField(
                label: context.tr('departmentOptional'),
                controller: _departmentController,
                icon: Icons.business_outlined,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: context.tr('phoneOptional'),
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
                    : Text(context.tr('createUser')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

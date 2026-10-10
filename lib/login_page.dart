import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/firebase_service.dart';
import 'services/app_provider.dart';
import 'admin_page.dart';
import 'tutorial_page.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String _selectedRole = 'employee'; // 'employee' or 'admin'

  Future<void> login() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      _showError("يرجى إدخال البريد الإلكتروني وكلمة المرور");
      return;
    }

    setState(() => _loading = true);
    try {
      final user = await FirebaseService.instance.signIn(
        email.text.trim(),
        password.text,
      );

      if (user == null) {
        _showError('بيانات الدخول غير صحيحة');
      } else {
        final role = user['role'] as String? ?? 'employee';
        final name = user['name'] as String? ?? '';

        if (!mounted) return;

        if (user['isActive'] == false) {
          _showError('هذا الحساب معطل حالياً، يرجى التواصل مع الإدارة');
          setState(() => _loading = false);
          return;
        }

        if (role != _selectedRole) {
          _showError(_selectedRole == 'admin' ? 'هذا الحساب ليس حساب مدير' : 'هذا الحساب ليس حساب موظف');
          setState(() => _loading = false);
          return;
        }

        if (role == 'admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => AdminPage(name: name, role: role),
            ),
          );
        } else {
          // Changed to redirect to TutorialPage instead of HomePage
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => TutorialPage(
                id: user['id'],
                name: name,
                username: user['email'],
                role: role,
                job: user['job'] ?? 'موظف',
                department: user['department'] ?? 'عام',
              ),
            ),
          );
        }
      }
    } catch (e) {
      _showError('حدث خطأ أثناء تسجيل الدخول: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _forgotPassword() {
    final org = Provider.of<AppProvider>(context, listen: false).organization;
    final String phone = org['phone'] ?? '';
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('نسيت كلمة المرور؟'),
        content: Text(
          'يرجى التواصل مع مدير النظام أو قسم الموارد البشرية لإعادة تعيين كلمة المرور الخاصة بك.\n\n'
          '${phone.isNotEmpty ? 'رقم التواصل: $phone' : ''}'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('حسناً'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orgName = Provider.of<AppProvider>(context).organization['name'] ?? 'نظام الحضور';
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.fingerprint, size: 70, color: primaryColor),
                const SizedBox(height: 16),
                Text(
                  orgName,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor),
                  textAlign: TextAlign.center,
                ),
                const Text(
                  "نظام الحضور والانصراف الذكي",
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 30),

                // Role Selector
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    children: [
                      _buildRoleOption('employee', 'موظف', Icons.person),
                      _buildRoleOption('admin', 'مدير', Icons.admin_panel_settings),
                    ],
                  ),
                ),
                const SizedBox(height: 25),

                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: "البريد الإلكتروني",
                    prefixIcon: const Icon(Icons.mail_outline, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: password,
                  obscureText: _obscurePassword,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: "كلمة المرور",
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _forgotPassword,
                    child: const Text("نسيت كلمة المرور؟", style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _loading ? null : login,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _loading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            _selectedRole == 'admin' ? "دخول كمدير" : "دخول كموظف",
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("ليس لديك حساب؟", style: TextStyle(fontSize: 13)),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignUpPage()),
                      ),
                      child: const Text("إنشاء حساب", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                // Tiny Icons for GPS and Biometrics
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text("مدعوم بـ GPS", style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    const SizedBox(width: 16),
                    Icon(Icons.face, size: 16, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text("والمصادقة الحيوية", style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleOption(String role, String label, IconData icon) {
    bool isSelected = _selectedRole == role;
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

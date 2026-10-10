import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home_page.dart';
import 'services/app_provider.dart';

class TutorialPage extends StatelessWidget {
  final String id;
  final String name;
  final String username;
  final String role;
  final String job;
  final String department;

  const TutorialPage({
    super.key,
    required this.id,
    required this.name,
    required this.username,
    required this.role,
    required this.job,
    required this.department,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('تعليمات الحضور'), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'أهلاً بك، $name 👋',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'قبل البدء بتسجيل الحضور، يرجى قراءة التعليمات التالية:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              Expanded(
                child: ListView(
                  children: [
                    _buildInstructionItem(
                      icon: Icons.location_on,
                      color: Colors.blue,
                      title: 'تفعيل الـ GPS',
                      description:
                          'يجب التأكد من تفعيل خدمة تحديد الموقع (GPS) والتواجد داخل النطاق الجغرافي للفرع التابع لك.',
                    ),
                    const SizedBox(height: 20),
                    _buildInstructionItem(
                      icon: Icons.face,
                      color: Colors.purple,
                      title: 'المصادقة الحيوية',
                      description:
                          'سيُطلب منك استخدام بصمة الوجه (Face ID) أو بصمة الإصبع للتحقق من هويتك عند كل عملية حضور أو انصراف.',
                    ),
                    const SizedBox(height: 20),
                    _buildInstructionItem(
                      icon: Icons.warning_amber_rounded,
                      color: Colors.red,
                      title: 'تنبيه هام',
                      description:
                          'مشاركة حسابك مع شخص آخر لتسجيل الحضور نيابة عنك يُعد مخالفة تعرضك للمساءلة الإدارية.',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              SizedBox(
                height: 60,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HomePage(
                          id: id,
                          name: name,
                          username: username,
                          role: role,
                          job: job,
                          department: department,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text(
                    'ابدأ تسجيل الحضور',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionItem({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

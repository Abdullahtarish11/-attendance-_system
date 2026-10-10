import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'services/firebase_service.dart';
import 'login_page.dart';
import 'profile_page.dart';
import 'about_page.dart';

class HomePage extends StatefulWidget {
  final String id;
  final String name;
  final String username;
  final String role;
  final String job;
  final String department;

  const HomePage({
    super.key,
    required this.id,
    required this.name,
    required this.username,
    required this.role,
    required this.job,
    required this.department,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _processing = false;
  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<String?> _authenticate() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
      if (!isAvailable) {
        _showError('الجهاز لا يدعم التحقق الحيوي (البصمة أو الوجه)');
        return null;
      }
      
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      String authType = 'Fingerprint';
      if (availableBiometrics.contains(BiometricType.face)) {
        authType = 'FaceID';
      }

      final authed = await _localAuth.authenticate(
        localizedReason: 'قم بتأكيد هويتك لتسجيل الحضور/الانصراف',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      return authed ? authType : null;
    } catch (e) {
      _showError('خطأ في التحقق: $e');
      return null;
    }
  }

  Future<Position?> _getPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showError('خدمات الموقع معطلة. يرجى تفعيل GPS');
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showError('تم رفض صلاحية الوصول للموقع');
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showError('صلاحيات الموقع مرفوضة دائماً. يرجى تفعيلها من الإعدادات');
      return null;
    }

    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  Future<void> _handleAttendance(String status) async {
    setState(() => _processing = true);

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(status == 'check_in' ? 'تسجيل حضور' : 'تسجيل انصراف', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Text(
            status == 'check_in'
                ? 'هل أنت متأكد من تسجيل الحضور الآن؟'
                : 'هل أنت متأكد من تسجيل الانصراف الآن؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('تأكيد'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        setState(() => _processing = false);
        return;
      }

      // 1. Authenticate Biometrics
      final authType = await _authenticate();
      if (authType == null) {
        setState(() => _processing = false);
        return;
      }

      // 2. Get Location
      final pos = await _getPosition();
      if (pos == null) {
        setState(() => _processing = false);
        return;
      }

      // 3. Check Radius (Check all available branches)
      Map<String, dynamic>? nearestBranch;
      for (var branch in FirebaseService.branches) {
        final bLat = branch['lat'] is num ? (branch['lat'] as num).toDouble() : double.tryParse(branch['lat']?.toString() ?? '') ?? 0.0;
        final bLng = branch['lng'] is num ? (branch['lng'] as num).toDouble() : double.tryParse(branch['lng']?.toString() ?? '') ?? 0.0;
        final bRadius = branch['radius'] is num ? (branch['radius'] as num).toDouble() : double.tryParse(branch['radius']?.toString() ?? '') ?? 200.0;

        final dist = Geolocator.distanceBetween(bLat, bLng, pos.latitude, pos.longitude);
        if (dist <= bRadius) {
          nearestBranch = branch;
          break; // User is inside this branch's range
        }
      }

      if (nearestBranch == null) {
        _showError('أنت خارج نطاق جميع الفروع المعتمدة ❌');
        setState(() => _processing = false);
        return;
      }

      // 4. Check Duplicates
      final already = await FirebaseService.instance.hasAttendanceToday(widget.name, status);
      if (already) {
        _showError(status == 'check_in' ? 'لقد سجلت الحضور مسبقاً اليوم' : 'لقد سجلت الانصراف مسبقاً اليوم');
        setState(() => _processing = false);
        return;
      }

      // 5. Save
      await FirebaseService.instance.saveAttendance(
        name: widget.name,
        status: status,
        lat: pos.latitude,
        lng: pos.longitude,
        branchName: nearestBranch['name'],
        verificationType: authType,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(status == 'check_in' ? 'تم تسجيل الحضور بنجاح' : 'تم تسجيل الانصراف بنجاح'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      _showError('حدث خطأ: $e');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          }
        ),
        title: const Text('لوحة الموظف', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutPage()),
            ),
            icon: const Icon(Icons.info_outline),
            tooltip: 'عن التطبيق',
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(widget.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              accountEmail: Text(widget.job),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 40, color: Colors.blue),
              ),
              decoration: BoxDecoration(color: primaryColor),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('الملف الشخصي'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfilePage(
                      id: widget.id,
                      name: widget.name,
                      username: widget.username,
                      job: widget.job,
                      department: widget.department,
                    ),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
              },
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.transparent,
              child: Icon(Icons.account_circle, size: 100, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Text(widget.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text('${widget.job} - ${widget.department}', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
            const SizedBox(height: 40),
            
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text('إجراءات الدوام', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  _buildActionButton(
                    label: 'تسجيل حضور',
                    icon: Icons.login,
                    color: Colors.green,
                    onPressed: _processing ? null : () => _handleAttendance('check_in'),
                  ),
                  const SizedBox(height: 16),
                  _buildActionButton(
                    label: 'تسجيل انصراف',
                    icon: Icons.logout,
                    color: Colors.orange,
                    onPressed: _processing ? null : () => _handleAttendance('check_out'),
                  ),
                ],
              ),
            ),
            
            if (_processing)
              const Padding(
                padding: EdgeInsets.only(top: 30),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 24),
        label: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          disabledBackgroundColor: color.withOpacity(0.5),
        ),
      ),
    );
  }
}

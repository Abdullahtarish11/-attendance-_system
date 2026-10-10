import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'services/firebase_service.dart';
import 'services/app_provider.dart';

class SettingsPage extends StatefulWidget {
  final String adminName;
  const SettingsPage({super.key, required this.adminName});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Org Tab
  final TextEditingController _orgNameCtrl = TextEditingController();
  final TextEditingController _orgPhoneCtrl = TextEditingController();
  final TextEditingController _orgEmailCtrl = TextEditingController();
  String _selectedColor = 'blue';

  // Branches Tab
  LatLng _currentLocation = const LatLng(24.7136, 46.6753);
  double _currentRadius = 200.0;
  bool _isSaving = false;
  final TextEditingController _branchNameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Load Org data
    final org = FirebaseService.organization;
    _orgNameCtrl.text = org['name'] ?? '';
    _orgPhoneCtrl.text = org['phone'] ?? '';
    _orgEmailCtrl.text = org['email'] ?? '';
    _selectedColor = org['color'] ?? 'blue';
  }

  Future<void> _saveOrgSettings() async {
    setState(() => _isSaving = true);
    try {
      await FirebaseService.instance.updateOrganization({
        'name': _orgNameCtrl.text,
        'phone': _orgPhoneCtrl.text,
        'email': _orgEmailCtrl.text,
        'color': _selectedColor,
      });
      await FirebaseService.instance.logAction(widget.adminName, 'تحديث إعدادات المؤسسة');
      if (mounted) {
        await Provider.of<AppProvider>(context, listen: false).reloadOrganization();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحفظ بنجاح'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _addBranch() async {
    if (_branchNameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال اسم الفرع')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      await FirebaseService.instance.addBranch(
        name: _branchNameCtrl.text,
        lat: _currentLocation.latitude,
        lng: _currentLocation.longitude,
        radius: _currentRadius,
        adminName: widget.adminName,
      );
      if (mounted) {
        _branchNameCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إضافة الفرع بنجاح'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات النظام', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.business), text: 'المؤسسة'),
            Tab(icon: Icon(Icons.location_city), text: 'الفروع'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrgSettingsTab(),
          _buildBranchesTab(),
        ],
      ),
    );
  }

  Widget _buildOrgSettingsTab() {
    final appProvider = Provider.of<AppProvider>(context);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('البيانات الأساسية للمؤسسة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _orgNameCtrl,
            decoration: const InputDecoration(labelText: 'اسم المؤسسة', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _orgPhoneCtrl,
            decoration: const InputDecoration(labelText: 'رقم التواصل', border: OutlineInputBorder()),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _orgEmailCtrl,
            decoration: const InputDecoration(labelText: 'البريد الإلكتروني للإدارة', border: OutlineInputBorder()),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 24),
          const Text('تخصيص المظهر', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedColor,
            decoration: const InputDecoration(labelText: 'اللون الأساسي', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'blue', child: Text('أزرق (الافتراضي)')),
              DropdownMenuItem(value: 'red', child: Text('أحمر')),
              DropdownMenuItem(value: 'green', child: Text('أخضر')),
              DropdownMenuItem(value: 'orange', child: Text('برتقالي')),
            ],
            onChanged: (val) => setState(() => _selectedColor = val ?? 'blue'),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('تفعيل الوضع الليلي (Dark Mode)'),
            value: appProvider.isDarkMode,
            onChanged: (val) => appProvider.toggleTheme(val),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _isSaving ? null : _saveOrgSettings,
            icon: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.save),
            label: const Text('حفظ التعديلات'),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchesTab() {
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 13,
              onTap: (tapPosition, point) => setState(() => _currentLocation = point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.attendance_app',
              ),
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _currentLocation,
                    color: Colors.blue.withOpacity(0.3),
                    borderColor: Colors.blue,
                    borderStrokeWidth: 2,
                    useRadiusInMeter: true,
                    radius: _currentRadius,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentLocation,
                    width: 60,
                    height: 60,
                    child: const Icon(Icons.location_on, color: Colors.blue, size: 40),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _branchNameCtrl,
                decoration: const InputDecoration(labelText: 'اسم الفرع الجديد', border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('النطاق (متر): '),
                  Expanded(
                    child: Slider(
                      value: _currentRadius,
                      min: 5,
                      max: 1000,
                      divisions: 199,
                      label: '${_currentRadius.toInt()}',
                      onChanged: (val) => setState(() => _currentRadius = val),
                    ),
                  ),
                  Text('${_currentRadius.toInt()}'),
                ],
              ),
              FilledButton.icon(
                onPressed: _isSaving ? null : _addBranch,
                icon: const Icon(Icons.add),
                label: const Text('إضافة الفرع'),
              ),
            ],
          ),
        ),
        const Divider(),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Text('الفروع المضافة', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: FirebaseService.branches.length,
            itemBuilder: (context, index) {
              final branch = FirebaseService.branches[index];
              return ListTile(
                leading: const Icon(Icons.business, color: Colors.blue),
                title: Text(branch['name'] ?? 'بدون اسم'),
                subtitle: Text('النطاق: ${branch['radius']?.toInt()} متر'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    await FirebaseService.instance.deleteBranch(branch['id'], branch['name'] ?? '', widget.adminName);
                    setState((){});
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'services/firebase_service.dart';
import 'login_page.dart';
import 'map_page.dart';
import 'settings_page.dart';

class AdminPage extends StatefulWidget {
  final String name;
  final String role;

  const AdminPage({super.key, required this.name, required this.role});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  int _currentIndex = 0; // 0: الحضور, 1: الموظفين, 2: سجل النظام
  String _searchQuery = "";
  DateTime? _selectedDate;
  
  List<Map<String, dynamic>> _allEmployeesData = [];
  bool _isLoadingEmployees = true;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    try {
      final qs = await FirebaseFirestore.instance.collection('employees').get();
      if (mounted) {
        setState(() {
          _allEmployeesData = qs.docs.map((d) => {'id': d.id, ...d.data()}).toList();
          _isLoadingEmployees = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingEmployees = false);
    }
  }

  void _changePasswordDialog(String employeeId) {
    final TextEditingController pwdController = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('إعادة تعيين كلمة المرور'),
        content: TextField(
          controller: pwdController,
          decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              if (pwdController.text.isNotEmpty) {
                await FirebaseService.instance.updatePassword(employeeId, pwdController.text);
                await FirebaseService.instance.logAction(widget.name, 'تم إعادة تعيين كلمة مرور موظف');
                if (mounted) Navigator.pop(c);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            );
          }
        ),
        title: Text(
          _currentIndex == 0 ? 'سجلات الحضور' : _currentIndex == 1 ? 'إدارة الموظفين' : 'سجل العمليات',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          if (_currentIndex == 0)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
              onPressed: _exportToPDF,
              tooltip: 'تصدير PDF',
            ),
          if (_currentIndex == 0)
            IconButton(
              icon: const Icon(Icons.table_view, color: Colors.green),
              onPressed: _exportToExcel,
              tooltip: 'تصدير Excel',
            ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(widget.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              accountEmail: const Text('مدير النظام'),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.admin_panel_settings, size: 40, color: Colors.blue),
              ),
              decoration: BoxDecoration(color: theme.colorScheme.primary),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('إعدادات المؤسسة والفروع'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsPage(adminName: widget.name)));
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage())),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() {
          _currentIndex = i;
          _searchQuery = "";
        }),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'الحضور'),
          NavigationDestination(icon: Icon(Icons.people), label: 'الموظفين'),
          NavigationDestination(icon: Icon(Icons.history), label: 'العمليات'),
        ],
      ),
      body: Column(
        children: [
          if (_currentIndex != 2) _buildSearchBar(),
          Expanded(
            child: _currentIndex == 0
                ? _buildAttendanceLogs()
                : _currentIndex == 1
                    ? _buildEmployeesList()
                    : _buildSystemLogs(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'بحث (بالاسم، القسم، أو الفرع)...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),
          if (_currentIndex == 0) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.calendar_today, color: _selectedDate != null ? Theme.of(context).colorScheme.primary : Colors.grey),
              onPressed: _pickDate,
            ),
          ]
        ],
      ),
    );
  }

  void _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) {
      setState(() => _selectedDate = d);
    } else {
      setState(() => _selectedDate = null); // clear date if user cancels
    }
  }

  Widget _buildAttendanceLogs() {
    final stream = FirebaseService.instance.attendanceStream(day: _selectedDate);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        var docs = snapshot.data?.docs ?? [];

        // Apply local search filter
        if (_searchQuery.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data();
            final name = (data['name'] ?? '').toString().toLowerCase();
            final branch = (data['branchName'] ?? data['centerName'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery) || branch.contains(_searchQuery);
          }).toList();
        }

        if (docs.isEmpty) return const Center(child: Text('لا توجد سجلات تطابق بحثك'));

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: docs.length,
          itemBuilder: (c, i) {
            final data = docs[i].data();
            final rawDate = data['date'];
            final date = rawDate is Timestamp ? rawDate.toDate() : DateTime.now();
            final isCheckIn = data['status'] == 'check_in';
            
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isCheckIn ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                  child: Icon(isCheckIn ? Icons.login : Icons.logout, color: isCheckIn ? Colors.green : Colors.orange),
                ),
                title: Text(data['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${isCheckIn ? "حضور" : "انصراف"} - ${DateFormat('hh:mm a').format(date)}\nالفرع: ${data['branchName'] ?? data['centerName'] ?? "غير محدد"}'),
                isThreeLine: true,
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => FirebaseService.instance.deleteAttendance(docs[i].id, widget.name),
                ),
                onTap: () {
                  if (data['lat'] != null && data['lng'] != null) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => MapPage(
                      lat: (data['lat'] as num).toDouble(),
                      lng: (data['lng'] as num).toDouble(),
                      name: data['name'],
                      date: date,
                    )));
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmployeesList() {
    if (_isLoadingEmployees) return const Center(child: CircularProgressIndicator());
    
    var filtered = _allEmployeesData.where((e) => e['role'] != 'admin').toList();
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((e) {
        final name = (e['name'] ?? '').toString().toLowerCase();
        final dept = (e['department'] ?? '').toString().toLowerCase();
        return name.contains(_searchQuery) || dept.contains(_searchQuery);
      }).toList();
    }

    if (filtered.isEmpty) return const Center(child: Text('لا يوجد موظفين يطابقون البحث'));

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: filtered.length,
      itemBuilder: (c, i) {
        final emp = filtered[i];
        final bool isActive = emp['isActive'] ?? false;
        
        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(emp['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${emp['job'] ?? ''} - ${emp['department'] ?? ''}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.lock_reset, color: Colors.orange),
                  tooltip: 'تغيير كلمة المرور',
                  onPressed: () => _changePasswordDialog(emp['id']),
                ),
                Switch(
                  value: isActive,
                  onChanged: (v) async {
                    await FirebaseFirestore.instance.collection('employees').doc(emp['id']).update({'isActive': v});
                    await FirebaseService.instance.logAction(widget.name, v ? 'تفعيل حساب موظف' : 'إيقاف حساب موظف');
                    _loadEmployees();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    await FirebaseService.instance.deleteEmployee(emp['id'], emp['name'], widget.name);
                    _loadEmployees();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSystemLogs() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseService.instance.logsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const Center(child: Text('لا توجد سجلات للعمليات'));

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: docs.length,
          itemBuilder: (c, i) {
            final data = docs[i].data();
            final date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
            return Card(
              child: ListTile(
                leading: const Icon(Icons.history, color: Colors.grey),
                title: Text(data['action'] ?? ''),
                subtitle: Text('بواسطة: ${data['user']} - ${DateFormat('yyyy-MM-dd hh:mm a').format(date)}'),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _exportToPDF() async {
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
    try {
      final qs = await FirebaseService.instance.attendanceStream(day: _selectedDate).first;
      final pdf = pw.Document();
      // Using a basic font for PDF as arabic text in pdf requires specific TTF font loading
      // For simplicity, we just use default but it might need proper ttf loading in production for arabic.
      
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              children: [
                pw.Text('Attendance Report', style: const pw.TextStyle(fontSize: 24)),
                pw.SizedBox(height: 20),
                pw.Table.fromTextArray(
                  headers: ['Name', 'Status', 'Date', 'Time', 'Branch'],
                  data: qs.docs.map((doc) {
                    final d = doc.data();
                    final date = (d['date'] as Timestamp).toDate();
                    return [
                      d['name'] ?? '',
                      d['status'] == 'check_in' ? 'Check In' : 'Check Out',
                      DateFormat('yyyy-MM-dd').format(date),
                      DateFormat('hh:mm a').format(date),
                      d['branchName'] ?? d['centerName'] ?? '',
                    ];
                  }).toList(),
                ),
              ],
            );
          },
        ),
      );

      final output = await getApplicationDocumentsDirectory();
      final file = File("${output.path}/Attendance_Report.pdf");
      await file.writeAsBytes(await pdf.save());

      if (!mounted) return;
      Navigator.pop(context); // Close loading
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تصدير الـ PDF بنجاح'),
          action: SnackBarAction(label: 'فتح', onPressed: () => OpenFile.open(file.path)),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في التصدير: $e')));
      }
    }
  }

  Future<void> _exportToExcel() async {
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
    try {
      final qs = await FirebaseService.instance.attendanceStream(day: _selectedDate).first;
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Attendance'];
      excel.delete('Sheet1');

      sheetObject.appendRow([
        TextCellValue('اسم الموظف'),
        TextCellValue('الحالة'),
        TextCellValue('التاريخ'),
        TextCellValue('الوقت'),
        TextCellValue('اسم الفرع'),
      ]);

      for (var doc in qs.docs) {
        final data = doc.data();
        final date = (data['date'] as Timestamp).toDate();
        sheetObject.appendRow([
          TextCellValue(data['name'] ?? ''),
          TextCellValue(data['status'] == 'check_in' ? 'حضور' : 'انصراف'),
          TextCellValue(DateFormat('yyyy-MM-dd').format(date)),
          TextCellValue(DateFormat('hh:mm a').format(date)),
          TextCellValue(data['branchName'] ?? data['centerName'] ?? 'غير محدد'),
        ]);
      }

      var fileBytes = excel.save();
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'Attendance_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(fileBytes!);

      if (!mounted) return;
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم التصدير بنجاح: $fileName'),
          action: SnackBarAction(label: 'فتح', onPressed: () => OpenFile.open(file.path)),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في التصدير: $e')));
      }
    }
  }
}

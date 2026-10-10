import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // List of all available branches
  static List<Map<String, dynamic>> branches = [];
  
  // Organization details
  static Map<String, dynamic> organization = {
    'name': 'نظام الحضور والانصراف',
    'color': 'blue',
    'phone': '',
    'email': '',
    'address': ''
  };

  /// Fetch organization details
  Future<void> fetchOrganization() async {
    try {
      final qs = await _db.collection('organizations').limit(1).get();
      if (qs.docs.isNotEmpty) {
        organization = qs.docs.first.data();
        organization['id'] = qs.docs.first.id;
      } else {
        // Create default if not exists
        final docRef = await _db.collection('organizations').add(organization);
        organization['id'] = docRef.id;
      }
    } catch (e) {
      print('Error fetching organization: $e');
    }
  }

  /// Update organization details
  Future<void> updateOrganization(Map<String, dynamic> data) async {
    if (organization.containsKey('id')) {
      await _db.collection('organizations').doc(organization['id']).update(data);
    } else {
      await _db.collection('organizations').add(data);
    }
    await fetchOrganization();
  }

  /// Fetch all branches from Firestore
  Future<void> fetchBranches() async {
    try {
      final qs = await _db.collection('branches').get();
      branches = qs.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      
      // Migration fallback from centers if branches is empty (optional safety)
      if (branches.isEmpty) {
        final qsCenters = await _db.collection('centers').get();
        if (qsCenters.docs.isNotEmpty) {
          for (var doc in qsCenters.docs) {
             await _db.collection('branches').add(doc.data());
          }
          final newQs = await _db.collection('branches').get();
          branches = newQs.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        } else {
          branches = [{
            'id': 'default',
            'name': 'الفرع الرئيسي',
            'lat': 24.7136,
            'lng': 46.6753,
            'radius': 200.0,
          }];
        }
      }
    } catch (e) {
      print('Error fetching branches: $e');
    }
  }

  /// Add a new branch
  Future<void> addBranch({
    required String name,
    required double lat,
    required double lng,
    required double radius,
    required String adminName,
  }) async {
    await _db.collection('branches').add({
      'name': name,
      'lat': lat,
      'lng': lng,
      'radius': radius,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await logAction(adminName, 'تم إضافة فرع جديد: $name');
    await fetchBranches();
  }
  
  /// Update an existing branch
  Future<void> updateBranch(String id, Map<String, dynamic> data, String adminName) async {
    await _db.collection('branches').doc(id).update(data);
    await logAction(adminName, 'تم تعديل بيانات الفرع: ${data['name'] ?? id}');
    await fetchBranches();
  }

  /// Delete a branch
  Future<void> deleteBranch(String id, String branchName, String adminName) async {
    await _db.collection('branches').doc(id).delete();
    await logAction(adminName, 'تم حذف الفرع: $branchName');
    await fetchBranches();
  }

  /// Register a new employee account
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String job,
    required String department,
    String? branch,
  }) async {
    final check = await _db.collection('employees').where('email', isEqualTo: email).get();
    if (check.docs.isNotEmpty) {
      throw 'هذا البريد الإلكتروني مسجل مسبقاً';
    }
    await _db.collection('employees').add({
      'email': email,
      'password': password,
      'name': name,
      'job': job,
      'department': department,
      'branch': branch ?? 'عام',
      'role': 'employee',
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>?> signIn(String email, String password) async {
    final qs = await _db.collection('employees').where('email', isEqualTo: email).limit(1).get();
    if (qs.docs.isEmpty) return null;
    final doc = qs.docs.first;
    final data = doc.data();
    final stored = data['password'] as String? ?? '';
    if (stored != password) return null;
    return {'id': doc.id, ...data};
  }

  Future<void> updatePassword(String employeeId, String newPassword) async {
    await _db.collection('employees').doc(employeeId).update({'password': newPassword});
  }

  Future<void> updateEmployeeInfo(String employeeId, Map<String, dynamic> info) async {
    await _db.collection('employees').doc(employeeId).update(info);
  }

  Future<void> deleteEmployee(String id, String employeeName, String adminName) async {
    await _db.collection('employees').doc(id).delete();
    await logAction(adminName, 'تم حذف الموظف: $employeeName');
  }

  Future<void> saveAttendance({
    required String name,
    required String status,
    required double lat,
    required double lng,
    String? branchName,
    String? verificationType,
  }) async {
    await _db.collection('attendance').add({
      'name': name,
      'date': FieldValue.serverTimestamp(),
      'status': status,
      'lat': lat,
      'lng': lng,
      'centerName': branchName, // Keeping it centerName for backwards compatibility
      'branchName': branchName,
      'verificationType': verificationType ?? 'GPS',
    });
    await logAction(name, status == 'check_in' ? 'قام بتسجيل الحضور' : 'قام بتسجيل الانصراف');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> attendanceStream({String? name, DateTime? day}) {
    Query<Map<String, dynamic>> q = _db.collection('attendance').orderBy('date', descending: true);
    if (name != null && name.isNotEmpty) q = q.where('name', isEqualTo: name);
    if (day != null) {
      final start = DateTime(day.year, day.month, day.day).toUtc();
      final end = start.add(const Duration(days: 1));
      q = q.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
           .where('date', isLessThan: Timestamp.fromDate(end));
    }
    return q.snapshots();
  }

  Future<void> deleteAttendance(String docId, String adminName) async {
    await _db.collection('attendance').doc(docId).delete();
    await logAction(adminName, 'قام بحذف سجل حضور');
  }

  Future<bool> hasAttendanceToday(String name, String status) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final qs = await _db.collection('attendance')
        .where('name', isEqualTo: name)
        .where('status', isEqualTo: status)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .limit(1).get();
    return qs.docs.isNotEmpty;
  }

  // Logs Action
  Future<void> logAction(String user, String action) async {
    await _db.collection('logs').add({
      'user': user,
      'action': action,
      'date': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> logsStream() {
    return _db.collection('logs').orderBy('date', descending: true).snapshots();
  }
}

// lib/screens/admin_dashboard.dart
// ignore_for_file: unnecessary_cast

import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:schaccs/screens/login_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;

class AdminDashboard extends StatefulWidget {
  static const routeName = '/admin';
  final String schoolCode;
  final String adminDocId;
  const AdminDashboard({
    required this.schoolCode,
    required this.adminDocId,
    super.key,
  });
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _tab = 0;
  final _tabs = [
    'Home',
    'Students',
    'Parents',
    'Payments',
    'Reports',
    'Settings',
  ];

  Future<bool> _onWillPop() async {
    if (_tab != 0) {
      setState(() => _tab = 0);
      return false;
    }
    return true;
  }

  void _logout() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/login',
      (_) => false,
      arguments: widget.schoolCode,
    );
  }

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.of(context).pushNamedAndRemoveUntil(
                LoginScreen.routeName, // '/login'
                (Route<dynamic> route) => false, // clear the entire stack
                arguments: widget.schoolCode, // pass the schoolCode along
              );
            },
          ),
          title: Text(
            _tabs[_tab],
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Color(0xFFB45309), // Amber 700
          elevation: 4,
          actions: [IconButton(icon: Icon(Icons.logout), onPressed: _logout)],
        ),
        body: IndexedStack(
          index: _tab,
          children: [
            _HomeView(schoolCode: widget.schoolCode),
            _StudentsView(schoolCode: widget.schoolCode),
            _ParentsView(schoolCode: widget.schoolCode),
            PaymentsView(schoolCode: widget.schoolCode),
            _ReportsView(schoolCode: widget.schoolCode),
            _SettingsView(
              schoolCode: widget.schoolCode,
              adminDocId: widget.adminDocId,
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i),
          unselectedItemColor: Colors.brown[300],
          selectedItemColor: Color(0xFFB45309), // Amber 700
          backgroundColor: Colors.white,
          elevation: 8,
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Students',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.family_restroom),
              label: 'Parents',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.payment),
              label: 'Payments',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.insert_chart),
              label: 'Reports',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────── HOME ───────────
class _HomeView extends StatelessWidget {
  final String schoolCode;
  const _HomeView({required this.schoolCode});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: Color(0xFFFFF7ED), // Orange 50 background
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Overview',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Color(0xFFB45309),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            _StatsGrid(schoolCode: schoolCode),
            SizedBox(height: 24),
            Text(
              'Excel Data Import',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Color(0xFFB45309),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Expanded(child: _ExcelImportCards(schoolCode: schoolCode)),
          ],
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final String schoolCode;
  const _StatsGrid({required this.schoolCode});

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.8, // CHANGED: Reduced from 2.2 to 1.8 for more height
      children: [
        _StatCard(
          icon: Icons.people,
          label: 'Students',
          stream: FirebaseFirestore.instance
              .collection('schools')
              .doc(schoolCode)
              .collection('students')
              .snapshots()
              .map((s) => s.docs.length.toString()),
        ),
        _StatCard(
          icon: Icons.family_restroom,
          label: 'Parents',
          stream: FirebaseFirestore.instance
              .collection('schools')
              .doc(schoolCode)
              .collection('parents')
              .snapshots()
              .map((s) => s.docs.length.toString()),
        ),
        _StatCard(
          icon: Icons.attach_money,
          label: 'Collected',
          stream: FirebaseFirestore.instance
              .collection('schools')
              .doc(schoolCode)
              .collection('payments')
              .where(
                'type',
                isEqualTo: 'payment history',
              ) // ADDED: Filter for payment history only
              .snapshots()
              .map((s) {
                final total = s.docs.fold<double>(
                  0,
                  (sum, d) =>
                      sum + (d.data()['amount'] as num? ?? 0).toDouble(),
                );
                return 'KES ${_formatCurrency(total)}'; // CHANGED: Better formatting
              }),
        ),
        _StatCard(
          icon: Icons.warning,
          label: 'With Balance',
          stream: FirebaseFirestore.instance
              .collection('schools')
              .doc(schoolCode)
              .collection('payments')
              .where(
                'type',
                isEqualTo: 'fee summary',
              ) // CHANGED: Use fee summary data
              .snapshots()
              .map((s) {
                int count =
                    s.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final totalBalance =
                          (data['totalBalance'] as num? ?? 0).toDouble();
                      return totalBalance >
                          0; // Students with outstanding balance
                    }).length;
                return count.toString();
              }),
        ),
      ],
    );
  }

  // ADDED: Helper function for better currency formatting
  static String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    } else {
      return amount.toStringAsFixed(0);
    }
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Stream<String> stream;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.stream,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFFEF3C7)], // Amber 100
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: EdgeInsets.all(12),
        child: StreamBuilder<String>(
          stream: stream,
          builder: (ctx, snap) {
            return Column(
              // CHANGED: From Row to Column for better layout
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Color(
                          0xFFFBBF24,
                        ).withOpacity(0.2), // Amber 400 with opacity
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        size: 24, // CHANGED: Reduced from 28 to 24
                        color: Color(0xFFB45309), // Amber 700
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.brown[700],
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8), // ADDED: Space between label and value
                Expanded(
                  child: Center(
                    // ADDED: Center the value
                    child: Text(
                      snap.data ?? '…',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF92400E),
                        fontSize: 18, // ADDED: Explicit font size
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                      textAlign: TextAlign.center, // ADDED: Center alignment
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ExcelImportCards extends StatelessWidget {
  final String schoolCode;
  const _ExcelImportCards({required this.schoolCode});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ExcelImportCard(
                title: 'Student Data',
                subtitle: 'Import student details from Excel',
                icon: Icons.people,
                color: Colors.blue,
                onTap: () => _importStudentData(context),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _ExcelImportCard(
                title: 'Payment History',
                subtitle: 'Import payment records from Excel',
                icon: Icons.payment,
                color: Colors.green,
                onTap: () => _importPaymentHistory(context),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        _ExcelImportCard(
          title: 'Fee Summary',
          subtitle: 'Import fee summary data from Excel',
          icon: Icons.summarize,
          color: Colors.orange,
          onTap: () => _importFeeSummary(context),
        ),
      ],
    );
  }

  void _importStudentData(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result != null) {
        late Uint8List rawBytes;

        if (result.files.first.bytes != null) {
          rawBytes = result.files.first.bytes!;
        } else if (result.files.first.path != null) {
          rawBytes = await File(result.files.first.path!).readAsBytes();
        } else {
          throw Exception('No file bytes or path available.');
        }

        final excel = Excel.decodeBytes(rawBytes);

        for (var table in excel.tables.keys) {
          final sheet = excel.tables[table]!;

          // Skip header row, start from row 1
          for (int i = 1; i < sheet.maxRows; i++) {
            final row = sheet.rows[i];
            if (row.length >= 4) {
              // Safe null checking with proper defaults
              final admNo = row[0]?.value?.toString().trim();
              final name = row[1]?.value?.toString().trim() ?? '';
              final studentClass = row[2]?.value?.toString().trim() ?? '';
              final phoneNumber = row[3]?.value?.toString().trim() ?? '';

              // Only process if admission number exists and is not empty
              if (admNo != null && admNo.isNotEmpty) {
                await _processStudentData(
                  admNo,
                  name,
                  studentClass,
                  phoneNumber,
                );
              }
            }
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Student data imported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error importing student data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _processStudentData(
    String admNo,
    String? name,
    String? studentClass,
    String? phoneNumber,
  ) async {
    final studentsRef = FirebaseFirestore.instance
        .collection('schools')
        .doc(schoolCode)
        .collection('students');

    // Check if student exists
    final existingStudent =
        await studentsRef.where('admissionNo', isEqualTo: admNo).get();

    final studentData = {
      'name': name ?? '',
      'class': studentClass ?? '',
      'parentPhone': phoneNumber ?? '',
      'admissionNo': admNo,
    };

    if (existingStudent.docs.isNotEmpty) {
      // Update existing student
      await existingStudent.docs.first.reference.update({
        ...studentData,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      // Create new student
      await studentsRef.add({
        ...studentData,
        'age': 0,
        'city': '',
        'homeAddress': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  void _importPaymentHistory(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true, // ← ensure `.bytes` is populated
      );

      if (result != null) {
        // 1) Safely get the raw bytes. If `.bytes` is null, read from `path`.
        late Uint8List rawBytes;
        if (result.files.first.bytes != null) {
          rawBytes = result.files.first.bytes!;
        } else if (result.files.first.path != null) {
          rawBytes = await File(result.files.first.path!).readAsBytes();
        } else {
          throw Exception('Unable to read file: no bytes or path available');
        }

        final excel = Excel.decodeBytes(rawBytes);

        for (var table in excel.tables.keys) {
          final sheet = excel.tables[table]!;

          for (int i = 1; i < sheet.maxRows; i++) {
            final row = sheet.rows[i];
            if (row.length >= 8) {
              // 2) Null-safe extraction + trim:
              final rawAdm = row[0]?.value;
              final rawName = row[1]?.value;
              final rawClass = row[2]?.value;
              final rawDateStr = row[3]?.value;
              final rawReceiptNo = row[4]?.value;
              final rawTotal = row[5]?.value;
              final rawPayMode = row[6]?.value;
              final rawTransNo = row[7]?.value;

              final admNo = (rawAdm != null) ? rawAdm.toString().trim() : null;
              final name = (rawName != null) ? rawName.toString().trim() : null;
              final studentClass =
                  (rawClass != null) ? rawClass.toString().trim() : null;
              final dateStr =
                  (rawDateStr != null) ? rawDateStr.toString().trim() : null;
              final receiptNo =
                  (rawReceiptNo != null)
                      ? rawReceiptNo.toString().trim()
                      : null;
              final total =
                  (rawTotal != null) ? rawTotal.toString().trim() : null;
              final paymentMode =
                  (rawPayMode != null) ? rawPayMode.toString().trim() : null;
              final transactionNo =
                  (rawTransNo != null) ? rawTransNo.toString().trim() : null;

              if (admNo != null && admNo.isNotEmpty) {
                await _processPaymentHistory(
                  admNo,
                  name,
                  studentClass,
                  dateStr,
                  receiptNo,
                  total,
                  paymentMode,
                  transactionNo,
                );
              }
            }
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment history imported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error importing payment history: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _processPaymentHistory(
    String admNo,
    String? name,
    String? studentClass,
    String? dateStr,
    String? receiptNo,
    String? total,
    String? paymentMode,
    String? transactionNo,
  ) async {
    // Verify student exists and matches
    final studentsRef = FirebaseFirestore.instance
        .collection('schools')
        .doc(schoolCode)
        .collection('students');

    final studentQuery =
        await studentsRef.where('admissionNo', isEqualTo: admNo).get();

    if (studentQuery.docs.isEmpty) {
      return; // Skip if student doesn't exist
    }

    final student = studentQuery.docs.first;
    final studentData = student.data();

    // Verify name and class match (case insensitive)
    if (name != null &&
        name.isNotEmpty &&
        studentData['name']?.toString().toLowerCase() != name.toLowerCase()) {
      return; // Skip if name doesn't match
    }
    if (studentClass != null &&
        studentClass.isNotEmpty &&
        studentData['class']?.toString().toLowerCase() !=
            studentClass.toLowerCase()) {
      return; // Skip if class doesn't match
    }

    // Parse date (DD-MM-YY format)
    DateTime? paymentDate;
    if (dateStr != null && dateStr.isNotEmpty) {
      try {
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]) + 2000; // Assuming 20XX
          paymentDate = DateTime(year, month, day);
        }
      } catch (e) {
        paymentDate = DateTime.now();
      }
    } else {
      paymentDate = DateTime.now();
    }

    // Create unique document ID
    String baseDocId =
        '$admNo-payment-history-${DateTime.now().millisecondsSinceEpoch}';
    String docId = await getUniqueDocId(schoolCode, 'payments', baseDocId);

    // FIXED: Create payment record with only essential fields (removed studentId)
    await FirebaseFirestore.instance
        .collection('schools')
        .doc(schoolCode)
        .collection('payments')
        .doc(docId)
        .set({
          'admissionNo': admNo, // Use admission number instead of studentId
          'amount': double.tryParse(total ?? '0') ?? 0,
          'mode': paymentMode ?? '',
          'receiptNumber': receiptNo ?? '',
          'transactionNumber': transactionNo ?? '',
          'date': Timestamp.fromDate(paymentDate!),
          'type': 'payment history',
          'timestamp': FieldValue.serverTimestamp(),
        });
  }

  void _importFeeSummary(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result != null) {
        late Uint8List rawBytes;
        if (result.files.first.bytes != null) {
          rawBytes = result.files.first.bytes!;
        } else if (result.files.first.path != null) {
          rawBytes = await File(result.files.first.path!).readAsBytes();
        } else {
          throw Exception('Unable to read file: no bytes or path available');
        }

        final excel = Excel.decodeBytes(rawBytes);
        int processedCount = 0;
        int errorCount = 0;

        for (var table in excel.tables.keys) {
          final sheet = excel.tables[table]!;
          print(
            'Processing sheet: $table with ${sheet.maxRows} rows',
          ); // Debug log

          // FIXED: Skip header row, start from row 1
          for (int i = 1; i < sheet.maxRows; i++) {
            final row = sheet.rows[i];
            print(
              'Processing row $i: ${row.map((cell) => cell?.value).toList()}',
            ); // Debug log

            // FIXED: Check for minimum required columns (8 columns based on your Excel)
            if (row.length >= 8) {
              final admNo = row[0]?.value?.toString().trim();
              final name = row[1]?.value?.toString().trim();
              final studentClass = row[2]?.value?.toString().trim();

              if (admNo != null && admNo.isNotEmpty) {
                try {
                  await _processFeeSummary(admNo, name, studentClass, row);
                  processedCount++;
                } catch (e) {
                  print(
                    'Error processing row $i for admission $admNo: $e',
                  ); // Debug log
                  errorCount++;
                }
              } else {
                print('Skipping row $i: empty admission number'); // Debug log
              }
            } else {
              print(
                'Skipping row $i: insufficient columns (${row.length})',
              ); // Debug log
            }
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Fee summary imported successfully! Processed: $processedCount, Errors: $errorCount',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Import error: $e'); // Debug log
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error importing fee summary: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _processFeeSummary(
    String admNo,
    String? name,
    String? studentClass,
    List<Data?> row,
  ) async {
    print('Processing fee summary for admission: $admNo'); // Debug log

    // Verify student exists and matches
    final studentsRef = FirebaseFirestore.instance
        .collection('schools')
        .doc(schoolCode)
        .collection('students');

    final studentQuery =
        await studentsRef.where('admissionNo', isEqualTo: admNo).get();

    if (studentQuery.docs.isEmpty) {
      print('Student not found for admission: $admNo'); // Debug log
      return; // Skip if student doesn't exist
    }

    final student = studentQuery.docs.first;
    final studentData = student.data();

    // Verify name and class match (if provided) - case insensitive
    if (name != null &&
        name.isNotEmpty &&
        studentData['name']?.toString().toLowerCase() != name.toLowerCase()) {
      print(
        'Name mismatch for $admNo: expected ${studentData['name']}, got $name',
      ); // Debug log
      return;
    }
    if (studentClass != null &&
        studentClass.isNotEmpty &&
        studentData['class']?.toString().toLowerCase() !=
            studentClass.toLowerCase()) {
      print(
        'Class mismatch for $admNo: expected ${studentData['class']}, got $studentClass',
      ); // Debug log
      return;
    }

    // FIXED: Safe extraction of fee data with proper null checks and column mapping
    // Based on your Excel: ADM, NAME, CLASS, TRQD, TRPAID, TOTALRQ, TOTALPAID, TOTALBAL
    final feeSummaryData = {
      'admissionNo': admNo,
      'name': name ?? studentData['name'] ?? '',
      'class': studentClass ?? studentData['class'] ?? '',
      // Term data (columns 3, 4, calculated balance)
      'termRequired':
          double.tryParse(row[3]?.value?.toString() ?? '0') ?? 0, // TRQD
      'termPaid':
          double.tryParse(row[4]?.value?.toString() ?? '0') ?? 0, // TRPAID
      'termBalance':
          (double.tryParse(row[3]?.value?.toString() ?? '0') ?? 0) -
          (double.tryParse(row[4]?.value?.toString() ?? '0') ??
              0), // TRQD - TRPAID
      // Total data (columns 5, 6, 7)
      'totalRequired':
          double.tryParse(row[5]?.value?.toString() ?? '0') ?? 0, // TOTALRQ
      'totalPaid':
          double.tryParse(row[6]?.value?.toString() ?? '0') ?? 0, // TOTALPAID
      'totalBalance':
          double.tryParse(row[7]?.value?.toString() ?? '0') ?? 0, // TOTALBAL
      'type': 'fee summary',
    };

    print('Fee summary data: $feeSummaryData'); // Debug log

    // Check if fee summary already exists for this student
    final existingFeeSummary =
        await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolCode)
            .collection('payments')
            .where('admissionNo', isEqualTo: admNo)
            .where('type', isEqualTo: 'fee summary')
            .get();

    if (existingFeeSummary.docs.isNotEmpty) {
      // Update existing fee summary
      print('Updating existing fee summary for $admNo'); // Debug log
      await existingFeeSummary.docs.first.reference.update({
        ...feeSummaryData,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      // Create new fee summary with unique doc ID
      String baseDocId = '$admNo-fee-summary';
      String docId = await getUniqueDocId(schoolCode, 'payments', baseDocId);

      print(
        'Creating new fee summary for $admNo with docId: $docId',
      ); // Debug log
      await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolCode)
          .collection('payments')
          .doc(docId)
          .set({...feeSummaryData, 'createdAt': FieldValue.serverTimestamp()});
    }
  }
}

class _ExcelImportCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ExcelImportCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [Colors.white, color.withOpacity(0.1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  Spacer(),
                  Icon(Icons.upload_file, color: color),
                ],
              ),
              SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────── PAYMENTS VIEW WITH TABS ─────────
class PaymentsView extends StatefulWidget {
  final String schoolCode;
  const PaymentsView({Key? key, required this.schoolCode}) : super(key: key);

  @override
  PaymentsViewState createState() => PaymentsViewState();
}

class PaymentsViewState extends State<PaymentsView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF7ED),
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFFB45309),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFFB45309),
              tabs: const [
                Tab(text: 'Payment History'),
                Tab(text: 'Fee Summary'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                PaymentHistoryTab(schoolCode: widget.schoolCode),
                FeeSummaryTab(schoolCode: widget.schoolCode),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentHistoryTab extends StatelessWidget {
  final String schoolCode;
  const PaymentHistoryTab({Key? key, required this.schoolCode})
    : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFB45309),
        onPressed: () => _showPaymentHistoryForm(context, null, schoolCode),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Container(
        color: const Color(0xFFFFF7ED),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Payment History',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFB45309),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream:
                    FirebaseFirestore.instance
                        .collection('schools')
                        .doc(schoolCode)
                        .collection('payments')
                        .where('type', isEqualTo: 'payment history')
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFB45309),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(child: Text('No payment history available.'));
                  }

                  return ListView.builder(
                    padding: EdgeInsets.only(bottom: 80),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final doc = snapshot.data!.docs[index];
                      final d = doc.data() as Map<String, dynamic>;
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          title: Text(
                            'KES ${(d['amount'] as num).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF92400E),
                            ),
                          ),
                          subtitle: Text(
                            '${d['mode'] ?? 'N/A'} • ${DateFormat('dd MMM yyyy').format((d['date'] as Timestamp).toDate())} • Adm#: ${d['admissionNo']}\nRct: ${d['receiptNumber'] ?? 'N/A'} • Trn: ${d['transactionNumber'] ?? 'N/A'}',
                          ),
                          trailing: const Icon(
                            Icons.edit,
                            color: Color(0xFFB45309),
                          ),
                          onTap:
                              () => _showPaymentHistoryForm(
                                context,
                                doc,
                                schoolCode,
                              ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentHistoryForm(
    BuildContext ctx,
    QueryDocumentSnapshot? doc,
    String code,
  ) async {
    final isEdit = doc != null;
    final data =
        isEdit ? doc.data()! as Map<String, dynamic> : <String, dynamic>{};
    final amountCtl = TextEditingController(text: data['amount']?.toString());
    final modeCtl = TextEditingController(text: data['mode'] as String?);
    final receiptCtl = TextEditingController(
      text: data['receiptNumber'] as String?,
    );
    final transactionCtl = TextEditingController(
      text: data['transactionNumber'] as String?,
    );
    DateTime date =
        data['date'] != null
            ? (data['date'] as Timestamp).toDate()
            : DateTime.now();

    final studentSnap =
        await FirebaseFirestore.instance
            .collection('schools')
            .doc(code)
            .collection('students')
            .orderBy('admissionNo')
            .get();
    final studentDocs = studentSnap.docs;

    if (studentDocs.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text('No students found. Please add students first.'),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (_) => PaymentHistoryFormContent(
            ctx: ctx,
            doc: doc,
            code: code,
            isEdit: isEdit,
            data: data,
            amountCtl: amountCtl,
            modeCtl: modeCtl,
            receiptCtl: receiptCtl,
            transactionCtl: transactionCtl,
            date: date,
            studentDocs: studentDocs,
          ),
    );
  }
}

class PaymentHistoryFormContent extends StatefulWidget {
  final BuildContext ctx;
  final QueryDocumentSnapshot? doc;
  final String code;
  final bool isEdit;
  final Map<String, dynamic> data;
  final TextEditingController amountCtl;
  final TextEditingController modeCtl;
  final TextEditingController receiptCtl;
  final TextEditingController transactionCtl;
  final DateTime date;
  final List<QueryDocumentSnapshot> studentDocs;

  const PaymentHistoryFormContent({
    Key? key,
    required this.ctx,
    required this.doc,
    required this.code,
    required this.isEdit,
    required this.data,
    required this.amountCtl,
    required this.modeCtl,
    required this.receiptCtl,
    required this.transactionCtl,
    required this.date,
    required this.studentDocs,
  }) : super(key: key);

  @override
  PaymentHistoryFormContentState createState() =>
      PaymentHistoryFormContentState();
}

class PaymentHistoryFormContentState extends State<PaymentHistoryFormContent> {
  String? selectedAdmissionNo;
  late DateTime selectedDate;

  @override
  void initState() {
    super.initState();
    selectedAdmissionNo =
        widget.isEdit ? widget.data['admissionNo'] as String? : null;
    selectedDate = widget.date;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(widget.ctx).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.isEdit ? 'Edit Payment History' : 'Add Payment History',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFFB45309),
              ),
            ),
            const SizedBox(height: 16),
            ModernField(
              controller: widget.amountCtl,
              label: 'Amount',
              keyboard: TextInputType.number,
            ),
            ModernField(controller: widget.modeCtl, label: 'Payment Mode'),
            ModernField(controller: widget.receiptCtl, label: 'Receipt Number'),
            ModernField(
              controller: widget.transactionCtl,
              label: 'Transaction Number',
            ),
            // Student dropdown
            Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonFormField<String>(
                value: selectedAdmissionNo,
                hint: Text(
                  'Select Student',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                decoration: const InputDecoration(
                  labelText: 'Student (Adm#)',
                  labelStyle: TextStyle(color: Color(0xFF92400E)),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  filled: true,
                  fillColor: Color(0xFFFFF7ED),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: Color(0xFFB45309), width: 2),
                  ),
                ),
                items:
                    widget.studentDocs.map((s) {
                      final sd = s.data() as Map<String, dynamic>;
                      final adm = sd['admissionNo'] as String;
                      return DropdownMenuItem<String>(
                        value: adm,
                        child: Text('$adm – ${sd['name']}'),
                      );
                    }).toList(),
                onChanged: (newAdm) {
                  setState(() => selectedAdmissionNo = newAdm);
                },
                dropdownColor: Colors.white,
              ),
            ),
            // Date picker
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: const Color(0xFFFFF7ED),
              child: ListTile(
                title: Text(
                  'Date: ${DateFormat('dd MMM yyyy').format(selectedDate)}',
                  style: const TextStyle(color: Color(0xFF92400E)),
                ),
                trailing: const Icon(
                  Icons.calendar_today,
                  color: Color(0xFFB45309),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: widget.ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    builder:
                        (ctx, child) => Theme(
                          data: Theme.of(ctx).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: Color(0xFFB45309),
                              onPrimary: Colors.white,
                              surface: Colors.white,
                              onSurface: Colors.black,
                            ),
                          ),
                          child: child!,
                        ),
                  );
                  if (picked != null) {
                    setState(() => selectedDate = picked);
                  }
                },
              ),
            ),
            const SizedBox(height: 24),
            // Submit button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor:
                      selectedAdmissionNo == null
                          ? Colors.grey[400]
                          : const Color(0xFFB45309),
                  shape: const StadiumBorder(),
                  minimumSize: const Size(0, 50),
                ),
                onPressed:
                    selectedAdmissionNo == null
                        ? null
                        : () async {
                          // Find student ID
                          final student = widget.studentDocs.firstWhere(
                            (s) =>
                                (s.data()
                                    as Map<String, dynamic>)['admissionNo'] ==
                                selectedAdmissionNo,
                          );

                          if (widget.isEdit) {
                            // Update existing payment
                            await widget.doc!.reference.update({
                              'amount':
                                  double.tryParse(widget.amountCtl.text) ?? 0,
                              'mode': widget.modeCtl.text.trim(),
                              'receiptNumber': widget.receiptCtl.text.trim(),
                              'transactionNumber':
                                  widget.transactionCtl.text.trim(),
                              'date': Timestamp.fromDate(selectedDate),
                              'admissionNo': selectedAdmissionNo!,
                              'studentId': student.id,
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                          } else {
                            // Create new payment with unique doc ID
                            String baseDocId =
                                '$selectedAdmissionNo-payment history';
                            String docId = await getUniqueDocId(
                              widget.code,
                              'payments',
                              baseDocId,
                            );

                            await FirebaseFirestore.instance
                                .collection('schools')
                                .doc(widget.code)
                                .collection('payments')
                                .doc(docId)
                                .set({
                                  'amount':
                                      double.tryParse(widget.amountCtl.text) ??
                                      0,
                                  'mode': widget.modeCtl.text.trim(),
                                  'receiptNumber':
                                      widget.receiptCtl.text.trim(),
                                  'transactionNumber':
                                      widget.transactionCtl.text.trim(),
                                  'date': Timestamp.fromDate(selectedDate),
                                  'admissionNo': selectedAdmissionNo!,
                                  'studentId': student.id,
                                  'type': 'payment history',
                                  'timestamp': FieldValue.serverTimestamp(),
                                });
                          }
                          Navigator.pop(widget.ctx);
                        },
                child: Text(widget.isEdit ? 'Save Payment' : 'Add Payment'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class FeeSummaryTab extends StatelessWidget {
  final String schoolCode;
  const FeeSummaryTab({Key? key, required this.schoolCode}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: Color(0xFFB45309),
        onPressed: () => _showFeeSummaryForm(context, null, schoolCode),
        child: Icon(Icons.add, color: Colors.white),
      ),
      body: Container(
        color: Color(0xFFFFF7ED),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Fee Summary',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFB45309),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream:
                    FirebaseFirestore.instance
                        .collection('schools')
                        .doc(schoolCode)
                        .collection('payments')
                        .where('type', isEqualTo: 'fee summary')
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFB45309),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Text('No fee summary data available.'),
                    );
                  }

                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final doc = snapshot.data!.docs[index];
                      final d = doc.data() as Map<String, dynamic>;
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          title: Text(
                            '${d['name']} (${d['admissionNo']})',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF92400E),
                            ),
                          ),
                          subtitle: Text(
                            'Class: ${d['class']}\nTerm Required: KES ${(d['termRequired'] ?? 0).toStringAsFixed(2)} • Term Paid: KES ${(d['termPaid'] ?? 0).toStringAsFixed(2)} • Term Balance: KES ${(d['termBalance'] ?? 0).toStringAsFixed(2)}\nTotal Required: KES ${(d['totalRequired'] ?? 0).toStringAsFixed(2)} • Total Paid: KES ${(d['totalPaid'] ?? 0).toStringAsFixed(2)} • Total Balance: KES ${(d['totalBalance'] ?? 0).toStringAsFixed(2)}',
                          ),
                          trailing: const Icon(
                            Icons.edit,
                            color: Color(0xFFB45309),
                          ),
                          onTap:
                              () =>
                                  _showFeeSummaryForm(context, doc, schoolCode),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFeeSummaryForm(
    BuildContext ctx,
    QueryDocumentSnapshot? doc,
    String code,
  ) async {
    final isEdit = doc != null;
    final data =
        isEdit ? doc.data()! as Map<String, dynamic> : <String, dynamic>{};

    // Controllers for simplified fee summary fields
    final nameCtl = TextEditingController(text: data['name'] as String?);
    final classCtl = TextEditingController(text: data['class'] as String?);
    final termRequiredCtl = TextEditingController(
      text: data['termRequired']?.toString(),
    );
    final termPaidCtl = TextEditingController(
      text: data['termPaid']?.toString(),
    );
    final termBalanceCtl = TextEditingController(
      text: data['termBalance']?.toString(),
    );
    final totalRequiredCtl = TextEditingController(
      text: data['totalRequired']?.toString(),
    );
    final totalPaidCtl = TextEditingController(
      text: data['totalPaid']?.toString(),
    );
    final totalBalanceCtl = TextEditingController(
      text: data['totalBalance']?.toString(),
    );

    final studentSnap =
        await FirebaseFirestore.instance
            .collection('schools')
            .doc(code)
            .collection('students')
            .orderBy('admissionNo')
            .get();
    final studentDocs = studentSnap.docs;

    if (studentDocs.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text('No students found. Please add students first.'),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (_) => FeeSummaryFormContent(
            ctx: ctx,
            doc: doc,
            code: code,
            isEdit: isEdit,
            data: data,
            nameCtl: nameCtl,
            classCtl: classCtl,
            termRequiredCtl: termRequiredCtl,
            termPaidCtl: termPaidCtl,
            termBalanceCtl: termBalanceCtl,
            totalRequiredCtl: totalRequiredCtl,
            totalPaidCtl: totalPaidCtl,
            totalBalanceCtl: totalBalanceCtl,
            studentDocs: studentDocs,
          ),
    );
  }
}

class FeeSummaryFormContent extends StatefulWidget {
  final BuildContext ctx;
  final QueryDocumentSnapshot? doc;
  final String code;
  final bool isEdit;
  final Map<String, dynamic> data;
  final TextEditingController nameCtl;
  final TextEditingController classCtl;
  final TextEditingController termRequiredCtl;
  final TextEditingController termPaidCtl;
  final TextEditingController termBalanceCtl;
  final TextEditingController totalRequiredCtl;
  final TextEditingController totalPaidCtl;
  final TextEditingController totalBalanceCtl;
  final List<QueryDocumentSnapshot> studentDocs;

  const FeeSummaryFormContent({
    Key? key,
    required this.ctx,
    required this.doc,
    required this.code,
    required this.isEdit,
    required this.data,
    required this.nameCtl,
    required this.classCtl,
    required this.termRequiredCtl,
    required this.termPaidCtl,
    required this.termBalanceCtl,
    required this.totalRequiredCtl,
    required this.totalPaidCtl,
    required this.totalBalanceCtl,
    required this.studentDocs,
  }) : super(key: key);

  @override
  FeeSummaryFormContentState createState() => FeeSummaryFormContentState();
}

class FeeSummaryFormContentState extends State<FeeSummaryFormContent> {
  String? selectedAdmissionNo;

  @override
  void initState() {
    super.initState();
    selectedAdmissionNo =
        widget.isEdit ? widget.data['admissionNo'] as String? : null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(widget.ctx).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.isEdit ? 'Edit Fee Summary' : 'Add Fee Summary',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFFB45309),
              ),
            ),
            const SizedBox(height: 16),
            // Student dropdown
            Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonFormField<String>(
                value: selectedAdmissionNo,
                hint: Text(
                  'Select Student',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                decoration: const InputDecoration(
                  labelText: 'Student (Adm#)',
                  labelStyle: TextStyle(color: Color(0xFF92400E)),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  filled: true,
                  fillColor: Color(0xFFFFF7ED),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: Color(0xFFB45309), width: 2),
                  ),
                ),
                items:
                    widget.studentDocs.map((s) {
                      final sd = s.data() as Map<String, dynamic>;
                      final adm = sd['admissionNo'] as String;
                      return DropdownMenuItem<String>(
                        value: adm,
                        child: Text('$adm – ${sd['name']}'),
                      );
                    }).toList(),
                onChanged: (newAdm) {
                  setState(() => selectedAdmissionNo = newAdm);
                  // Auto-fill name and class when student is selected
                  if (newAdm != null) {
                    final student = widget.studentDocs.firstWhere(
                      (s) =>
                          (s.data() as Map<String, dynamic>)['admissionNo'] ==
                          newAdm,
                    );
                    final studentData = student.data() as Map<String, dynamic>;
                    widget.nameCtl.text = studentData['name'] ?? '';
                    widget.classCtl.text = studentData['class'] ?? '';
                  }
                },
                dropdownColor: Colors.white,
              ),
            ),
            ModernField(controller: widget.nameCtl, label: 'Name'),
            ModernField(controller: widget.classCtl, label: 'Class'),

            // Term Section
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Term Fees',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ModernField(
                          controller: widget.termRequiredCtl,
                          label: 'Term Required',
                          keyboard: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ModernField(
                          controller: widget.termPaidCtl,
                          label: 'Term Paid',
                          keyboard: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ModernField(
                    controller: widget.termBalanceCtl,
                    label: 'Term Balance',
                    keyboard: TextInputType.number,
                  ),
                ],
              ),
            ),

            // Total Section
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFB45309).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFB45309).withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Summary',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFB45309),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ModernField(
                          controller: widget.totalRequiredCtl,
                          label: 'Total Required',
                          keyboard: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ModernField(
                          controller: widget.totalPaidCtl,
                          label: 'Total Paid',
                          keyboard: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ModernField(
                    controller: widget.totalBalanceCtl,
                    label: 'Total Balance',
                    keyboard: TextInputType.number,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Submit button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor:
                      selectedAdmissionNo == null
                          ? Colors.grey[400]
                          : const Color(0xFFB45309),
                  shape: const StadiumBorder(),
                  minimumSize: const Size(0, 50),
                ),
                onPressed:
                    selectedAdmissionNo == null
                        ? null
                        : () async {
                          // Find student ID
                          final student = widget.studentDocs.firstWhere(
                            (s) =>
                                (s.data()
                                    as Map<String, dynamic>)['admissionNo'] ==
                                selectedAdmissionNo,
                          );

                          final feeSummaryData = {
                            'admissionNo': selectedAdmissionNo!,
                            'studentId': student.id,
                            'name': widget.nameCtl.text.trim(),
                            'class': widget.classCtl.text.trim(),
                            'termRequired':
                                double.tryParse(widget.termRequiredCtl.text) ??
                                0,
                            'termPaid':
                                double.tryParse(widget.termPaidCtl.text) ?? 0,
                            'termBalance':
                                double.tryParse(widget.termBalanceCtl.text) ??
                                0,
                            'totalRequired':
                                double.tryParse(widget.totalRequiredCtl.text) ??
                                0,
                            'totalPaid':
                                double.tryParse(widget.totalPaidCtl.text) ?? 0,
                            'totalBalance':
                                double.tryParse(widget.totalBalanceCtl.text) ??
                                0,
                            'type': 'fee summary',
                          };

                          if (widget.isEdit) {
                            // Update existing fee summary
                            await widget.doc!.reference.update({
                              ...feeSummaryData,
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                          } else {
                            // Check if fee summary already exists for this student
                            final existingFeeSummary =
                                await FirebaseFirestore.instance
                                    .collection('schools')
                                    .doc(widget.code)
                                    .collection('payments')
                                    .where(
                                      'admissionNo',
                                      isEqualTo: selectedAdmissionNo,
                                    )
                                    .where('type', isEqualTo: 'fee summary')
                                    .get();

                            if (existingFeeSummary.docs.isNotEmpty) {
                              // Update existing
                              await existingFeeSummary.docs.first.reference
                                  .update({
                                    ...feeSummaryData,
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  });
                            } else {
                              // Create new with unique doc ID
                              String baseDocId =
                                  '$selectedAdmissionNo-fee summary';
                              String docId = await getUniqueDocId(
                                widget.code,
                                'payments',
                                baseDocId,
                              );

                              await FirebaseFirestore.instance
                                  .collection('schools')
                                  .doc(widget.code)
                                  .collection('payments')
                                  .doc(docId)
                                  .set({
                                    ...feeSummaryData,
                                    'createdAt': FieldValue.serverTimestamp(),
                                  });
                            }
                          }
                          Navigator.pop(widget.ctx);
                        },
                child: Text(
                  widget.isEdit ? 'Save Fee Summary' : 'Add Fee Summary',
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ───────── STUDENTS ─────────
class _StudentsView extends StatelessWidget {
  final String schoolCode;
  const _StudentsView({required this.schoolCode});
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFFFFF7ED), // Orange 50 background
      child: EditableList(
        title: 'Students',
        collection: FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolCode)
            .collection('students'),
        itemBuilder: (ctx, doc) {
          final d = doc.data()! as Map<String, dynamic>;
          return Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              title: Text(
                d['name'],
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF92400E), // Amber 800
                ),
              ),
              subtitle: Text(
                'Adm#: ${d['admissionNo']} • Class: ${d['class'] ?? 'N/A'} • Age: ${d['age']}',
              ),
              trailing: Icon(Icons.edit, color: Color(0xFFB45309)), // Amber 700
              onTap: () => _showStudentForm(ctx, doc, schoolCode),
            ),
          );
        },
        onAdd: () => _showStudentForm(context, null, schoolCode),
      ),
    );
  }

  void _showStudentForm(
    BuildContext ctx,
    QueryDocumentSnapshot? doc,
    String code,
  ) {
    final isEdit = doc != null;
    final d =
        isEdit ? doc.data()! as Map<String, dynamic> : <String, dynamic>{};
    final name = TextEditingController(text: d['name']);
    final adm = TextEditingController(text: d['admissionNo']);
    final studentClass = TextEditingController(text: d['class']);
    final age = TextEditingController(text: d['age']?.toString());
    final city = TextEditingController(text: d['city']);
    final phone = TextEditingController(text: d['parentPhone']);
    final home = TextEditingController(text: d['homeAddress']);

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (_) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isEdit ? 'Edit Student' : 'Add Student',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB45309), // Amber 700
                  ),
                ),
                SizedBox(height: 16),
                ModernField(controller: name, label: 'Full Name'),
                ModernField(controller: adm, label: 'Admission No'),
                ModernField(controller: studentClass, label: 'Class'),
                ModernField(
                  controller: age,
                  label: 'Age',
                  keyboard: TextInputType.number,
                ),
                ModernField(controller: city, label: 'City'),
                ModernField(
                  controller: phone,
                  label: 'Parent Phone',
                  keyboard: TextInputType.phone,
                ),
                ModernField(controller: home, label: 'Home Address'),
                SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Color(0xFFB45309),
                    shape: StadiumBorder(),
                    minimumSize: Size(double.infinity, 50),
                  ),
                  child: Text(isEdit ? 'Save' : 'Add'),
                  onPressed: () async {
                    final col = FirebaseFirestore.instance
                        .collection('schools')
                        .doc(code)
                        .collection('students');
                    final payload = {
                      'name': name.text.trim(),
                      'admissionNo': adm.text.trim(),
                      'class': studentClass.text.trim(),
                      'age': int.tryParse(age.text) ?? 0,
                      'city': city.text.trim(),
                      'parentPhone': phone.text.trim(),
                      'homeAddress': home.text.trim(),
                      'createdAt': FieldValue.serverTimestamp(),
                    };
                    if (isEdit) {
                      await doc.reference.update(payload);
                    } else {
                      await col.add(payload);
                    }
                    Navigator.pop(ctx);
                  },
                ),
                SizedBox(height: 16),
              ],
            ),
          ),
    );
  }
}

// ───────── PARENTS ─────────
class _ParentsView extends StatelessWidget {
  final String schoolCode;
  const _ParentsView({required this.schoolCode});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFFFFF7ED), // Orange 50 background
      child: EditableList(
        title: 'Parents',
        collection: FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolCode)
            .collection('parents'),
        itemBuilder: (ctx, doc) {
          final d = doc.data()! as Map<String, dynamic>;
          return Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              title: Text(
                d['name'] as String,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF92400E), // Amber 800
                ),
              ),
              subtitle: Text(
                'Email: ${d['email']} • City: ${d['city']}\nAdmission No: ${d['admissionNo'] ?? 'N/A'}',
              ),
              trailing: Icon(Icons.edit, color: Color(0xFFB45309)), // Amber 700
              onTap: () => _showParentForm(ctx, doc, schoolCode),
            ),
          );
        },
        onAdd: () => _showParentForm(context, null, schoolCode),
      ),
    );
  }

  void _showParentForm(
    BuildContext ctx,
    QueryDocumentSnapshot? doc,
    String code,
  ) async {
    final isEdit = doc != null;
    final data =
        isEdit ? doc.data()! as Map<String, dynamic> : <String, dynamic>{};

    // text controllers
    final nameCtl = TextEditingController(text: data['name'] as String?);
    final emailCtl = TextEditingController(text: data['email'] as String?);
    final cityCtl = TextEditingController(text: data['city'] as String?);
    final phoneCtl = TextEditingController(text: data['phone'] as String?);
    final passCtl = TextEditingController(text: data['password'] as String?);

    // fetch students for dropdown
    final studentSnap =
        await FirebaseFirestore.instance
            .collection('schools')
            .doc(code)
            .collection('students')
            .orderBy('admissionNo')
            .get();
    final studentDocs = studentSnap.docs;

    // If no students exist, show error
    if (studentDocs.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text('No students found. Please add students first.'),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (_) => _ParentFormContent(
            ctx: ctx,
            doc: doc,
            code: code,
            isEdit: isEdit,
            data: data,
            nameCtl: nameCtl,
            emailCtl: emailCtl,
            cityCtl: cityCtl,
            phoneCtl: phoneCtl,
            passCtl: passCtl,
            studentDocs: studentDocs,
          ),
    );
  }
}

class _ParentFormContent extends StatefulWidget {
  final BuildContext ctx;
  final QueryDocumentSnapshot? doc;
  final String code;
  final bool isEdit;
  final Map<String, dynamic> data;
  final TextEditingController nameCtl;
  final TextEditingController emailCtl;
  final TextEditingController cityCtl;
  final TextEditingController phoneCtl;
  final TextEditingController passCtl;
  final List<QueryDocumentSnapshot> studentDocs;

  const _ParentFormContent({
    required this.ctx,
    required this.doc,
    required this.code,
    required this.isEdit,
    required this.data,
    required this.nameCtl,
    required this.emailCtl,
    required this.cityCtl,
    required this.phoneCtl,
    required this.passCtl,
    required this.studentDocs,
  });

  @override
  _ParentFormContentState createState() => _ParentFormContentState();
}

class _ParentFormContentState extends State<_ParentFormContent> {
  String? selectedStudentId; // Only for UI selection
  String? selectedAdmissionNo;

  @override
  void initState() {
    super.initState();
    if (widget.isEdit) {
      selectedAdmissionNo = widget.data['admissionNo'] as String?;
      // Find the student ID for UI selection based on admission number
      if (selectedAdmissionNo != null) {
        final student =
            widget.studentDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['admissionNo'] == selectedAdmissionNo;
            }).firstOrNull;
        selectedStudentId = student?.id;
      }
    }
  }

  void _onStudentChanged(String? studentId) {
    if (studentId != null) {
      // Find the selected student document
      final selectedStudent = widget.studentDocs.firstWhere(
        (doc) => doc.id == studentId,
      );
      final studentData = selectedStudent.data() as Map<String, dynamic>;

      setState(() {
        selectedStudentId = studentId;
        selectedAdmissionNo = studentData['admissionNo'] as String?;
      });
    } else {
      setState(() {
        selectedStudentId = null;
        selectedAdmissionNo = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(widget.ctx).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.isEdit ? 'Edit Parent' : 'Add Parent',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFFB45309), // Amber 700
              ),
            ),
            SizedBox(height: 16),

            ModernField(controller: widget.nameCtl, label: 'Full Name'),
            ModernField(
              controller: widget.emailCtl,
              label: 'Email',
              keyboard: TextInputType.emailAddress,
            ),
            ModernField(controller: widget.cityCtl, label: 'City'),
            ModernField(
              controller: widget.phoneCtl,
              label: 'Phone',
              keyboard: TextInputType.phone,
            ),

            // Password field
            Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: TextField(
                controller: widget.passCtl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: Color(0xFF92400E)),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  filled: true,
                  fillColor: Color(0xFFFFF7ED),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Color(0xFFB45309), width: 2),
                  ),
                ),
              ),
            ),

            // Student dropdown
            Container(
              margin: EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonFormField<String>(
                value: selectedStudentId,
                hint: Text(
                  'Select Student',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                decoration: InputDecoration(
                  labelText: 'Linked Student',
                  labelStyle: TextStyle(color: Color(0xFF92400E)),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  filled: true,
                  fillColor: Color(0xFFFFF7ED),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Color(0xFFB45309), width: 2),
                  ),
                ),
                items:
                    widget.studentDocs.map((s) {
                      final sd = s.data() as Map<String, dynamic>;
                      return DropdownMenuItem<String>(
                        value: s.id,
                        child: Text('${sd['admissionNo']} - ${sd['name']}'),
                      );
                    }).toList(),
                onChanged: _onStudentChanged,
                dropdownColor: Colors.white,
              ),
            ),

            // Display selected admission number
            if (selectedAdmissionNo != null)
              Container(
                margin: EdgeInsets.symmetric(vertical: 8),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFFFEF3C7), // Light amber background
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xFFB45309).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Color(0xFFB45309),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Selected Admission No: $selectedAdmissionNo',
                        style: TextStyle(
                          color: Color(0xFF92400E),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            SizedBox(height: 24),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor:
                      selectedStudentId == null
                          ? Colors.grey[400]
                          : Color(0xFFB45309),
                  shape: StadiumBorder(),
                  minimumSize: Size(0, 50),
                ),
                onPressed:
                    selectedStudentId == null
                        ? null
                        : () async {
                          final col = FirebaseFirestore.instance
                              .collection('schools')
                              .doc(widget.code)
                              .collection('parents');

                          final payload = {
                            'name': widget.nameCtl.text.trim(),
                            'email': widget.emailCtl.text.trim(),
                            'city': widget.cityCtl.text.trim(),
                            'phone': widget.phoneCtl.text.trim(),
                            'admissionNo': selectedAdmissionNo!,
                            'password':
                                widget.passCtl.text.isNotEmpty
                                    ? widget.passCtl.text.trim()
                                    : (widget.data['password'] ?? ''),
                            'createdAt': FieldValue.serverTimestamp(),
                          };

                          if (widget.isEdit) {
                            await widget.doc!.reference.update(payload);
                          } else {
                            // Check existing parents for this admission number
                            final existingParents =
                                await col
                                    .where(
                                      'admissionNo',
                                      isEqualTo: selectedAdmissionNo!,
                                    )
                                    .get();

                            // Check if already 2 parents exist
                            if (existingParents.docs.length >= 2) {
                              ScaffoldMessenger.of(widget.ctx).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Maximum 2 parents allowed per student. This student already has 2 registered parents.',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            // Determine parent index (1 or 2)
                            int parentIndex = existingParents.docs.length + 1;

                            // Create document ID in format "admissionNo(parentIndex)"
                            final docId =
                                '${selectedAdmissionNo!}($parentIndex)';

                            // Add parentIndex to payload
                            payload['parentIndex'] = parentIndex;

                            // Use the formatted document ID
                            await col.doc(docId).set(payload);
                          }
                          Navigator.pop(widget.ctx);
                        },
                child: Text(
                  selectedStudentId == null
                      ? 'Select Student First'
                      : (widget.isEdit ? 'Save Parent' : 'Add Parent'),
                ),
              ),
            ),

            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ───────── REPORTS ─────────
class _ReportsView extends StatelessWidget {
  final String schoolCode;
  const _ReportsView({required this.schoolCode});
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFFFFF7ED), // Orange 50 background
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Reports',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB45309), // Amber 700
                  ),
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.add),
                  label: Text('Generate'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Color(0xFFB45309),
                    shape: StadiumBorder(),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onPressed: () => _genReport(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('schools')
                      .doc(schoolCode)
                      .collection('reports')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFB45309),
                      ), // Amber 700
                    ),
                  );
                }
                final docs = snap.data!.docs;
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (c, i) {
                    final d = docs[i].data()! as Map<String, dynamic>;
                    final date = (d['createdAt'] as Timestamp).toDate();
                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      child: ListTile(
                        title: Text(
                          'Report ${DateFormat('dd/MM/yyyy').format(date)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF92400E), // Amber 800
                          ),
                        ),
                        subtitle: Text(
                          'Students: ${d['totalStudents']}  •  Fees: KES ${(d['totalFees'] as num).toStringAsFixed(2)}',
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_vert,
                            color: Color(0xFFB45309),
                          ), // Amber 700
                          onSelected:
                              (v) => _exportReport(
                                schoolCode,
                                docs[i].reference.id,
                                v,
                              ),
                          itemBuilder:
                              (c) => [
                                PopupMenuItem(
                                  value: 'CSV',
                                  child: Text('Export CSV'),
                                ),
                                PopupMenuItem(
                                  value: 'PDF',
                                  child: Text('Export PDF'),
                                ),
                                PopupMenuItem(
                                  value: 'DEL',
                                  child: Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _genReport(BuildContext ctx) async {
    final school = FirebaseFirestore.instance
        .collection('schools')
        .doc(schoolCode);
    final studs = await school.collection('students').get();
    final pays = await school.collection('payments').get();
    final totalStud = studs.docs.length;
    final totalFees = pays.docs.fold<double>(
      0,
      (s, d) => s + (d.data()['amount'] as num).toDouble(),
    );
    await school.collection('reports').add({
      'createdAt': FieldValue.serverTimestamp(),
      'totalStudents': totalStud,
      'totalFees': totalFees,
    });
  }

  Future<void> _exportReport(String code, String id, String fmt) async {
    final ref = FirebaseFirestore.instance
        .collection('schools')
        .doc(code)
        .collection('reports')
        .doc(id);
    final snap = await ref.get();
    final d = snap.data()!;
    final date = (d['createdAt'] as Timestamp).toDate();
    final rows = [
      ['Field', 'Value'],
      ['Date', DateFormat('dd MMM yyyy').format(date)],
      ['Students', d['totalStudents']],
      ['TotalFees', d['totalFees']],
    ];
    final dir = await getApplicationDocumentsDirectory();
    if (fmt == 'CSV') {
      final csv = ListToCsvConverter().convert(rows);
      final file = File('${dir.path}/report_$id.csv');
      await file.writeAsString(csv);
      OpenFilex.open(file.path);
    } else if (fmt == 'PDF') {
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(build: (c) => pw.Table.fromTextArray(context: c, data: rows)),
      );
      final file = File('${dir.path}/report_$id.pdf');
      await file.writeAsBytes(await pdf.save());
      OpenFilex.open(file.path);
    } else if (fmt == 'DEL') {
      await ref.delete();
    }
  }
}

/// ───────── SETTINGS ─────────
class _SettingsView extends StatefulWidget {
  final String schoolCode;
  final String adminDocId;
  const _SettingsView({required this.schoolCode, required this.adminDocId});
  @override
  _SettingsViewState createState() => _SettingsViewState();
}

class _SettingsViewState extends State<_SettingsView> {
  final _nameCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _passCtl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snap =
          await FirebaseFirestore.instance
              .collection('schools')
              .doc(widget.schoolCode)
              .collection('admins')
              .doc(widget.adminDocId)
              .get();

      final d = snap.data() ?? <String, dynamic>{};

      // Default to empty string if null
      _nameCtl.text = (d['name'] as String?) ?? '';
      _emailCtl.text = (d['email'] as String?) ?? '';
    } catch (e) {
      // Optionally show an error or leave fields blank
      print('Error loading admin profile: $e');
    }
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      final updateData = <String, dynamic>{
        'name': _nameCtl.text.trim(),
        'email': _emailCtl.text.trim(),
      };
      if (_passCtl.text.isNotEmpty) {
        updateData['password'] = _passCtl.text.trim();
      }

      await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolCode)
          .collection('admins')
          .doc(widget.adminDocId)
          .update(updateData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved successfully'),
          backgroundColor: Color(0xFFB45309), // Amber 700
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _emailCtl.dispose();
    _passCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFFFFF7ED), // Orange 50 background
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin Profile',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFB45309), // Amber 700
                      ),
                    ),
                    SizedBox(height: 16),
                    ModernField(controller: _nameCtl, label: 'Name'),
                    ModernField(
                      controller: _emailCtl,
                      label: 'Email',
                      keyboard: TextInputType.emailAddress,
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: TextField(
                        controller: _passCtl,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          labelStyle: TextStyle(
                            color: Color(0xFF92400E),
                          ), // Amber 800
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          filled: true,
                          fillColor: Color(0xFFFFF7ED), // Orange 50
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Color(0xFFB45309),
                              width: 2,
                            ), // Amber 700
                          ),
                          hintText: 'Leave blank to keep current password',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Color(0xFFB45309),
                          shape: StadiumBorder(),
                        ),
                        onPressed: _loading ? null : _save,
                        child:
                            _loading
                                ? CircularProgressIndicator(color: Colors.white)
                                : Text('Save Changes'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────── GENERIC EDITABLE LIST ─────────
class EditableList extends StatelessWidget {
  final String title;
  final CollectionReference collection;
  final Widget Function(BuildContext, QueryDocumentSnapshot) itemBuilder;
  final VoidCallback onAdd;
  const EditableList({
    required this.title,
    required this.collection,
    required this.itemBuilder,
    required this.onAdd,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream:
                collection.orderBy('createdAt', descending: true).snapshots(),
            builder: (c, s) {
              if (!s.hasData) {
                return Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFB45309),
                    ), // Amber 700
                  ),
                );
              }
              final docs = s.data!.docs;
              return ListView.separated(
                padding: EdgeInsets.only(top: 8, bottom: 80),
                itemBuilder: (c, i) => itemBuilder(c, docs[i]),
                separatorBuilder: (a, b) => SizedBox(height: 4),
                itemCount: docs.length,
              );
            },
          ),
        ),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            icon: Icon(Icons.add),
            label: Text('Add $title'),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Color(0xFFB45309),
              shape: StadiumBorder(),
              minimumSize: Size(double.infinity, 50),
            ),
            onPressed: onAdd,
          ),
        ),
      ],
    );
  }
}

// ───────── MODERN FIELD ─────────
class ModernField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType keyboard;
  const ModernField({
    required this.controller,
    required this.label,
    this.keyboard = TextInputType.text,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Color(0xFF92400E)), // Amber 800
          floatingLabelBehavior: FloatingLabelBehavior.always,
          filled: true,
          fillColor: Color(0xFFFFF7ED), // Orange 50
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Color(0xFFB45309),
              width: 2,
            ), // Amber 700
          ),
        ),
      ),
    );
  }
}

// ───────── UTILITY FUNCTIONS ─────────
Future<String> getUniqueDocId(
  String schoolCode,
  String collection,
  String baseId,
) async {
  String docId = baseId;
  int counter = 1;

  while (true) {
    final doc =
        await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolCode)
            .collection(collection)
            .doc(docId)
            .get();

    if (!doc.exists) {
      return docId;
    }

    docId = '$baseId($counter)';
    counter++;
  }
}

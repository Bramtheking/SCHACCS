// lib/screens/admin_dashboard.dart
// ignore_for_file: unnecessary_cast

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:schaccs/screens/login_screen.dart';

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
  final _tabs = ['Home','Students','Parents','Payments','Reports','Settings'];

  Future<bool> _onWillPop() async {
    if (_tab != 0) { setState(() => _tab = 0); return false; }
    return true;
  }
  void _logout() {
    Navigator.of(context)
      .pushNamedAndRemoveUntil('/login', (_) => false, arguments: widget.schoolCode);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
          Navigator.of(context).pushNamedAndRemoveUntil(
            LoginScreen.routeName,            // '/login'
            (Route<dynamic> route) => false,  // clear the entire stack
            arguments: widget.schoolCode,     // pass the schoolCode along
          );
        },
          ),
          title: Text(_tabs[_tab], style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Color(0xFFB45309), // Amber 700
          elevation: 4,
          actions: [ IconButton(icon: Icon(Icons.logout), onPressed: _logout) ],
        ),
        body: IndexedStack(
          index: _tab,
          children: [
            _HomeView(schoolCode: widget.schoolCode),
            _StudentsView(schoolCode: widget.schoolCode),
            _ParentsView(schoolCode: widget.schoolCode),
            _PaymentsView(schoolCode: widget.schoolCode),
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
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Students'),
            BottomNavigationBarItem(icon: Icon(Icons.family_restroom), label: 'Parents'),
            BottomNavigationBarItem(icon: Icon(Icons.payment), label: 'Payments'),
            BottomNavigationBarItem(icon: Icon(Icons.insert_chart), label: 'Reports'),
            BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Overview',
            style: theme.textTheme.headlineSmall
              ?.copyWith(color: Color(0xFFB45309), fontWeight: FontWeight.bold)
          ),
          SizedBox(height: 16),
          _StatsGrid(schoolCode: schoolCode),
        ]),
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
      crossAxisCount: 2, shrinkWrap: true,
      mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 2.2,
      children: [
        _StatCard(
          icon: Icons.people,
          label: 'Students',
          stream: FirebaseFirestore.instance
            .collection('schools').doc(schoolCode)
            .collection('students').snapshots()
            .map((s) => s.docs.length.toString()),
        ),
        _StatCard(
          icon: Icons.family_restroom,
          label: 'Parents',
          stream: FirebaseFirestore.instance
            .collection('schools').doc(schoolCode)
            .collection('parents').snapshots()
            .map((s) => s.docs.length.toString()),
        ),
        _StatCard(
          icon: Icons.attach_money,
          label: 'Collected',
          stream: FirebaseFirestore.instance
            .collection('schools').doc(schoolCode)
            .collection('payments').snapshots()
            .map((s) {
              final total = s.docs.fold<double>(
                0, (sum, d) => sum + (d.data()['amount'] as num).toDouble());
              return 'KES ${total.toStringAsFixed(2)}';
            }),
        ),
        _StatCard(
          icon: Icons.warning,
          label: 'With Balance',
          stream: FirebaseFirestore.instance
            .collection('schools').doc(schoolCode)
            .collection('students').snapshots()
            .asyncMap((snap) async {
              int count = 0;
              for (var doc in snap.docs) {
                final d = doc.data();
                final paidSnap = await FirebaseFirestore.instance
                  .collection('schools').doc(schoolCode)
                  .collection('payments')
                  .where('studentId', isEqualTo: doc.id).get();
                final paid = paidSnap.docs.fold<double>(
                  0, (sum, d) => sum + (d.data()['amount'] as num).toDouble());
                final expected = (d['expectedFee'] ?? 0) as num;
                if (paid < expected) count++;
              }
              return count.toString();
            }),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Stream<String> stream;
  const _StatCard({
    required this.icon, required this.label, required this.stream,
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
            return Row(children: [
              Container(
 padding: EdgeInsets.all(8),
 decoration: BoxDecoration(
 color: Color(0xFFFBBF24).withOpacity(0.2), // Amber 400 with opacity
 borderRadius: BorderRadius.circular(8),
 ),
 child: Icon(icon, size: 28, color: Color(0xFFB45309)), // Amber 700
 ),
 SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(label, style: theme.textTheme.bodyMedium?.copyWith(
 color: Colors.brown[700]
 )),
 Text(snap.data ?? '…',
 style: theme.textTheme.headlineSmall
 ?.copyWith(fontWeight: FontWeight.bold, color: Color(0xFF92400E))), // Amber 800
 ],
 )
              )
            ]);
          },
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
      child: _EditableList(
        title: 'Students',
        collection: FirebaseFirestore.instance
          .collection('schools').doc(schoolCode)
          .collection('students'),
        itemBuilder: (ctx, doc) {
          final d = doc.data()! as Map<String, dynamic>;
          return Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: ListTile(
              title: Text(d['name'], style: TextStyle(
                fontWeight: FontWeight.w500, 
                color: Color(0xFF92400E), // Amber 800
              )),
              subtitle: Text('Adm#: ${d['admissionNo']} • Age: ${d['age']}'),
              trailing: Icon(Icons.edit, color: Color(0xFFB45309)), // Amber 700
              onTap: () => _showStudentForm(ctx, doc, schoolCode),
            ),
          );
        },
        onAdd: () => _showStudentForm(context, null, schoolCode),
      ),
    );
  }

  void _showStudentForm(BuildContext ctx, QueryDocumentSnapshot? doc, String code) {
    final isEdit = doc != null;
    final d = isEdit ? doc.data()! as Map<String, dynamic> : <String,dynamic>{};
    final name  = TextEditingController(text: d['name']);
    final adm   = TextEditingController(text: d['admissionNo']);
    final age   = TextEditingController(text: d['age']?.toString());
    final city  = TextEditingController(text: d['city']);
    final phone = TextEditingController(text: d['parentPhone']);
    final home  = TextEditingController(text: d['homeAddress']);
    final fee   = TextEditingController(text: d['expectedFee']?.toString());

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left:16, right:16, top:24
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(isEdit ? 'Edit Student' : 'Add Student',
            style: TextStyle(
              fontSize: 20, 
              fontWeight: FontWeight.bold,
              color: Color(0xFFB45309), // Amber 700
            )),
          SizedBox(height:16),
          _ModernField(controller: name,  label: 'Full Name'),
          _ModernField(controller: adm,   label: 'Admission No'),
          _ModernField(controller: age,   label: 'Age', keyboard: TextInputType.number),
          _ModernField(controller: city,  label: 'City'),
          _ModernField(controller: phone, label: 'Parent Phone', keyboard: TextInputType.phone),
          _ModernField(controller: home,  label: 'Home Address'),
          _ModernField(controller: fee,   label: 'Expected Fee', keyboard: TextInputType.number),
          SizedBox(height:24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white, backgroundColor: Color(0xFFB45309),
              shape: StadiumBorder(), 
              minimumSize: Size(double.infinity,50)),
            child: Text(isEdit ? 'Save' : 'Add'),
            onPressed: () async {
              final col = FirebaseFirestore.instance
                .collection('schools').doc(code)
                .collection('students');
              final payload = {
                'name': name.text.trim(),
                'admissionNo': adm.text.trim(),
                'age': int.tryParse(age.text) ?? 0,
                'city': city.text.trim(),
                'parentPhone': phone.text.trim(),
                'homeAddress': home.text.trim(),
                'expectedFee': double.tryParse(fee.text) ?? 0,
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
          SizedBox(height:16),
        ]),
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
      child: _EditableList(
        title: 'Parents',
        collection: FirebaseFirestore.instance
          .collection('schools').doc(schoolCode)
          .collection('parents'),
        itemBuilder: (ctx, doc) {
          final d = doc.data()! as Map<String, dynamic>;
          return Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: ListTile(
              title: Text(d['name'] as String, style: TextStyle(
                fontWeight: FontWeight.w500, 
                color: Color(0xFF92400E), // Amber 800
              )),
              subtitle: Text('Email: ${d['email']} • City: ${d['city']}'),
              trailing: Icon(Icons.edit, color: Color(0xFFB45309)), // Amber 700
              onTap: () => _showParentForm(ctx, doc, schoolCode),
            ),
          );
        },
        onAdd: () => _showParentForm(context, null, schoolCode),
      ),
    );
  }

  void _showParentForm(BuildContext ctx, QueryDocumentSnapshot? doc, String code) async {
    final isEdit = doc != null;
    final data = isEdit ? doc.data()! as Map<String, dynamic> : <String, dynamic>{};

    // text controllers
    final nameCtl = TextEditingController(text: data['name'] as String?);
    final emailCtl = TextEditingController(text: data['email'] as String?);
    final cityCtl = TextEditingController(text: data['city'] as String?);
    final phoneCtl = TextEditingController(text: data['phone'] as String?);
    final passCtl = TextEditingController(text: data['password'] as String?);

    // fetch students for dropdown
    final studentSnap = await FirebaseFirestore.instance
      .collection('schools').doc(code)
      .collection('students')
      .orderBy('admissionNo')
      .get();
    final studentDocs = studentSnap.docs;

    // If no students exist, show error
    if (studentDocs.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('No students found. Please add students first.'))
      );
      return;
    }

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))
      ),
      builder: (_) => _ParentFormContent(
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
  String? selectedStudentId;

  @override
  void initState() {
    super.initState();
    selectedStudentId = widget.isEdit ? widget.data['studentId'] as String? : null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(widget.ctx).viewInsets.bottom,
        left: 16, right: 16, top: 24
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            widget.isEdit ? 'Edit Parent' : 'Add Parent',
            style: TextStyle(
              fontSize: 20, 
              fontWeight: FontWeight.bold,
              color: Color(0xFFB45309), // Amber 700
            )
          ),
          SizedBox(height: 16),

          _ModernField(controller: widget.nameCtl, label: 'Full Name'),
          _ModernField(controller: widget.emailCtl, label: 'Email', keyboard: TextInputType.emailAddress),
          _ModernField(controller: widget.cityCtl, label: 'City'),
          _ModernField(controller: widget.phoneCtl, label: 'Phone', keyboard: TextInputType.phone),

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
              hint: Text('Select Student', style: TextStyle(color: Colors.grey[600])),
              decoration: InputDecoration(
                labelText: 'Linked Student',
                labelStyle: TextStyle(color: Color(0xFF92400E)),
                floatingLabelBehavior: FloatingLabelBehavior.always,
                filled: true,
                fillColor: Color(0xFFFFF7ED),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFFB45309), width: 2),
                ),
              ),
              items: widget.studentDocs.map((s) {
                final sd = s.data() as Map<String, dynamic>;
                return DropdownMenuItem<String>(
                  value: s.id,
                  child: Text('${sd['admissionNo']} - ${sd['name']}'),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  selectedStudentId = newValue;
                });
              },
              dropdownColor: Colors.white,
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
                backgroundColor: selectedStudentId == null 
                    ? Colors.grey[400] 
                    : Color(0xFFB45309),
                shape: StadiumBorder(),
                minimumSize: Size(0, 50),
              ),
              onPressed: selectedStudentId == null ? null : () async {
                final col = FirebaseFirestore.instance
                  .collection('schools').doc(widget.code)
                  .collection('parents');
                final payload = {
                  'name': widget.nameCtl.text.trim(),
                  'email': widget.emailCtl.text.trim(),
                  'city': widget.cityCtl.text.trim(),
                  'phone': widget.phoneCtl.text.trim(),
                  'studentId': selectedStudentId!,
                  'password': widget.passCtl.text.isNotEmpty
                                 ? widget.passCtl.text.trim()
                                 : (widget.data['password'] ?? ''),
                  'createdAt': FieldValue.serverTimestamp(),
                };
                if (widget.isEdit) {
                  await widget.doc!.reference.update(payload);
                } else {
                  await col.add(payload);
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
        ]),
      ),
    );
  }
}

/// ───────── PAYMENTS ─────────
class _PaymentsView extends StatelessWidget {
  final String schoolCode;
  const _PaymentsView({required this.schoolCode});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFFFFF7ED),
      child: _EditableList(
        title: 'Payments',
        collection: FirebaseFirestore.instance
          .collection('schools').doc(schoolCode)
          .collection('payments'),
        itemBuilder: (ctx, doc) {
          final d = doc.data()! as Map<String, dynamic>;
          return Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: ListTile(
              title: Text(
                'KES ${(d['amount'] as num).toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF92400E),
                ),
              ),
              subtitle: Text(
                '${d['mode']} • ${DateFormat('dd MMM yyyy').format((d['date'] as Timestamp).toDate())} • Adm#: ${d['admissionNo']}'
              ),
              trailing: Icon(Icons.edit, color: Color(0xFFB45309)),
              onTap: () => _showPaymentForm(ctx, doc, schoolCode),
            ),
          );
        },
        onAdd: () => _showPaymentForm(context, null, schoolCode),
      ),
    );
  }

  void _showPaymentForm(BuildContext ctx, QueryDocumentSnapshot? doc, String code) async {
    final isEdit = doc != null;
    final data = isEdit ? doc.data()! as Map<String, dynamic> : <String, dynamic>{};
    final amountCtl = TextEditingController(text: data['amount']?.toString());
    final modeCtl   = TextEditingController(text: data['mode'] as String?);
    DateTime date = data['date'] != null
      ? (data['date'] as Timestamp).toDate()
      : DateTime.now();

    final studentSnap = await FirebaseFirestore.instance
      .collection('schools').doc(code)
      .collection('students')
      .orderBy('admissionNo')
      .get();
    final studentDocs = studentSnap.docs;

    if (studentDocs.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('No students found. Please add students first.'))
      );
      return;
    }

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))
      ),
      builder: (_) => _PaymentFormContent(
        ctx: ctx,
        doc: doc,
        code: code,
        isEdit: isEdit,
        data: data,
        amountCtl: amountCtl,
        modeCtl: modeCtl,
        date: date,
        studentDocs: studentDocs,
      ),
    );
  }
}

class _PaymentFormContent extends StatefulWidget {
  final BuildContext ctx;
  final QueryDocumentSnapshot? doc;
  final String code;
  final bool isEdit;
  final Map<String, dynamic> data;
  final TextEditingController amountCtl;
  final TextEditingController modeCtl;
  final DateTime date;
  final List<QueryDocumentSnapshot> studentDocs;

  const _PaymentFormContent({
    required this.ctx,
    required this.doc,
    required this.code,
    required this.isEdit,
    required this.data,
    required this.amountCtl,
    required this.modeCtl,
    required this.date,
    required this.studentDocs,
  });

  @override
  _PaymentFormContentState createState() => _PaymentFormContentState();
}

class _PaymentFormContentState extends State<_PaymentFormContent> {
  String? selectedAdmissionNo;
  late DateTime selectedDate;

  @override
  void initState() {
    super.initState();
    selectedAdmissionNo = widget.isEdit
      ? widget.data['admissionNo'] as String?
      : null;
    selectedDate = widget.date;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(widget.ctx).viewInsets.bottom,
        left: 16, right: 16, top: 24
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            widget.isEdit ? 'Edit Payment' : 'Add Payment',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFFB45309),
            ),
          ),
          SizedBox(height: 16),

          _ModernField(
            controller: widget.amountCtl,
            label: 'Amount',
            keyboard: TextInputType.number,
          ),
          _ModernField(
            controller: widget.modeCtl,
            label: 'Mode',
          ),

          // ─── Student dropdown using admissionNo ───
          Container(
            margin: EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonFormField<String>(
              value: selectedAdmissionNo,
              hint: Text('Select Student', style: TextStyle(color: Colors.grey[600])),
              decoration: InputDecoration(
                labelText: 'Student (Adm#)',
                labelStyle: TextStyle(color: Color(0xFF92400E)),
                floatingLabelBehavior: FloatingLabelBehavior.always,
                filled: true,
                fillColor: Color(0xFFFFF7ED),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFFB45309), width: 2),
                ),
              ),
              items: widget.studentDocs.map((s) {
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

          // ─── Date picker ───
          Card(
            margin: EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: Color(0xFFFFF7ED),
            child: ListTile(
              title: Text(
                'Date: ${DateFormat('dd MMM yyyy').format(selectedDate)}',
                style: TextStyle(color: Color(0xFF92400E)),
              ),
              trailing: Icon(Icons.calendar_today, color: Color(0xFFB45309)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: widget.ctx,
                  initialDate: selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  builder: (ctx, child) => Theme(
                    data: Theme.of(ctx).copyWith(
                      colorScheme: ColorScheme.light(
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

          SizedBox(height: 24),

          // ─── Submit button ───
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: selectedAdmissionNo == null
                  ? Colors.grey[400]
                  : Color(0xFFB45309),
                shape: StadiumBorder(),
                minimumSize: Size(0, 50),
              ),
              onPressed: selectedAdmissionNo == null ? null : () async {
                final col = FirebaseFirestore.instance
                  .collection('schools').doc(widget.code)
                  .collection('payments');
                final payload = {
                  'amount': double.tryParse(widget.amountCtl.text) ?? 0,
                  'mode': widget.modeCtl.text.trim(),
                  'date': Timestamp.fromDate(selectedDate),
                  'admissionNo': selectedAdmissionNo!,
                  'timestamp': FieldValue.serverTimestamp(),
                };
                if (widget.isEdit) {
                  await widget.doc!.reference.update(payload);
                } else {
                  await col.add(payload);
                }
                Navigator.pop(widget.ctx);
              },
              child: Text(widget.isEdit ? 'Save Payment' : 'Add Payment'),
            ),
          ),

          SizedBox(height: 16),
        ]),
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
      child: Column(children:[
        Padding(
          padding:EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children:[
              Text('Reports', style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFFB45309), // Amber 700
              )),
              ElevatedButton.icon(
                icon: Icon(Icons.add),
                label: Text('Generate'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white, backgroundColor: Color(0xFFB45309),
                  shape: StadiumBorder(),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                onPressed: ()=> _genReport(context),
              ),
            ],
          ),
        ),
        Expanded(child:
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
              .collection('schools').doc(schoolCode)
              .collection('reports')
              .orderBy('createdAt', descending:true)
              .snapshots(),
            builder:(ctx,snap){
              if(!snap.hasData) {
                return Center(child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB45309)), // Amber 700
              ));
              }
              final docs=snap.data!.docs;
              return ListView.builder(
                itemCount:docs.length,
                itemBuilder:(c,i){
                  final d=docs[i].data()! as Map<String,dynamic>;
                  final date=(d['createdAt'] as Timestamp).toDate();
                  return Card(
                    margin:EdgeInsets.symmetric(horizontal:16,vertical:8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                    child:ListTile(
                      title: Text('Report ${DateFormat('dd/MM/yyyy').format(date)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w500, 
                          color: Color(0xFF92400E), // Amber 800
                        )),
                      subtitle: Text('Students: ${d['totalStudents']}  •  Fees: KES ${ (d['totalFees'] as num).toStringAsFixed(2)}'),
                      trailing: PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: Color(0xFFB45309)), // Amber 700
                        onSelected:(v)=> _exportReport(schoolCode, docs[i].reference.id, v),
                        itemBuilder:(c)=>[
                          PopupMenuItem(value:'CSV',child:Text('Export CSV')),
                          PopupMenuItem(value:'PDF',child:Text('Export PDF')),
                          PopupMenuItem(value:'DEL',child:Text('Delete',style:TextStyle(color:Colors.red))),
                        ],
                      ),
                    )
                  );
                }
              );
            }
          )
        )
      ]),
    );
  }

  Future<void> _genReport(BuildContext ctx) async {
    final school=FirebaseFirestore.instance.collection('schools').doc(schoolCode);
    final studs=await school.collection('students').get();
    final pays=await school.collection('payments').get();
    final totalStud=studs.docs.length;
    final totalFees=pays.docs.fold<double>(0,(s,d)=>s+(d.data()['amount'] as num).toDouble());
    await school.collection('reports').add({
      'createdAt':FieldValue.serverTimestamp(),
      'totalStudents':totalStud,
      'totalFees':totalFees,
    });
  }

  Future<void> _exportReport(String code, String id, String fmt) async {
    final ref=FirebaseFirestore.instance.collection('schools').doc(code).collection('reports').doc(id);
    final snap=await ref.get();
    final d=snap.data()!;
    final date=(d['createdAt'] as Timestamp).toDate();
    final rows=[
      ['Field','Value'],
      ['Date', DateFormat('dd MMM yyyy').format(date)],
      ['Students', d['totalStudents']],
      ['TotalFees', d['totalFees']],
    ];
    final dir=await getApplicationDocumentsDirectory();
    if(fmt=='CSV'){
      final csv=ListToCsvConverter().convert(rows);
      final file=File('${dir.path}/report_$id.csv');
      await file.writeAsString(csv);
      OpenFilex.open(file.path);
    } else if(fmt=='PDF'){
      final pdf=pw.Document();
      pdf.addPage(pw.Page(build:(c)=>pw.Table.fromTextArray(context:c,data:rows)));
      final file=File('${dir.path}/report_$id.pdf');
      await file.writeAsBytes(await pdf.save());
      OpenFilex.open(file.path);
    } else if(fmt=='DEL'){
      await ref.delete();
    }
  }
}

/// ───────── SETTINGS ─────────
class _SettingsView extends StatefulWidget {
  final String schoolCode;
  final String adminDocId;
  const _SettingsView({
    required this.schoolCode,
    required this.adminDocId,
  });
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
      final snap = await FirebaseFirestore.instance
        .collection('schools')
        .doc(widget.schoolCode)
        .collection('admins')
        .doc(widget.adminDocId)
        .get();

      final d = snap.data() ?? <String, dynamic>{};

      // Default to empty string if null
      _nameCtl.text  = (d['name']  as String?) ?? '';
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
        'name':  _nameCtl.text.trim(),
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
        child: Column(children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Admin Profile', style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB45309), // Amber 700
                  )),
                  SizedBox(height: 16),
                  _ModernField(controller: _nameCtl, label: 'Name'),
                  _ModernField(controller: _emailCtl, label: 'Email', keyboard: TextInputType.emailAddress),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: TextField(
                      controller: _passCtl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        labelStyle: TextStyle(color: Color(0xFF92400E)), // Amber 800
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        filled: true,
                        fillColor: Color(0xFFFFF7ED), // Orange 50
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFFB45309), width: 2), // Amber 700
                        ),
                        hintText: 'Leave blank to keep current password',
                        hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white, backgroundColor: Color(0xFFB45309),
                        shape: StadiumBorder(),
                      ),
                      onPressed: _loading ? null : _save,
                      child: _loading
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ───────── GENERIC EDITABLE LIST ─────────
class _EditableList extends StatelessWidget {
  final String title;
  final CollectionReference collection;
  final Widget Function(BuildContext, QueryDocumentSnapshot) itemBuilder;
  final VoidCallback onAdd;
  const _EditableList({
    required this.title,
    required this.collection,
    required this.itemBuilder,
    required this.onAdd,
  });
  @override
  Widget build(BuildContext context) {
    return Column(children:[
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: collection.orderBy('createdAt', descending:true).snapshots(),
          builder:(c,s){
            if(!s.hasData) {
              return Center(child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB45309)), // Amber 700
            ));
            }
            final docs=s.data!.docs;
            return ListView.separated(
              padding: EdgeInsets.only(top: 8, bottom: 80),
              itemBuilder:(c,i)=>itemBuilder(c,docs[i]),
              separatorBuilder:(a,b)=>SizedBox(height: 4),
              itemCount:docs.length);
          },
        )
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
            foregroundColor: Colors.white, backgroundColor: Color(0xFFB45309),
            shape: StadiumBorder(), 
            minimumSize: Size(double.infinity, 50)),
          onPressed: onAdd,
        ),
      )
    ]);
  }
}

// ───────── MODERN FIELD ─────────
class _ModernField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType keyboard;
  const _ModernField({
    required this.controller,
    required this.label,
    this.keyboard=TextInputType.text,
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
            borderSide: BorderSide.none
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Color(0xFFB45309), width: 2), // Amber 700
          ),
        ),
      ),
    );
  }
}

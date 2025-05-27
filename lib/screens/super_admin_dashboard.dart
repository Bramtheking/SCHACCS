// lib/screens/super_admin_dashboard.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:schaccs/screens/login_screen.dart';

class SuperAdminDashboard extends StatefulWidget {
  static const routeName = '/superAdmin';
  const SuperAdminDashboard({super.key});
  @override
  _SuperAdminDashboardState createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  int _tab = 0;
  final _tabs = ['Schools', 'Super-Admins', 'Analytics', 'Audit Log', 'Settings'];

  void _logout() {
    // Clear session if any
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
   appBar: AppBar(
  leading: IconButton(
    icon: Icon(Icons.arrow_back, color: Colors.white),
    onPressed: () {
      Navigator.of(context).pushNamedAndRemoveUntil(
        LoginScreen.routeName,
        (Route<dynamic> route) => false,
        arguments: 'supermaster', // works for super admin login
      );
    },
  ),
  title: Text(
    _tabs[_tab],
    style: const TextStyle(fontWeight: FontWeight.bold),
  ),
  backgroundColor: const Color(0xFFB45309),
  actions: [
    IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
  ],
),



      body: IndexedStack(
        index: _tab,
        children: const [
          _SchoolsView(),
          _SuperAdminsView(),
          _AnalyticsView(),
          _AuditLogView(),
          _SettingsView(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        selectedItemColor: const Color(0xFFB45309),
        unselectedItemColor: Colors.brown,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.school), label: 'Schools'),
          BottomNavigationBarItem(icon: Icon(Icons.supervisor_account), label: 'Super-Admins'),
          BottomNavigationBarItem(icon: Icon(Icons.insert_chart), label: 'Analytics'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Audit Log'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

// ───────── SCHOOLS + SCHOOL-ADMINS ─────────
class _SchoolsView extends StatefulWidget {
  const _SchoolsView();
  @override
  __SchoolsViewState createState() => __SchoolsViewState();
}

class __SchoolsViewState extends State<_SchoolsView> {
  final _schoolNameCtrl = TextEditingController();
  final _adminNameCtrl = TextEditingController();
  final _adminEmailCtrl = TextEditingController();
  final _adminPassCtrl = TextEditingController();

  // Create/Edit School
  void _openSchoolDialog({String? id, String? currentName}) {
    _schoolNameCtrl.text = currentName ?? '';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(id == null ? 'Add School' : 'Edit School'),
        content: TextField(controller: _schoolNameCtrl, decoration: const InputDecoration(labelText: 'School Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = _schoolNameCtrl.text.trim();
              if (name.isEmpty) return;
              final col = FirebaseFirestore.instance.collection('schools');
              if (id == null) {
                final code = name.toLowerCase().replaceAll(' ', '_');
                await col.doc(code).set({'name': name, 'createdAt': FieldValue.serverTimestamp()});
              } else {
                await col.doc(id).update({'name': name});
              }
              Navigator.pop(context);
            },
            child: Text(id == null ? 'Create' : 'Update'),
          ),
        ],
      ),
    );
  }

  // Confirm delete school
  void _confirmDeleteSchool(String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Delete school "$id"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('schools').doc(id).delete();
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Create/Edit School-Admin
  void _openAdminDialog(String schoolId, {DocumentSnapshot? adminDoc}) {
    if (adminDoc != null) {
      _adminNameCtrl.text = adminDoc['name'];
      _adminEmailCtrl.text = adminDoc['email'];
      _adminPassCtrl.text = '';
    } else {
      _adminNameCtrl.clear();
      _adminEmailCtrl.clear();
      _adminPassCtrl.clear();
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(adminDoc == null ? 'Add School-Admin' : 'Edit School-Admin'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _adminNameCtrl, decoration: const InputDecoration(labelText: 'Name')),
          TextField(controller: _adminEmailCtrl, decoration: const InputDecoration(labelText: 'Email')),
          TextField(
            controller: _adminPassCtrl,
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final col = FirebaseFirestore.instance
                  .collection('schools')
                  .doc(schoolId)
                  .collection('admins');
              final data = {
                'name': _adminNameCtrl.text.trim(),
                'email': _adminEmailCtrl.text.trim(),
                'enabled': true,
                'createdAt': FieldValue.serverTimestamp(),
              };
              if (adminDoc == null) {
                data['password'] = _adminPassCtrl.text;
                await col.add(data);
              } else {
                if (_adminPassCtrl.text.isNotEmpty) data['password'] = _adminPassCtrl.text;
                await adminDoc.reference.update(data);
              }
              Navigator.pop(context);
            },
            child: Text(adminDoc == null ? 'Create' : 'Update'),
          ),
        ],
      ),
    );
  }

  // Confirm delete admin
  void _confirmDeleteAdmin(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Removal'),
        content: Text('Remove admin "${doc['name']}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await doc.reference.delete();
              Navigator.pop(context);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('schools')
          .where(FieldPath.documentId, isNotEqualTo: 'supermaster')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final schools = snap.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: schools.length,
          itemBuilder: (_, i) {
            final school = schools[i];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ExpansionTile(
                title: Text(school['name'] ?? school.id),
                subtitle: Text('Code: ${school.id}'),
                children: [
                  // School-level actions
                  OverflowBar(
                    children: [
                      TextButton(
                        onPressed: () => _openSchoolDialog(id: school.id, currentName: school['name']),
                        child: const Text('Edit School'),
                      ),
                      TextButton(
                        onPressed: () => _confirmDeleteSchool(school.id),
                        child: const Text('Delete School', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),

                  // School-Admin list
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(),
                        Text('Admins', style: Theme.of(context).textTheme.titleMedium),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('schools')
                              .doc(school.id)
                              .collection('admins')
                              .orderBy('createdAt', descending: true)
                              .snapshots(),
                          builder: (ctx2, snap2) {
                            if (!snap2.hasData) return const SizedBox();
                            final admins = snap2.data!.docs;
                            return Column(
                              children: admins.map((adm) {
                                final enabled = adm['enabled'] as bool? ?? true;
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                                  title: Text(adm['name']),
                                  subtitle: Text(adm['email']),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (v) {
                                      switch (v) {
                                        case 'edit':
                                          _openAdminDialog(school.id, adminDoc: adm);
                                          break;
                                        case 'toggle':
                                          adm.reference.update({'enabled': !enabled});
                                          break;
                                        case 'remove':
                                          _confirmDeleteAdmin(adm);
                                          break;
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                      PopupMenuItem(
                                          value: 'toggle',
                                          child: Text(enabled ? 'Disable' : 'Enable')),
                                      const PopupMenuItem(
                                          value: 'remove',
                                          child: Text('Remove', style: TextStyle(color: Colors.red))),
                                    ],
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Add Admin'),
                            onPressed: () => _openAdminDialog(school.id),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ───────── SUPER-ADMINS ─────────
class _SuperAdminsView extends StatefulWidget {
  const _SuperAdminsView();
  @override
  __SuperAdminsViewState createState() => __SuperAdminsViewState();
}

class __SuperAdminsViewState extends State<_SuperAdminsView> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  void _openAdminDialog({DocumentSnapshot? doc}) {
    if (doc != null) {
      _nameCtrl.text = doc['name'];
      _emailCtrl.text = doc['email'];
      _passCtrl.text = '';
    } else {
      _nameCtrl.clear();
      _emailCtrl.clear();
      _passCtrl.clear();
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(doc == null ? 'Add Super-Admin' : 'Edit Super-Admin'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
          TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
          TextField(
            controller: _passCtrl,
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = _nameCtrl.text.trim();
              final email = _emailCtrl.text.trim();
              final pass = _passCtrl.text;
              final col = FirebaseFirestore.instance
                  .collection('schools')
                  .doc('supermaster')
                  .collection('admins');
              if (doc == null) {
                await col.add({
                  'name': name,
                  'email': email,
                  'password': pass,
                  'enabled': true,
                  'createdAt': FieldValue.serverTimestamp(),
                });
              } else {
                final data = {
                  'name': name,
                  'email': email,
                };
                if (pass.isNotEmpty) data['password'] = pass;
                await col.doc(doc.id).update(data);
              }
              Navigator.pop(context);
            },
            child: Text(doc == null ? 'Create' : 'Update'),
          ),
        ],
      ),
    );
  }

  void _resetPassword(DocumentSnapshot doc) {
    _passCtrl.clear();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset Password'),
        content: TextField(
          controller: _passCtrl,
          decoration: const InputDecoration(labelText: 'New Password'),
          obscureText: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await doc.reference.update({'password': _passCtrl.text});
              Navigator.pop(context);
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _toggleEnabled(DocumentSnapshot doc) async {
    final enabled = doc['enabled'] as bool? ?? true;
    await doc.reference.update({'enabled': !enabled});
  }

  void _confirmRemove(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Admin'),
        content: Text('Remove admin "${doc['name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await doc.reference.delete();
              Navigator.pop(context);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('schools')
                .doc('supermaster')
                .collection('admins')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (ctx, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snap.data!.docs;
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final d = docs[i];
                  final enabled = d['enabled'] as bool? ?? true;
                  return Card(
                    margin: const EdgeInsets.all(8),
                    child: ListTile(
                      title: Text(d['name']),
                      subtitle: Text(d['email']),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) {
                          switch (v) {
                            case 'edit': _openAdminDialog(doc: d); break;
                            case 'reset': _resetPassword(d); break;
                            case 'toggle': _toggleEnabled(d); break;
                            case 'remove': _confirmRemove(d); break;
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Text('Edit')),
                          const PopupMenuItem(value: 'reset', child: Text('Reset Password')),
                          PopupMenuItem(
                              value: 'toggle',
                              child: Text(enabled ? 'Disable' : 'Enable')),
                          const PopupMenuItem(value: 'remove', child: Text('Remove', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.person_add),
            label: const Text('Add Super-Admin'),
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            onPressed: () => _openAdminDialog(),
          ),
        ),
      ],
    );
  }
}

// ───────── ANALYTICS ─────────
class _AnalyticsView extends StatefulWidget {
  const _AnalyticsView();
  @override
  __AnalyticsViewState createState() => __AnalyticsViewState();
}

class __AnalyticsViewState extends State<_AnalyticsView> {
  DateTimeRange? _range;

  Future<List<int>> _compute({DateTimeRange? range}) async {
    final col = FirebaseFirestore.instance.collection('schools');
    final snap = await col.get();
    final ids = snap.docs.map((d) => d.id).where((id) => id != 'supermaster');
    int students = 0, parents = 0, payments = 0;
    for (var id in ids) {
      final school = col.doc(id);
      Query<Map<String, dynamic>> q = school.collection('students');
      Query<Map<String, dynamic>> p = school.collection('parents');
      Query<Map<String, dynamic>> pay = school.collection('payments');
      if (range != null) {
        q = q.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(range.start));
        q = q.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(range.end));
        p = p.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(range.start));
        p = p.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(range.end));
        pay = pay.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(range.start));
        pay = pay.where('date', isLessThanOrEqualTo: Timestamp.fromDate(range.end));
      }
      students += (await q.get()).docs.length;
      parents += (await p.get()).docs.length;
      payments += (await pay.get()).docs.length;
    }
    return [snap.docs.length - 1, students, parents, payments];
  }

  Future<void> _exportCsv(List<int> data) async {
    final rows = [
      ['Metric', 'Count'],
      ['Schools', data[0]],
      ['Students', data[1]],
      ['Parents', data[2]],
      ['Payments', data[3]],
    ];
    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/analytics_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csv);
    await OpenFilex.open(file.path);
  }

  Future<void> _exportPdf(List<int> data) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(build: (ctx) => pw.Table.fromTextArray(
      data: [
        ['Metric', 'Count'],
        ['Schools', data[0].toString()],
        ['Students', data[1].toString()],
        ['Parents', data[2].toString()],
        ['Payments', data[3].toString()],
      ],
    )));
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/analytics_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    await OpenFilex.open(file.path);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.date_range),
              label: Text(_range == null
                  ? 'Select Range'
                  : '${DateFormat.yMd().format(_range!.start)} - ${DateFormat.yMd().format(_range!.end)}'),
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(now.year - 5),
                  lastDate: now,
                  initialDateRange: _range,
                );
                if (picked != null) setState(() => _range = picked);
              },
            ),
            const SizedBox(width: 16),
            ElevatedButton(onPressed: () async {
              final data = await _compute(range: _range);
              await _exportCsv(data);
            }, child: const Text('Export CSV')),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: () async {
              final data = await _compute(range: _range);
              await _exportPdf(data);
            }, child: const Text('Export PDF')),
          ]),
          const SizedBox(height: 24),
          FutureBuilder<List<int>>(
            future: _compute(range: _range),
            builder: (ctx, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final d = snap.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Schools: ${d[0]}'),
                  Text('Total Students: ${d[1]}'),
                  Text('Total Parents: ${d[2]}'),
                  Text('Total Payments: ${d[3]}'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ───────── AUDIT LOG ─────────
class _AuditLogView extends StatelessWidget {
  const _AuditLogView();
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('audit_logs')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data()! as Map<String, dynamic>;
            return ListTile(
              leading: const Icon(Icons.history),
              title: Text(d['action'] ?? ''),
              subtitle: Text(
                DateFormat('dd MMM yyyy HH:mm').format((d['timestamp'] as Timestamp).toDate()),
              ),
            );
          },
        );
      },
    );
  }
}

// ───────── SETTINGS ─────────
class _SettingsView extends StatelessWidget {
  const _SettingsView();

  // Role assignment: list all school-admins and allow promote/demote.
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collectionGroup('admins').snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i];
            final isSuper = d.reference.path.contains('supermaster');
            return ListTile(
              title: Text(d['name']),
              subtitle: Text('${d['email']} • ${isSuper ? 'Super-Admin' : 'School-Admin'}'),
              trailing: ElevatedButton(
                onPressed: () async {
                  final dest = isSuper
                      ? d.reference.parent.parent!.collection('admins')
                      : FirebaseFirestore.instance.collection('schools').doc('supermaster').collection('admins');
                  final data = d.data() as Map<String, dynamic>;
                  await dest.doc(d.id).set(data);
                  await d.reference.delete();
                },
                child: Text(isSuper ? 'Demote' : 'Promote'),
              ),
            );
          },
        );
      },
    );
  }
}

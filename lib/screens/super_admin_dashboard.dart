import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SuperAdminDashboard extends StatefulWidget {
  static const routeName = '/super-admin-dashboard';

  const SuperAdminDashboard({Key? key}) : super(key: key);

  @override
  SuperAdminDashboardState createState() => SuperAdminDashboardState();
}

class SuperAdminDashboardState extends State<SuperAdminDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic> _dashboardStats = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadDashboardStats();
  }

  Future<void> _loadDashboardStats() async {
    setState(() => _isLoading = true);
    
    try {
      // Get total schools count
      final schoolsSnapshot = await FirebaseFirestore.instance.collection('schools').get();
      final schoolCount = schoolsSnapshot.docs.length;
      
      // Get total students count across all schools
      int totalStudents = 0;
      int totalAdmins = 0;
      int totalParents = 0;
      double totalPayments = 0;
      
      for (var school in schoolsSnapshot.docs) {
        // Count students
        final studentsSnapshot = await FirebaseFirestore.instance
            .collection('schools')
            .doc(school.id)
            .collection('students')
            .count()
            .get();
        totalStudents += studentsSnapshot.count!;
        
        // Count admins
        final adminsSnapshot = await FirebaseFirestore.instance
            .collection('schools')
            .doc(school.id)
            .collection('admins')
            .count()
            .get();
        totalAdmins += adminsSnapshot.count!;
        
        // Count parents
        final parentsSnapshot = await FirebaseFirestore.instance
            .collection('schools')
            .doc(school.id)
            .collection('parents')
            .count()
            .get();
        totalParents += parentsSnapshot.count!;
        
        // Sum payments
        final feeSummarySnapshot = await FirebaseFirestore.instance
    .collection('schools')
    .doc(school.id)
    .collection('payments')
    .where('type', isEqualTo: 'fee summary')
    .get();
    
for (var feeSummary in feeSummarySnapshot.docs) {
  final feeSummaryData = feeSummary.data();
  
  totalPayments += (feeSummaryData['totalPaid'] as num?)?.toDouble() ?? 0;
}
 }
      
      setState(() {
        _dashboardStats = {
          'schoolCount': schoolCount,
          'studentCount': totalStudents,
          'adminCount': totalAdmins,
          'parentCount': totalParents,
          'totalPayments': totalPayments,
        };
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading dashboard stats: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Super Admin Dashboard',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFFB8692E),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadDashboardStats,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pushReplacementNamed('/');
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Schools', icon: Icon(Icons.school)),
            Tab(text: 'Admins', icon: Icon(Icons.admin_panel_settings)),
            Tab(text: 'Users', icon: Icon(Icons.people)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFB8692E)),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                OverviewTab(stats: _dashboardStats),
                SchoolsTab(),
                AdminsTab(),
                UsersTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFB8692E),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          // Show different add dialogs based on active tab
          switch (_tabController.index) {
            case 1: // Schools tab
              _showAddSchoolDialog();
              break;
            case 2: // Admins tab
              _showAddAdminDialog();
              break;
            default:
              break;
          }
        },
      ),
    );
  }

  void _showAddSchoolDialog() {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final addressController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
final poBoxController       = TextEditingController();
final principalController   = TextEditingController();
final logoUrlController     = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Add New School',
          style: TextStyle(color: Color(0xFFB8692E)),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ModernField(controller: nameController, label: 'School Name'),
              ModernField(controller: codeController, label: 'School Code'),
              ModernField(controller: addressController, label: 'Address'),
              ModernField(controller: phoneController, label: 'Phone Number'),
              ModernField(controller: emailController, label: 'Email'),
              // NEW – extra fields
ModernField(controller: poBoxController,     label: 'PO Box'),
ModernField(controller: principalController, label: 'Principal Name'),
ModernField(controller: logoUrlController,   label: 'Logo URL'),

            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB8692E),
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            child: const Text('Add School'),
            onPressed: () async {
              if (nameController.text.isEmpty || codeController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('School name and code are required')),
                );
                return;
              }

              try {
                // Check if school code already exists
                final existingSchool = await FirebaseFirestore.instance
                    .collection('schools')
                    .doc(codeController.text.trim())
                    .get();
                
                if (existingSchool.exists) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('School code already exists')),
                  );
                  return;
                }

                // Add new school
        await FirebaseFirestore.instance
  .collection('schools')
  .doc(codeController.text.trim())
  .set({
    'name':           nameController.text.trim(),
    'code':           codeController.text.trim(),
    'address':        addressController.text.trim(),
    'phone':          phoneController.text.trim(),
    'email':          emailController.text.trim(),
    'poBox':          poBoxController.text.trim(),       // NEW
    'principalName':  principalController.text.trim(),   // NEW
    'logoUrl':        logoUrlController.text.trim(),     // NEW
    'createdAt':      FieldValue.serverTimestamp(),
  });


                Navigator.of(ctx).pop();
                _loadDashboardStats(); // Refresh stats
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('School added successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error adding school: $e')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showAddAdminDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String? selectedSchool;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text(
            'Add New Admin',
            style: TextStyle(color: Color(0xFFB8692E)),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ModernField(controller: nameController, label: 'Admin Name'),
                ModernField(controller: emailController, label: 'Email'),
                ModernField(
                  controller: passwordController,
                  label: 'Password',
                  isPassword: true,
                ),
                const SizedBox(height: 16),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('schools').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const CircularProgressIndicator();
                    }

                    final schools = snapshot.data!.docs;
                    
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: selectedSchool,
                        hint: const Text('Select School'),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                        ),
                        items: schools.map((school) {
                          final data = school.data() as Map<String, dynamic>;
                          return DropdownMenuItem<String>(
                            value: school.id,
                            child: Text('${data['name']} (${school.id})'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedSchool = value;
                          });
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB8692E),
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              child: const Text('Add Admin'),
              onPressed: () async {
                if (nameController.text.isEmpty || 
                    emailController.text.isEmpty || 
                    passwordController.text.isEmpty ||
                    selectedSchool == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All fields are required')),
                  );
                  return;
                }

                try {
                  // Create user in Firebase Auth
                  final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                    email: emailController.text.trim(),
                    password: passwordController.text.trim(),
                  );
                  
                  // Add admin to Firestore
                  await FirebaseFirestore.instance
                      .collection('schools')
                      .doc(selectedSchool)
                      .collection('admins')
                      .doc(userCredential.user!.uid)
                      .set({
                    'name': nameController.text.trim(),
                    'email': emailController.text.trim(),
                    'role': 'admin',
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  Navigator.of(ctx).pop();
                  _loadDashboardStats(); // Refresh stats
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Admin added successfully')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error adding admin: $e')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Overview Tab
class OverviewTab extends StatelessWidget {
  final Map<String, dynamic> stats;
  
  const OverviewTab({Key? key, required this.stats}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF7ED),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'System Overview',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFFB8692E),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Schools',
                    stats['schoolCount']?.toString() ?? '0',
                    Icons.school,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Students',
                    stats['studentCount']?.toString() ?? '0',
                    Icons.person,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Admins',
                    stats['adminCount']?.toString() ?? '0',
                    Icons.admin_panel_settings,
                    Colors.purple,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Parents',
                    stats['parentCount']?.toString() ?? '0',
                    Icons.family_restroom,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatCard(
              'Total Payments',
              'KES ${NumberFormat('#,##0.00').format(stats['totalPayments'] ?? 0)}',
              Icons.payments,
              const Color(0xFFB8692E),
              fullWidth: true,
            ),
            const SizedBox(height: 24),
            const Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFFB8692E),
              ),
            ),
            const SizedBox(height: 16),
            _buildRecentActivityList(),
            const SizedBox(height: 24),
            const Text(
              'System Health',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFFB8692E),
              ),
            ),
            const SizedBox(height: 16),
            _buildSystemHealthCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {bool fullWidth = false}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityList() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('system_logs')
                  .orderBy('timestamp', descending: true)
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFB8692E)),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No recent activity'),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final log = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                    return ListTile(
                      leading: Icon(
                        _getActivityIcon(log['type'] as String? ?? 'info'),
                        color: _getActivityColor(log['type'] as String? ?? 'info'),
                      ),
                      title: Text(log['message'] as String? ?? 'Unknown activity'),
                      subtitle: Text(
                        log['timestamp'] != null
                            ? DateFormat('MMM dd, yyyy • HH:mm').format((log['timestamp'] as Timestamp).toDate())
                            : 'Unknown time',
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'login':
        return Icons.login;
      case 'create':
        return Icons.add_circle;
      case 'update':
        return Icons.edit;
      case 'delete':
        return Icons.delete;
      case 'error':
        return Icons.error;
      default:
        return Icons.info;
    }
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'login':
        return Colors.blue;
      case 'create':
        return Colors.green;
      case 'update':
        return Colors.orange;
      case 'delete':
        return Colors.red;
      case 'error':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildSystemHealthCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'All Systems Operational',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  'Last updated: ${DateFormat('HH:mm').format(DateTime.now())}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildHealthItem('Database', 'Online', Colors.green),
            _buildHealthItem('Authentication', 'Online', Colors.green),
            _buildHealthItem('Storage', 'Online', Colors.green),
            _buildHealthItem('API Services', 'Online', Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthItem(String service, String status, Color statusColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            service,
            style: const TextStyle(fontSize: 16),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Schools Tab
class SchoolsTab extends StatelessWidget {
  const SchoolsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF7ED),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search schools...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFFB8692E)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                // Implement search functionality
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('schools')
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFB8692E)),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No schools found'));
                }

                final schools = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: schools.length,
                  itemBuilder: (context, index) {
                    final school = schools[index].data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ExpansionTile(
                        title: Text(
                          school['name'] as String? ?? 'Unknown School',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB8692E),
                          ),
                        ),
                        subtitle: Text('Code: ${schools[index].id}'),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFB8692E).withOpacity(0.1),
                          child: const Icon(Icons.school, color: Color(0xFFB8692E)),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSchoolDetail('Address', school['address'] as String? ?? 'N/A'),
                                _buildSchoolDetail('Phone', school['phone'] as String? ?? 'N/A'),
                                _buildSchoolDetail('Email', school['email'] as String? ?? 'N/A'),
                                _buildSchoolDetail(
                                  'Created',
                                  school['createdAt'] != null
                                      ? DateFormat('MMM dd, yyyy').format((school['createdAt'] as Timestamp).toDate())
                                      : 'N/A',
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.edit, size: 16),
                                      label: const Text('Edit'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFFB8692E),
                                        side: const BorderSide(color: Color(0xFFB8692E)),
                                      ),
                                      onPressed: () => _showEditSchoolDialog(context, schools[index]),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.delete, size: 16),
                                      label: const Text('Delete'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side: const BorderSide(color: Colors.red),
                                      ),
                                      onPressed: () => _showDeleteSchoolDialog(context, schools[index]),
                                    ),
                                  ],
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchoolDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _showEditSchoolDialog(BuildContext context, DocumentSnapshot school) {
    final data                = school.data() as Map<String, dynamic>;
final nameController      = TextEditingController(text: data['name'] as String?);
final addressController   = TextEditingController(text: data['address'] as String?);
final phoneController     = TextEditingController(text: data['phone'] as String?);
final emailController     = TextEditingController(text: data['email'] as String?);

// NEW – prefill extra fields
final poBoxController       = TextEditingController(text: data['poBox'] as String?);
final principalController   = TextEditingController(text: data['principalName'] as String?);
final logoUrlController     = TextEditingController(text: data['logoUrl'] as String?);


    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Edit School',
          style: TextStyle(color: Color(0xFFB8692E)),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ModernField(controller: nameController, label: 'School Name'),
              ModernField(controller: addressController, label: 'Address'),
              ModernField(controller: phoneController, label: 'Phone Number'),
              ModernField(controller: emailController, label: 'Email'),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB8692E),
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            child: const Text('Save Changes'),
            onPressed: () async {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('School name is required')),
                );
                return;
              }

              try {
                await FirebaseFirestore.instance
                    .collection('schools')
                    .doc(school.id)
                    .update({
                  'name': nameController.text.trim(),
                  'address': addressController.text.trim(),
                  'phone': phoneController.text.trim(),
                  'email': emailController.text.trim(),
                  'updatedAt': FieldValue.serverTimestamp(),
                  'poBox':         poBoxController.text.trim(),       // NEW
'principalName': principalController.text.trim(),   // NEW
'logoUrl':       logoUrlController.text.trim(),     
                });

                Navigator.of(ctx).pop();
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('School updated successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error updating school: $e')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteSchoolDialog(BuildContext context, DocumentSnapshot school) {
    final data = school.data() as Map<String, dynamic>;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Delete School',
          style: TextStyle(color: Colors.red),
        ),
        content: Text(
          'Are you sure you want to delete ${data['name']}? This action cannot be undone and will delete all associated data including students, admins, and payments.',
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            child: const Text('Delete'),
            onPressed: () async {
              try {
                // In a real app, you would need to delete all subcollections first
                // This is a simplified version
                await FirebaseFirestore.instance
                    .collection('schools')
                    .doc(school.id)
                    .delete();

                Navigator.of(ctx).pop();
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('School deleted successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting school: $e')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

// Admins Tab
class AdminsTab extends StatelessWidget {
  const AdminsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF7ED),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search admins...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFFB8692E)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                // Implement search functionality
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('schools')
                  .snapshots(),
              builder: (context, schoolsSnapshot) {
                if (schoolsSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFB8692E)),
                  );
                }

                if (!schoolsSnapshot.hasData || schoolsSnapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No schools found'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: schoolsSnapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final school = schoolsSnapshot.data!.docs[index];
                    final schoolData = school.data() as Map<String, dynamic>;
                    
                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('schools')
                          .doc(school.id)
                          .collection('admins')
                          .snapshots(),
                      builder: (context, adminsSnapshot) {
                        if (adminsSnapshot.connectionState == ConnectionState.waiting) {
                          return const SizedBox.shrink();
                        }

                        if (!adminsSnapshot.hasData || adminsSnapshot.data!.docs.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Text(
                                '${schoolData['name']} (${school.id})',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFB8692E),
                                ),
                              ),
                            ),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: adminsSnapshot.data!.docs.length,
                              itemBuilder: (context, adminIndex) {
                                final admin = adminsSnapshot.data!.docs[adminIndex];
                                final adminData = admin.data() as Map<String, dynamic>;
                                
                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: const Color(0xFFB8692E).withOpacity(0.1),
                                      child: const Icon(Icons.person, color: Color(0xFFB8692E)),
                                    ),
                                    title: Text(
                                      adminData['name'] as String? ?? 'Unknown Admin',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text(adminData['email'] as String? ?? 'No email'),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Color(0xFFB8692E)),
                                          onPressed: () => _showEditAdminDialog(context, school.id, admin),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: () => _showDeleteAdminDialog(context, school.id, admin),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
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

  void _showEditAdminDialog(BuildContext context, String schoolId, DocumentSnapshot admin) {
    final data = admin.data() as Map<String, dynamic>;
    final nameController = TextEditingController(text: data['name'] as String?);
    final emailController = TextEditingController(text: data['email'] as String?);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Edit Admin',
          style: TextStyle(color: Color(0xFFB8692E)),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ModernField(controller: nameController, label: 'Admin Name'),
              ModernField(controller: emailController, label: 'Email', enabled: false),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.lock_reset, size: 16),
                label: const Text('Reset Password'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: const BorderSide(color: Colors.blue),
                ),
                onPressed: () => _showResetPasswordDialog(context, data['email'] as String? ?? ''),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB8692E),
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            child: const Text('Save Changes'),
            onPressed: () async {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Admin name is required')),
                );
                return;
              }

              try {
                await FirebaseFirestore.instance
                    .collection('schools')
                    .doc(schoolId)
                    .collection('admins')
                    .doc(admin.id)
                    .update({
                  'name': nameController.text.trim(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                Navigator.of(ctx).pop();
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Admin updated successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error updating admin: $e')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showResetPasswordDialog(BuildContext context, String email) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Reset Password',
          style: TextStyle(color: Colors.blue),
        ),
        content: Text(
          'Send password reset email to $email?',
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            child: const Text('Send Reset Email'),
            onPressed: () async {
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                Navigator.of(ctx).pop();
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password reset email sent')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error sending reset email: $e')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteAdminDialog(BuildContext context, String schoolId, DocumentSnapshot admin) {
    final data = admin.data() as Map<String, dynamic>;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Delete Admin',
          style: TextStyle(color: Colors.red),
        ),
        content: Text(
          'Are you sure you want to delete admin ${data['name']}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            child: const Text('Delete'),
            onPressed: () async {
              try {
                // Delete from Firestore
                await FirebaseFirestore.instance
                    .collection('schools')
                    .doc(schoolId)
                    .collection('admins')
                    .doc(admin.id)
                    .delete();

                // In a real app, you might want to delete the Firebase Auth user as well
                // This requires Cloud Functions or admin SDK

                Navigator.of(ctx).pop();
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Admin deleted successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting admin: $e')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

// Users Tab
class UsersTab extends StatelessWidget {
  const UsersTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Container(
        color: const Color(0xFFFFF7ED),
        child: Column(
          children: [
            Container(
              color: Colors.white,
              child: const TabBar(
                labelColor: Color(0xFFB8692E),
                unselectedLabelColor: Colors.grey,
                indicatorColor: Color(0xFFB8692E),
                tabs: [
                  Tab(text: 'Parents'),
                  Tab(text: 'Students'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildParentsTab(),
                  _buildStudentsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParentsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('schools')
          .snapshots(),
      builder: (context, schoolsSnapshot) {
        if (schoolsSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFB8692E)),
          );
        }

        if (!schoolsSnapshot.hasData || schoolsSnapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No schools found'));
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: schoolsSnapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final school = schoolsSnapshot.data!.docs[index];
            final schoolData = school.data() as Map<String, dynamic>;
            
            return ExpansionTile(
              title: Text(
                schoolData['name'] as String? ?? 'Unknown School',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFB8692E),
                ),
              ),
              subtitle: Text('Code: ${school.id}'),
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('schools')
                      .doc(school.id)
                      .collection('parents')
                      .snapshots(),
                  builder: (context, parentsSnapshot) {
                    if (parentsSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFFB8692E)),
                      );
                    }

                    if (!parentsSnapshot.hasData || parentsSnapshot.data!.docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('No parents found for this school'),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: parentsSnapshot.data!.docs.length,
                      itemBuilder: (context, parentIndex) {
                        final parent = parentsSnapshot.data!.docs[parentIndex];
                        final parentData = parent.data() as Map<String, dynamic>;
                        
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFB8692E).withOpacity(0.1),
                            child: const Icon(Icons.person, color: Color(0xFFB8692E)),
                          ),
                          title: Text(parentData['name'] as String? ?? 'Unknown Parent'),
                          subtitle: Text(parentData['email'] as String? ?? 'No email'),
                          trailing: IconButton(
                            icon: const Icon(Icons.info, color: Color(0xFFB8692E)),
                            onPressed: () => _showParentDetailsDialog(context, school.id, parent),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStudentsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('schools')
          .snapshots(),
      builder: (context, schoolsSnapshot) {
        if (schoolsSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFB8692E)),
          );
        }

        if (!schoolsSnapshot.hasData || schoolsSnapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No schools found'));
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: schoolsSnapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final school = schoolsSnapshot.data!.docs[index];
            final schoolData = school.data() as Map<String, dynamic>;
            
            return ExpansionTile(
              title: Text(
                schoolData['name'] as String? ?? 'Unknown School',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFB8692E),
                ),
              ),
              subtitle: Text('Code: ${school.id}'),
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('schools')
                      .doc(school.id)
                      .collection('students')
                      .snapshots(),
                  builder: (context, studentsSnapshot) {
                    if (studentsSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFFB8692E)),
                      );
                    }

                    if (!studentsSnapshot.hasData || studentsSnapshot.data!.docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('No students found for this school'),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: studentsSnapshot.data!.docs.length,
                      itemBuilder: (context, studentIndex) {
                        final student = studentsSnapshot.data!.docs[studentIndex];
                        final studentData = student.data() as Map<String, dynamic>;
                        
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFB8692E).withOpacity(0.1),
                            child: const Icon(Icons.school, color: Color(0xFFB8692E)),
                          ),
                          title: Text(studentData['name'] as String? ?? 'Unknown Student'),
                          subtitle: Text(
                            'Adm#: ${studentData['admissionNo'] as String? ?? 'N/A'} • Class: ${studentData['class'] as String? ?? 'N/A'}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.info, color: Color(0xFFB8692E)),
                            onPressed: () => _showStudentDetailsDialog(context, school.id, student),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showParentDetailsDialog(BuildContext context, String schoolId, DocumentSnapshot parent) {
    final data = parent.data() as Map<String, dynamic>;
final parentAdmissionNo = data['admissionNo'] as String?;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          data['name'] as String? ?? 'Parent Details',
          style: const TextStyle(color: Color(0xFFB8692E)),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailItem('Email', data['email'] as String? ?? 'N/A'),
              _buildDetailItem('Phone', data['phone'] as String? ?? 'N/A'),
              _buildDetailItem(
                'Registered',
                data['createdAt'] != null
                    ? DateFormat('MMM dd, yyyy').format((data['createdAt'] as Timestamp).toDate())
                    : 'N/A',
              ),
              const SizedBox(height: 16),
              const Text(
                'Children',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFB8692E),
                ),
              ),
              const SizedBox(height: 8),
              FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('schools')
                    .doc(schoolId)
                    .collection('students')
                   .where('admissionNo', isEqualTo: parentAdmissionNo)
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFFB8692E)),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Text('No children found');
                  }

                  return Column(
                    children: snapshot.data!.docs.map((student) {
                      final studentData = student.data() as Map<String, dynamic>;
                      return ListTile(
                        title: Text(studentData['name'] as String? ?? 'Unknown Student'),
                        subtitle: Text(
                          'Adm#: ${studentData['admissionNo'] as String? ?? 'N/A'} • Class: ${studentData['class'] as String? ?? 'N/A'}',
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  void _showStudentDetailsDialog(BuildContext context, String schoolId, DocumentSnapshot student) {
    final data = student.data() as Map<String, dynamic>;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          data['name'] as String? ?? 'Student Details',
          style: const TextStyle(color: Color(0xFFB8692E)),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailItem('Admission No', data['admissionNo'] as String? ?? 'N/A'),
              _buildDetailItem('Class', data['class'] as String? ?? 'N/A'),
              _buildDetailItem('Gender', data['gender'] as String? ?? 'N/A'),
              _buildDetailItem('Date of Birth', data['dob'] as String? ?? 'N/A'),
              const SizedBox(height: 16),
              const Text(
                'Fee Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFB8692E),
                ),
              ),
              const SizedBox(height: 8),
              FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('schools')
                    .doc(schoolId)
                    .collection('payments')
                    .where('type', isEqualTo: 'fee summary')
                    .where('admissionNo', isEqualTo: data['admissionNo'])
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFFB8692E)),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Text('No fee summary found');
                  }

                  final feeSummary = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailItem('Total Required', 'KES ${(feeSummary['totalRequired'] as num?)?.toStringAsFixed(2) ?? '0.00'}'),
                          _buildDetailItem('Total Paid', 'KES ${(feeSummary['totalPaid'] as num?)?.toStringAsFixed(2) ?? '0.00'}'),
                          _buildDetailItem('Total Balance', 'KES ${(feeSummary['totalBalance'] as num?)?.toStringAsFixed(2) ?? '0.00'}'),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Parent Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFB8692E),
                ),
              ),
              const SizedBox(height: 8),
              FutureBuilder<DocumentSnapshot>(
                future: data['parentId'] != null
                    ? FirebaseFirestore.instance
                        .collection('schools')
                        .doc(schoolId)
                        .collection('parents')
                        .doc(data['parentId'] as String)
                        .get()
                    : null,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Text('No parent information found');
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFFB8692E)),
                    );
                  }

                  if (!snapshot.data!.exists) {
                    return const Text('Parent not found');
                  }

                  final parentData = snapshot.data!.data() as Map<String, dynamic>;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailItem('Name', parentData['name'] as String? ?? 'N/A'),
                          _buildDetailItem('Email', parentData['email'] as String? ?? 'N/A'),
                          _buildDetailItem('Phone', parentData['phone'] as String? ?? 'N/A'),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}

// Modern Field Widget
class ModernField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType keyboard;
  final bool isPassword;
  final bool enabled;

  const ModernField({
    Key? key,
    required this.controller,
    required this.label,
    this.keyboard = TextInputType.text,
    this.isPassword = false,
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        obscureText: isPassword,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF92400E)),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          filled: true,
          fillColor: const Color(0xFFFFF7ED),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFB8692E), width: 2),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
          ),
        ),
      ),
    );
  }
}

// Helper function to get a unique document ID
Future<String> getUniqueDocId(String schoolCode, String collection, String baseId) async {
  String docId = baseId;
  int counter = 1;
  bool exists = true;

  while (exists) {
    final doc = await FirebaseFirestore.instance
        .collection('schools')
        .doc(schoolCode)
        .collection(collection)
        .doc(docId)
        .get();
    
    if (!doc.exists) {
      exists = false;
    } else {
      counter++;
      docId = '$baseId-$counter';
    }
  }

  return docId;
}
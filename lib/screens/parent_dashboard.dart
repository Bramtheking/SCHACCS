import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:schaccs/screens/login_screen.dart';
import 'package:schaccs/screens/statement_screen.dart';
import 'package:schaccs/screens/newsletter_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class ParentDashboard extends StatefulWidget {
  static const String routeName = '/parent-dashboard';
  final String schoolCode;
  final String parentDocId;

  const ParentDashboard({
    super.key,
    required this.schoolCode,
    required this.parentDocId,
  });

  @override
  _ParentDashboardState createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  String? selectedStudentId;
  List<Map<String, dynamic>> students = [];
  Map<String, dynamic>? selectedStudent;
  Map<String, dynamic>? parentData;
  bool isLoading = true;
  String schoolName = '';

  // Color scheme
  final Color primaryColor = Color(0xFFB45309); // Amber 700
  final Color secondaryColor = Color(0xFFD97706); // Amber 600
  final Color backgroundColor = Color(0xFFFFF7ED); // Orange 50 background
  final Color textPrimaryColor = Color(0xFF4A4A4A);
  final Color textSecondaryColor = Color(0xFF888888);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final schoolRef = FirebaseFirestore.instance.collection('schools').doc(widget.schoolCode);
      
      // Fetch school name
      final schoolDoc = await schoolRef.get();
      final school = schoolDoc.data();
      if (school != null) {
        setState(() {
          schoolName = school['name'] ?? '';
        });
      }

      // Fetch parent data
      final parentDoc = await schoolRef.collection('parents').doc(widget.parentDocId).get();
      final parent = parentDoc.data();
      if (parent == null) return;

      setState(() {
        parentData = parent;
      });

      // Fetch students using admission number from parent data
      final parentAdmissionNo = parent['admissionNo'] as String?;
      if (parentAdmissionNo == null) return;

      final studentQuery = await schoolRef
          .collection('students')
          .where('admissionNo', isEqualTo: parentAdmissionNo)
          .get();

      final studentList = studentQuery.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      setState(() {
        students = studentList;
        if (students.isNotEmpty) {
          selectedStudentId = students[0]['id'];
          selectedStudent = students[0];
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading data: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pushNamedAndRemoveUntil(
              LoginScreen.routeName,
              (Route<dynamic> route) => false,
              arguments: widget.schoolCode,
            );
          },
        ),
        title: Text(
          'Parent Dashboard',
          style: GoogleFonts.workSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        actions: [
          if (parentData != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: CircleAvatar(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: Text(
                        (parentData?['name'] ?? '').isNotEmpty 
                          ? (parentData?['name'] ?? '')[0].toUpperCase() 
                          : 'P',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    parentData?['name'] ?? '', 
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
          ),
        ],
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: primaryColor),
                  SizedBox(height: 16),
                  Text(
                    'Loading dashboard...',
                    style: GoogleFonts.workSans(
                      color: primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : students.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: primaryColor,
                  child: SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildWelcomeHeader(),
                        SizedBox(height: 24),
                        _buildStudentInfoCard(),
                        SizedBox(height: 20),
                        _buildFeePaymentCard(),
                        SizedBox(height: 20),
                        _buildNewsletterCard(),
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.school,
              color: Colors.white,
              size: 32,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome to',
                  style: GoogleFonts.workSans(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
                Text(
                  schoolName.isNotEmpty ? schoolName : 'School Portal',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Stay connected with your child\'s education',
                  style: GoogleFonts.workSans(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentInfoCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      shadowColor: primaryColor.withOpacity(0.3),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [Colors.white, backgroundColor.withOpacity(0.5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.person,
                      color: primaryColor,
                      size: 28,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Student Information',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        Text(
                          'View your child\'s details',
                          style: GoogleFonts.workSans(
                            fontSize: 14,
                            color: textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              
              // Student selector if multiple students
              if (students.length > 1) ...[
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primaryColor.withOpacity(0.2)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedStudentId,
                      isExpanded: true,
                      icon: Icon(Icons.keyboard_arrow_down, color: primaryColor),
                      hint: Text('Select Student'),
                      items: students.map((student) {
                        return DropdownMenuItem<String>(
                          value: student['id'],
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: primaryColor.withOpacity(0.1),
                                child: Text(
                                  (student['name'] ?? '').isNotEmpty 
                                    ? student['name'][0].toUpperCase() 
                                    : 'S',
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                student['name'] ?? 'Unknown',
                                style: GoogleFonts.workSans(fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedStudentId = value;
                            selectedStudent = students.firstWhere((student) => student['id'] == value);
                          });
                        }
                      },
                    ),
                  ),
                ),
                SizedBox(height: 20),
              ],
              
              // Student details
              if (selectedStudent != null) ...[
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: primaryColor.withOpacity(0.1)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: primaryColor, width: 2),
                            ),
                            child: CircleAvatar(
                              radius: 30,
                              backgroundColor: primaryColor.withOpacity(0.1),
                              child: Text(
  (selectedStudent?['name'] ?? '').isNotEmpty
      ? (selectedStudent?['name'] ?? '')[0].toUpperCase()
      : 'S',
  style: TextStyle(
    color: primaryColor,
    fontSize: 24,
    fontWeight: FontWeight.bold,
  ),
),

                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedStudent?['name'] ?? 'Unknown Student',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimaryColor,
                                  ),
                                ),
                                Text(
                                  'Class ${selectedStudent?['class'] ?? 'N/A'}',
                                  style: GoogleFonts.workSans(
                                    fontSize: 14,
                                    color: textSecondaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoItem(
                              Icons.badge,
                              'Admission No',
                              selectedStudent?['admissionNo'] ?? 'N/A',
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _buildInfoItem(
                              Icons.cake,
                              'Age',
                              '${selectedStudent?['age'] ?? 'N/A'}',
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoItem(
                              Icons.location_city,
                              'City',
                              selectedStudent?['city'] ?? 'N/A',
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _buildInfoItem(
                              Icons.phone,
                              'Parent Phone',
                              selectedStudent?['parentPhone'] ?? 'N/A',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: primaryColor),
              SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.workSans(
                  fontSize: 12,
                  color: textSecondaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.workSans(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textPrimaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeePaymentCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      shadowColor: Colors.green.withOpacity(0.3),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            StatementScreen.routeName,
            arguments: {
              'school': widget.schoolCode,
              'parentDocId': widget.parentDocId,
            },
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [Colors.white, Colors.green.shade50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet,
                    color: Colors.green[700],
                    size: 32,
                  ),
                ),
                SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fee & Payment Summary',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'View detailed fee statements and payment history',
                        style: GoogleFonts.workSans(
                          fontSize: 14,
                          color: textSecondaryColor,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'Tap to view details',
                            style: GoogleFonts.workSans(
                              fontSize: 12,
                              color: Colors.green[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 12,
                            color: Colors.green[600],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNewsletterCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      shadowColor: Colors.blue.withOpacity(0.3),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            NewsletterScreen.routeName,
            arguments: {
              'schoolCode': widget.schoolCode,
              'parentDocId': widget.parentDocId,
            },
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [Colors.white, Colors.blue.shade50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.newspaper,
                    color: Colors.blue[700],
                    size: 32,
                  ),
                ),
                SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'School News & Updates',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Stay updated with school announcements and newsletters',
                        style: GoogleFonts.workSans(
                          fontSize: 14,
                          color: textSecondaryColor,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'Tap to view updates',
                            style: GoogleFonts.workSans(
                              fontSize: 12,
                              color: Colors.blue[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 12,
                            color: Colors.blue[600],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.school,
                size: 80,
                color: primaryColor,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'No Students Found',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'There are no students linked to this parent account.',
              style: GoogleFonts.workSans(
                fontSize: 16,
                color: textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: Text(
                'Refresh',
                style: GoogleFonts.workSans(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
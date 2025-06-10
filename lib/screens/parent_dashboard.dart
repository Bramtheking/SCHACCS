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

class _ParentDashboardState extends State<ParentDashboard>
    with TickerProviderStateMixin {
  String? selectedStudentId;
  List<Map<String, dynamic>> students = [];
  Map<String, dynamic>? selectedStudent;
  Map<String, dynamic>? parentData;
  bool isLoading = true;
  String schoolName = '';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Enhanced modern color scheme
  final Color primaryColor = Color(0xFFB45309); // Amber 700
  final Color secondaryColor = Color(0xFFD97706); // Amber 600
  final Color accentColor = Color(0xFFF59E0B); // Amber 500
  final Color backgroundColor = Color(0xFFFFFBF5); // Warmer background
  final Color cardBackground = Colors.white;
  final Color textPrimaryColor = Color(0xFF1F2937); // Gray 800
  final Color textSecondaryColor = Color(0xFF6B7280); // Gray 500
  final Color surfaceColor = Color(0xFFF9FAFB); // Gray 50

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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

      _animationController.forward();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading data: ${e.toString()}'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          if (isLoading)
            SliverFillRemaining(
              child: _buildLoadingState(),
            )
          else if (students.isEmpty)
            SliverFillRemaining(
              child: _buildEmptyState(),
            )
          else
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    children: [
                      _buildQuickStats(),
                      SizedBox(height: 24),
                      _buildStudentInfoCard(),
                      SizedBox(height: 20),
                      _buildActionCards(),
                      SizedBox(height: 20),
                      _buildRecentActivityCard(),
                      SizedBox(height: 100), // Bottom padding
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      backgroundColor: primaryColor,
      leading: IconButton(
        icon: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
        onPressed: () {
          Navigator.of(context).pushNamedAndRemoveUntil(
            LoginScreen.routeName,
            (Route<dynamic> route) => false,
            arguments: widget.schoolCode,
          );
        },
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryColor,
                secondaryColor,
                accentColor,
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -50,
                top: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                right: -100,
                top: 50,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
            ],
          ),
        ),
        title: Text(
          'Dashboard',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: false,
      ),
      actions: [
        if (parentData != null)
          Container(
            margin: EdgeInsets.only(right: 16, top: 8, bottom: 8),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: Center(
                    child: Text(
                      (parentData?['name'] ?? '').isNotEmpty 
                        ? (parentData?['name'] ?? '')[0].toUpperCase() 
                        : 'P',
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  parentData?['name']?.split(' ')[0] ?? '', 
                  style: GoogleFonts.workSans(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: CircularProgressIndicator(
                color: primaryColor,
                strokeWidth: 3,
              ),
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Loading your dashboard...',
            style: GoogleFonts.poppins(
              color: primaryColor,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Please wait while we fetch your data',
            style: GoogleFonts.workSans(
              color: textSecondaryColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Container(
      margin: EdgeInsets.only(top: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total Students',
              '${students.length}',
              Icons.people,
              Colors.blue,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: _buildStatCard(
              'Active Session',
              '2024-25',
              Icons.calendar_today,
              Colors.green,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: _buildStatCard(
              'Notifications',
              '3',
              Icons.notifications,
              Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textPrimaryColor,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.workSans(
              fontSize: 12,
              color: textSecondaryColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStudentInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor.withOpacity(0.1), accentColor.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Student Profile',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textPrimaryColor,
                        ),
                      ),
                      Text(
                        'Your child\'s academic information',
                        style: GoogleFonts.workSans(
                          fontSize: 14,
                          color: textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (students.length > 1)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${students.length} students',
                      style: GoogleFonts.workSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              children: [
                // Student selector if multiple students
                if (students.length > 1) ...[
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: primaryColor.withOpacity(0.2)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedStudentId,
                        isExpanded: true,
                        icon: Icon(Icons.expand_more, color: primaryColor),
                        hint: Text('Select Student'),
                        items: students.map((student) {
                          return DropdownMenuItem<String>(
                            value: student['id'],
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [primaryColor, accentColor],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      (student['name'] ?? '').isNotEmpty 
                                        ? student['name'][0].toUpperCase() 
                                        : 'S',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      student['name'] ?? 'Unknown',
                                      style: GoogleFonts.workSans(
                                        fontWeight: FontWeight.w600,
                                        color: textPrimaryColor,
                                      ),
                                    ),
                                    Text(
                                      'Class ${student['class'] ?? 'N/A'}',
                                      style: GoogleFonts.workSans(
                                        fontSize: 12,
                                        color: textSecondaryColor,
                                      ),
                                    ),
                                  ],
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
                  SizedBox(height: 24),
                ],
                
                // Student details
                if (selectedStudent != null) ...[
                  Row(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [primaryColor, accentColor],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.3),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            (selectedStudent?['name'] ?? '').isNotEmpty
                                ? (selectedStudent?['name'] ?? '')[0].toUpperCase()
                                : 'S',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedStudent?['name'] ?? 'Unknown Student',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: textPrimaryColor,
                              ),
                            ),
                            SizedBox(height: 4),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Class ${selectedStudent?['class'] ?? 'N/A'}',
                                style: GoogleFonts.workSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.verified, size: 16, color: Colors.green),
                                SizedBox(width: 4),
                                Text(
                                  'Active Student',
                                  style: GoogleFonts.workSans(
                                    fontSize: 12,
                                    color: Colors.green[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  
                  // Student info grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      _buildInfoTile(
                        Icons.badge_outlined,
                        'Admission No',
                        selectedStudent?['admissionNo'] ?? 'N/A',
                        Colors.blue,
                      ),
                      _buildInfoTile(
                        Icons.cake_outlined,
                        'Age',
                        '${selectedStudent?['age'] ?? 'N/A'} years',
                        Colors.purple,
                      ),
                      _buildInfoTile(
                        Icons.location_city_outlined,
                        'City',
                        selectedStudent?['city'] ?? 'N/A',
                        Colors.green,
                      ),
                      _buildInfoTile(
                        Icons.phone_outlined,
                        'Contact',
                        selectedStudent?['parentPhone'] ?? 'N/A',
                        Colors.orange,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.workSans(
              fontSize: 12,
              color: textSecondaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.workSans(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textPrimaryColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActionCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'Fee Statement',
                'View payment history',
                Icons.account_balance_wallet,
                Colors.green,
                () {
                  Navigator.pushNamed(
                    context,
                    StatementScreen.routeName,
                    arguments: {
                      'school': widget.schoolCode,
                      'parentDocId': widget.parentDocId,
                    },
                  );
                },
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildActionCard(
                'Newsletters',
                'School updates',
                Icons.newspaper,
                Colors.blue,
                () {
                  Navigator.pushNamed(
                    context,
                    NewsletterScreen.routeName,
                    arguments: {
                      'schoolCode': widget.schoolCode,
                      'parentDocId': widget.parentDocId,
                    },
                  );
                },
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'Attendance',
                'Track presence',
                Icons.fact_check,
                Colors.purple,
                () {
                  // TODO: Navigate to attendance screen
                },
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildActionCard(
                'Academics',
                'Grades & reports',
                Icons.school,
                Colors.indigo,
                () {
                  // TODO: Navigate to academics screen
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBackground,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textPrimaryColor,
              ),
            ),
            SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.workSans(
                fontSize: 12,
                color: textSecondaryColor,
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'View details',
                  style: GoogleFonts.workSans(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios, size: 12, color: color),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityCard() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.timeline, color: primaryColor, size: 20),
              ),
              SizedBox(width: 12),
              Text(
                'Recent Activity',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimaryColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          _buildActivityItem(
            'Fee Payment Received',
            'KES 15,000 - Term 2 fees',
            '2 days ago',
            Icons.payment,
            Colors.green,
          ),
          _buildActivityItem(
            'Newsletter Published',
            'Monthly school newsletter available',
            '1 week ago',
            Icons.article,
            Colors.blue,
          ),
          _buildActivityItem(
            'Report Card Ready',
            'Mid-term examination results',
            '2 weeks ago',
            Icons.assessment,
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String title, String subtitle, String time, IconData icon, Color color) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.workSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimaryColor,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.workSans(
                    fontSize: 12,
                    color: textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: GoogleFonts.workSans(
              fontSize: 11,
              color: textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: _loadData,
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 8,
      icon: Icon(Icons.refresh),
      label: Text(
        'Refresh',
        style: GoogleFonts.workSans(fontWeight: FontWeight.w600),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor.withOpacity(0.1), accentColor.withOpacity(0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.school_outlined,
                    size: 40,
                    color: primaryColor,
                  ),
                ),
              ),
            ),
            SizedBox(height: 32),
            Text(
              'No Students Found',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textPrimaryColor,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'It looks like there are no students\nlinked to your parent account.',
              style: GoogleFonts.workSans(
                fontSize: 16,
                color: textSecondaryColor,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 40),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, accentColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.3),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _loadData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Refresh Data',
                      style: GoogleFonts.workSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Contact school administration if you believe this is an error.',
                      style: GoogleFonts.workSans(
                        fontSize: 14,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
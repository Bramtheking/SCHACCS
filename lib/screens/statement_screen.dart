import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:schaccs/screens/login_screen.dart';

class StatementScreen extends StatefulWidget {
  static const String routeName = '/statement';
  final String schoolCode;
  final String parentDocId;
  
  const StatementScreen({
    super.key,
    required this.schoolCode,
    required this.parentDocId,
  });
  
  @override
  _StatementScreenState createState() => _StatementScreenState();
}

class _StatementScreenState extends State<StatementScreen> {
  String? selectedStudentId;
  List<Map<String, dynamic>> students = [];
  Map<String, dynamic>? selectedStudent;
  List<Map<String, dynamic>> payments = [];
  bool isLoading = true;
  String? _selectedTimeFilter = 'current_term';
  
  // Color scheme
  final Color primaryColor = Color(0xFFB45309); // Amber 700
  final Color accentColor = Color(0xFFD97706); // Amber 600
  final Color backgroundColor = Color(0xFFFFF7ED); // Orange 50 background
  final Color tableHeaderColor = Color(0xFFFFF7ED); // Orange 50
  final Color tableBorderColor = Color(0xFFD4D4D8); // Zinc 300
  
  // School info
  String schoolName = '';
  String poBox = '';
  String phone = '';
  String email = '';
  String principalName = '';
  String schoolLogo = 'assets/school_logo.png';
  
  Map<String, dynamic>? parentData;
  
  @override
  void initState() {
    super.initState();
    fetchData();
  }
  
  Future<void> fetchData() async {
    setState(() {
      isLoading = true;
    });
    
    try {
      final schoolRef = FirebaseFirestore.instance.collection('schools').doc(widget.schoolCode);
      
      // Fetch school details
      final schoolDoc = await schoolRef.get();
      final school = schoolDoc.data();
      
      if (school != null) {
        setState(() {
          schoolName = school['name'] ?? '';
          poBox = school['poBox'] ?? '';
          phone = school['phone'] ?? '';
          email = school['email'] ?? '';
          principalName = school['principalName'] ?? '';
          if (school['logoUrl'] != null) {
            schoolLogo = school['logoUrl'];
          }
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
      
      // Fetch payments
      if (selectedStudentId != null) {
        _filterPayments();
      }
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

  // FIXED: Updated _filterPayments method
  void _filterPayments() async {
    if (selectedStudent == null) return;
    
    setState(() {
      isLoading = true;
    });
    
    try {
      final schoolRef = FirebaseFirestore.instance.collection('schools').doc(widget.schoolCode);
      final admissionNo = selectedStudent!['admissionNo'] as String;
      
      print('Filtering payments for admission number: $admissionNo');
      
      if (_selectedTimeFilter == 'yearly') {
        // Get fee summary data
        final feeSummaryQuery = await schoolRef
          .collection('payments')
          .where('admissionNo', isEqualTo: admissionNo)
          .where('type', isEqualTo: 'fee summary')
          .get();
          
        print('Fee summary query returned ${feeSummaryQuery.docs.length} documents');
        
        final feeSummaryList = feeSummaryQuery.docs.map((doc) => doc.data()).toList();
        
        setState(() {
          payments = feeSummaryList;
          isLoading = false;
        });
      } else {
        // Get ALL payment history first, then filter by date in code
        final paymentQuery = await schoolRef
          .collection('payments')
          .where('admissionNo', isEqualTo: admissionNo)
          .where('type', isEqualTo: 'payment history')
          .get();
          
        print('Found ${paymentQuery.docs.length} payment history documents');
        
        if (paymentQuery.docs.isNotEmpty) {
          print('First payment document: ${paymentQuery.docs.first.data()}');
        }
        
        // Filter by date in code (more reliable than Firestore compound queries)
        final paymentList = paymentQuery.docs.map((doc) => doc.data()).where((payment) {
          if (payment['date'] == null) return true; // Include payments without dates
          
          final paymentDate = (payment['date'] as Timestamp).toDate();
          final now = DateTime.now();
          
          if (_selectedTimeFilter == 'term3') {
            return paymentDate.isAfter(DateTime(now.year, 1, 1)) && 
                   paymentDate.isBefore(DateTime(now.year, 4, 30, 23, 59, 59));
          } else if (_selectedTimeFilter == 'term1') {
            return paymentDate.isAfter(DateTime(now.year, 5, 1)) && 
                   paymentDate.isBefore(DateTime(now.year, 8, 31, 23, 59, 59));
          } else if (_selectedTimeFilter == 'term2') {
            return paymentDate.isAfter(DateTime(now.year, 9, 1)) && 
                   paymentDate.isBefore(DateTime(now.year, 12, 31, 23, 59, 59));
          } else { // current_term
            return true; // Show all for current term
          }
        }).toList();
        
        print('Filtered to ${paymentList.length} payments');
        
        setState(() {
          payments = paymentList;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error filtering payments: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading payment data: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        payments = [];
        isLoading = false;
      });
    }
  }
  
  Widget buildHeader() {
    final now = DateTime.now();
    late final String termLabel;
    if (now.month >= 1 && now.month <= 4) {
      termLabel = 'Term 1';
    } else if (now.month >= 5 && now.month <= 8) {
      termLabel = 'Term 2';
    } else {
      termLabel = 'Term 3';
    }
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      shadowColor: primaryColor.withOpacity(0.3),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.white, backgroundColor.withOpacity(0.5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: primaryColor, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.transparent,
                      child: ClipOval(
                        child: Image.network(
                          schoolLogo,
                          errorBuilder: (context, error, stackTrace) =>
                              Icon(Icons.school, size: 44, color: primaryColor),
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
                          schoolName.toUpperCase(),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'P.O. BOX $poBox • TEL: $phone',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          'Email: $email',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Divider(thickness: 2, color: primaryColor.withOpacity(0.3)),
              Container(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primaryColor.withOpacity(0.3)),
                ),
                child: Text(
                  '$termLabel Fees Statement as at ${DateFormat('dd-MMM-yyyy').format(now)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget buildStudentInfo() {
    if (selectedStudent == null) return SizedBox.shrink();
    
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      shadowColor: primaryColor.withOpacity(0.2),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.white, backgroundColor.withOpacity(0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: primaryColor.withOpacity(0.2), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryColor, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: primaryColor.withOpacity(0.1),
                    child: Icon(Icons.person, color: primaryColor, size: 28),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    selectedStudent?['name'] ?? '',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: StudentInfoItem(
                    icon: Icons.class_,
                    label: 'Class',
                    value: selectedStudent?['class'] ?? '',
                  ),
                ),
                Expanded(
                  child: StudentInfoItem(
                    icon: Icons.numbers,
                    label: 'ADM No',
                    value: selectedStudent?['admissionNo'] ?? '',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget StudentInfoItem({required IconData icon, required String label, required String value}) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: primaryColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: primaryColor),
          SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget buildPaymentsTable() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      shadowColor: primaryColor.withOpacity(0.2),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.white, backgroundColor.withOpacity(0.3)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                border: Border(bottom: BorderSide(color: primaryColor.withOpacity(0.3))),
              ),
              child: Row(
                children: [
                  Icon(Icons.receipt_long, color: primaryColor, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Payment History',
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.all(16),
              child: payments.isEmpty 
                  ? _buildEmptyPaymentCard() 
                  : Column(
                      children: payments.map((payment) => _buildPaymentCard(payment)).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyPaymentCard() {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.white, backgroundColor.withOpacity(0.1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: primaryColor.withOpacity(0.1)),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Text(
                      'KES 0.00',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.grey[500],
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: primaryColor),
                        SizedBox(width: 4),
                        Text(
                          'No Date',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _PaymentDetailField(
                        icon: Icons.attach_money,
                        label: 'Amount',
                        value: '0.00',
                        isEmpty: true,
                      ),
                      Divider(height: 16, color: Colors.grey[300]),
                      _PaymentDetailField(
                        icon: Icons.payment,
                        label: 'Payment Mode',
                        value: 'Not specified',
                        isEmpty: true,
                      ),
                      Divider(height: 16, color: Colors.grey[300]),
                      _PaymentDetailField(
                        icon: Icons.badge,
                        label: 'Admission Number',
                        value: 'Not specified',
                        isEmpty: true,
                      ),
                      Divider(height: 16, color: Colors.grey[300]),
                      _PaymentDetailField(
                        icon: Icons.receipt,
                        label: 'Receipt Number',
                        value: 'Not specified',
                        isEmpty: true,
                      ),
                      Divider(height: 16, color: Colors.grey[300]),
                      _PaymentDetailField(
                        icon: Icons.confirmation_number,
                        label: 'Transaction Number',
                        value: 'Not specified',
                        isEmpty: true,
                      ),
                      Divider(height: 16, color: Colors.grey[300]),
                      _PaymentDetailField(
                        icon: Icons.event,
                        label: 'Payment Date',
                        value: 'Not specified',
                        isEmpty: true,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

 Widget _buildPaymentCard(Map<String, dynamic> payment) {
  final amount = double.tryParse(payment['amount']?.toString() ?? '0') ?? 0;
  final formattedAmount = NumberFormat('#,##0.00').format(amount);
  final date = payment['date'] is Timestamp 
      ? DateFormat('yyyy-MM-dd HH:mm:ss').format((payment['date'] as Timestamp).toDate())
      : '';
  
  // Extract payment mode and transaction details
  final paymentMode = payment['mode']?.toString() ?? 'Payment';
  final transactionNo = payment['transactionNumber']?.toString() ?? '';
  final receiptNo = payment['receiptNumber']?.toString() ?? '';
  
  // Create transaction title
  String transactionTitle = paymentMode;
  if (transactionNo.isNotEmpty) {
    transactionTitle += ' - ${transactionNo.length > 10 ? transactionNo.substring(0, 10) + '...' : transactionNo}';
  } else if (receiptNo.isNotEmpty) {
    transactionTitle += ' - ${receiptNo.length > 10 ? receiptNo.substring(0, 10) + '...' : receiptNo}';
  }
  
  return Container(
    margin: EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          blurRadius: 4,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: IntrinsicHeight(
      child: Row(
        children: [
          // Green left border
          Container(
            width: 6,
            decoration: BoxDecoration(
              color: Colors.green[600],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                bottomLeft: Radius.circular(8),
              ),
            ),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  // Left side - Date and transaction details
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date
                        Text(
                          date,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        // Transaction title
                        Text(
                          transactionTitle,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        // Additional date/time
                        Text(
                          date.isNotEmpty ? DateFormat('yyyy-MM-dd HH:mm:ss').format((payment['date'] as Timestamp).toDate()) : '',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Right side - Amount and status
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Amount
                      Text(
                        '${formattedAmount} KES',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[600],
                        ),
                      ),
                      SizedBox(height: 4),
                      // Status
                      Text(
                        'Success',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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

  Widget _PaymentDetailField({
    required IconData icon,
    required String label,
    required String value,
    bool isEmpty = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isEmpty ? Colors.grey[100] : primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon, 
            size: 16, 
            color: isEmpty ? Colors.grey[400] : primaryColor,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: isEmpty ? Colors.grey[50] : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isEmpty ? Colors.grey[200]! : primaryColor.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isEmpty ? FontWeight.normal : FontWeight.w600,
                    color: isEmpty ? Colors.grey[500] : Colors.black87,
                    fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ignore: unused_element
  IconData _getPaymentModeIcon(String payMode) {
    payMode = payMode.toLowerCase();
    
    if (payMode.contains('cash')) {
      return Icons.money;
    } else if (payMode.contains('mpesa') || payMode.contains('mobile')) {
      return Icons.phone_android;
    } else if (payMode.contains('bank') || payMode.contains('slip')) {
      return Icons.account_balance;
    } else if (payMode.contains('card') || payMode.contains('credit') || payMode.contains('debit')) {
      return Icons.credit_card;
    } else if (payMode.contains('cheque') || payMode.contains('check')) {
      return Icons.receipt;
    } else if (payMode.contains('online') || payMode.contains('digital')) {
      return Icons.computer;
    } else if (payMode.contains('prepaid')) {
      return Icons.access_time_filled;
    } else {
      return Icons.payment;
    }
  }
 
  Widget buildTotals() {
    double totalPaid = 0;
    double totalRequired = 0;
    double balance = 0;

    if (selectedStudent != null) {
      final admissionNo = selectedStudent!['admissionNo'] as String;
      
      return FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('schools')
            .doc(widget.schoolCode)
            .collection('payments')
            .where('admissionNo', isEqualTo: admissionNo)
            .where('type', isEqualTo: 'fee summary')
            .get(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            final feeSummary = snapshot.data!.docs.first.data() as Map<String, dynamic>;
            
            if (_selectedTimeFilter == 'yearly') {
              totalRequired = (feeSummary['totalRequired'] as num?)?.toDouble() ?? 0;
              totalPaid = (feeSummary['totalPaid'] as num?)?.toDouble() ?? 0;
              balance = (feeSummary['totalBalance'] as num?)?.toDouble() ?? 0;
            } else {
              totalRequired = (feeSummary['termRequired'] as num?)?.toDouble() ?? 0;
              totalPaid = (feeSummary['termPaid'] as num?)?.toDouble() ?? 0;
              balance = (feeSummary['termBalance'] as num?)?.toDouble() ?? 0;
            }
          }
          
          double paymentPercentage = totalRequired > 0 ? (totalPaid / totalRequired) * 100 : 0;
          if (paymentPercentage > 100) paymentPercentage = 100;
          
          final currencyFormat = NumberFormat('#,##0.00');
          
          return Card(
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            shadowColor: primaryColor.withOpacity(0.2),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [Colors.white, backgroundColor.withOpacity(0.5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.summarize, color: primaryColor, size: 24),
                            SizedBox(width: 12),
                            Text(
                              'Fees Summary',
                              style: TextStyle(
                                fontSize: 18, 
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: primaryColor, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.1),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedTimeFilter,
                              icon: Icon(Icons.arrow_drop_down, color: primaryColor),
                              items: [
                                DropdownMenuItem(value: 'current_term', child: Text('Current Term', style: TextStyle(fontWeight: FontWeight.w500))),
                                DropdownMenuItem(value: 'yearly', child: Text('Yearly', style: TextStyle(fontWeight: FontWeight.w500))),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedTimeFilter = value;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Payment Progress',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${paymentPercentage.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: _getColorForPercentage(paymentPercentage),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: paymentPercentage / 100,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _getColorForPercentage(paymentPercentage),
                            ),
                            minHeight: 12,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: primaryColor.withOpacity(0.2)),
                      ),
                      child: Column(
                        children: [
                          FinanceSummaryItem(
                            icon: Icons.receipt_long,
                            label: _selectedTimeFilter == 'yearly' ? 'Total Required' : 'Term Required',
                            value: currencyFormat.format(totalRequired),
                            valueColor: Colors.black87,
                          ),
                          Divider(color: primaryColor.withOpacity(0.3)),
                          FinanceSummaryItem(
                            icon: Icons.payments,
                            label: _selectedTimeFilter == 'yearly' ? 'Total Paid' : 'Term Paid',
                            value: currencyFormat.format(totalPaid),
                            valueColor: Colors.green[700]!,
                          ),
                          Divider(color: primaryColor.withOpacity(0.3)),
                          FinanceSummaryItem(
                            icon: Icons.account_balance_wallet,
                            label: 'Balance',
                            value: currencyFormat.format(balance),
                            valueColor: balance > 0 ? Colors.red[700]! : Colors.green[700]!,
                            isBold: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }
    
    return SizedBox.shrink();
  }

  Color _getColorForPercentage(double percentage) {
    if (percentage >= 100) return Colors.green[700]!;
    if (percentage >= 75) return Colors.green[600]!;
    if (percentage >= 50) return Colors.orange;
    if (percentage >= 25) return Colors.orange[700]!;
    return Colors.red[700]!;
  }

  Widget FinanceSummaryItem({
    required IconData icon, 
    required String label, 
    required String value, 
    required Color valueColor,
    bool isBold = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: primaryColor),
          ),
          SizedBox(width: 16),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
          Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget buildSignature() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      shadowColor: primaryColor.withOpacity(0.1),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.white, backgroundColor.withOpacity(0.3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Certified By:',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Image.asset(
                    'assets/stamp.png',
                    height: 50,
                    errorBuilder: (context, error, stackTrace) => 
                        Container(
                          width: 50, 
                          height: 50,
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.verified, color: primaryColor),
                        ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Container(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      principalName.isNotEmpty ? principalName : 'PRINCIPAL',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: primaryColor,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'School Principal',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),
              Divider(color: primaryColor.withOpacity(0.3), thickness: 1),
              SizedBox(height: 8),
              Text(
                'This is a computer-generated statement and does not require physical signature.',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget buildProfileSection() {
    if (parentData == null) return SizedBox.shrink();
    
    return Container(
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
    );
  }
  
  Future<void> _generatePDF() async {
    final pdf = pw.Document();
    
    final font = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.nunitoBold();
    
    double totalPaid = 0;
    double totalRequired = 0;
    double balance = 0;
    
    if (_selectedTimeFilter == 'yearly' && payments.isNotEmpty) {
      final feeSummary = payments.first;
      totalRequired = (feeSummary['totalRequired'] as num?)?.toDouble() ?? 0;
      totalPaid = (feeSummary['totalPaid'] as num?)?.toDouble() ?? 0;
      balance = (feeSummary['totalBalance'] as num?)?.toDouble() ?? 0;
    } else if (_selectedTimeFilter != 'yearly') {
      totalPaid = payments.fold(0, (sum, item) {
        final amount = double.tryParse(item['amount']?.toString() ?? '0') ?? 0;
        return sum + amount;
      });
      
      if (selectedStudentId != null) {
        final feeSummaryQuery = await FirebaseFirestore.instance
          .collection('schools').doc(widget.schoolCode)
          .collection('payments')
          .where('admissionNo', isEqualTo: selectedStudent!['admissionNo'])
          .where('type', isEqualTo: 'fee summary')
          .get();
        
        if (feeSummaryQuery.docs.isNotEmpty) {
          final feeSummary = feeSummaryQuery.docs.first.data();
          totalRequired = (feeSummary['termRequired'] as num?)?.toDouble() ?? 0;
        }
        
        balance = totalRequired - totalPaid;
      }
    }
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      schoolName.toUpperCase(),
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 18,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'P.O. BOX $poBox    TEL: $phone    Email: $email',
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 10,
                      ),
                    ),
                    pw.SizedBox(height: 16),
                    pw.Text(
                      'Fees Statement as at ${DateFormat('dd-MMM-yyyy').format(DateTime.now())}',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Container(
                padding: pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Student Name: ${selectedStudent?['name'] ?? ''}', style: pw.TextStyle(font: font)),
                    pw.Text('Class: ${selectedStudent?['class'] ?? ''}', style: pw.TextStyle(font: font)),
                    pw.Text('ADM No: ${selectedStudent?['admissionNo'] ?? ''}', style: pw.TextStyle(font: font)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: pw.FlexColumnWidth(1),
                  1: pw.FlexColumnWidth(1),
                  2: pw.FlexColumnWidth(1),
                  3: pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#f0f0f0'),
                    ),
                    children: [
                      pw.Padding(
                        padding: pw.EdgeInsets.all(5),
                        child: pw.Text('Date', style: pw.TextStyle(font: fontBold)),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(5),
                        child: pw.Text('Amount', style: pw.TextStyle(font: fontBold)),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(5),
                        child: pw.Text('Pay Mode', style: pw.TextStyle(font: fontBold)),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(5),
                        child: pw.Text('Receipt No', style: pw.TextStyle(font: fontBold)),
                      ),
                    ],
                  ),
                  ...payments.map((payment) {
                    final amount = double.tryParse(payment['amount']?.toString() ?? '0') ?? 0;
                    final formattedAmount = NumberFormat('#,##0.00').format(amount);
                    final date = payment['date'] is Timestamp 
                        ? DateFormat('dd MMM yyyy').format((payment['date'] as Timestamp).toDate())
                        : '';
                    
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: pw.EdgeInsets.all(5),
                          child: pw.Text(date, style: pw.TextStyle(font: font)),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(5),
                          child: pw.Text(formattedAmount, style: pw.TextStyle(font: font)),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(5),
                          child: pw.Text(payment['mode'] ?? '', style: pw.TextStyle(font: font)),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(5),
                          child: pw.Text(payment['receiptNumber'] ?? '', style: pw.TextStyle(font: font)),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Container(
                padding: pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Total Required: ${NumberFormat('#,##0.00').format(totalRequired)}', style: pw.TextStyle(font: font)),
                    pw.Text('Total Paid: ${NumberFormat('#,##0.00').format(totalPaid)}', style: pw.TextStyle(font: font)),
                    pw.Text('Balance: ${NumberFormat('#,##0.00').format(balance)}', style: pw.TextStyle(font: fontBold)),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),
              pw.Container(
                alignment: pw.Alignment.bottomRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Divider(),
                    pw.Text('Certified By:', style: pw.TextStyle(font: font)),
                    pw.SizedBox(height: 5),
                    pw.Text(principalName.isNotEmpty ? principalName : 'PRINCIPAL', style: pw.TextStyle(font: fontBold)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
    
    await Printing.layoutPdf(
      onLayout: (format) => pdf.save(),
    );
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
        title: Text('Fees Statement', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        elevation: 0,
        actions: [
          buildProfileSection(),
          IconButton(
            icon: Icon(Icons.picture_as_pdf, color: Colors.white),
            onPressed: _generatePDF,
            tooltip: 'Export to PDF',
          ),
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (context) => StatementOptions(
                  onRefresh: fetchData,
                  onExportPdf: _generatePDF,
                ),
              );
            },
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
                Text('Loading statement data...', style: TextStyle(color: primaryColor, fontWeight: FontWeight.w500)),
              ],
            ),
          )
        : students.isEmpty
          ? EmptyStateWidget(
              icon: Icons.school,
              title: 'No Students Found',
              message: 'There are no students linked to this account.',
              buttonText: 'Refresh',
              onButtonPressed: fetchData,
            )
          : RefreshIndicator(
              onRefresh: fetchData,
              color: primaryColor,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    buildHeader(),
                    SizedBox(height: 16),
                    if (students.length > 1)
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: [Colors.white, backgroundColor.withOpacity(0.5)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedStudentId,
                                isExpanded: true,
                                icon: Icon(Icons.keyboard_arrow_down, color: primaryColor),
                                hint: Text('Select Student', style: TextStyle(fontWeight: FontWeight.w500)),
                                items: students.map((student) {
                                  return DropdownMenuItem<String>(
                                    value: student['id'],
                                    child: Row(
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(color: primaryColor, width: 1),
                                          ),
                                          child: CircleAvatar(
                                            radius: 16,
                                            backgroundColor: primaryColor.withOpacity(0.1),
                                            child: Text(
                                              (student['name'] ?? '').isNotEmpty ? student['name'][0].toUpperCase() : 'S',
                                              style: TextStyle(
                                                color: primaryColor,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 14),
                                        Text(student['name'], style: TextStyle(fontWeight: FontWeight.w500)),
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
                                    _filterPayments();
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    SizedBox(height: 16),
                    buildStudentInfo(),
                    SizedBox(height: 16),
                    buildTotals(),
                    SizedBox(height: 16),
                    buildPaymentsTable(),
                    SizedBox(height: 16),
                    buildSignature(),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _generatePDF,
        backgroundColor: accentColor,
        tooltip: 'Download PDF Statement',
        child: Icon(Icons.download, color: Colors.white),
      ),
    );
  }
}

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String buttonText;
  final VoidCallback onButtonPressed;
  
  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.buttonText,
    required this.onButtonPressed,
  });
  
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFFB45309).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 80,
                color: Color(0xFFB45309),
              ),
            ),
            SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFFB45309),
              ),
            ),
            SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: onButtonPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFB45309),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: Text(buttonText, style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class StatementOptions extends StatelessWidget {
  final VoidCallback onRefresh;
  final VoidCallback onExportPdf;
  
  const StatementOptions({
    super.key,
    required this.onRefresh,
    required this.onExportPdf,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          _OptionTile(
            icon: Icons.refresh,
            title: 'Refresh Data',
            onTap: () {
              Navigator.pop(context);
              onRefresh();
            },
          ),
          _OptionTile(
            icon: Icons.picture_as_pdf,
            title: 'Export to PDF',
            onTap: () {
              Navigator.pop(context);
              onExportPdf();
            },
          ),
          _OptionTile(
            icon: Icons.share,
            title: 'Share Statement',
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Sharing functionality coming soon'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Color(0xFFB45309),
                ),
              );
            },
          ),
          _OptionTile(
            icon: Icons.print,
            title: 'Print Statement',
            onTap: () {
              Navigator.pop(context);
              onExportPdf();
            },
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  
  const _OptionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Color(0xFFB45309).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Color(0xFFB45309)),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
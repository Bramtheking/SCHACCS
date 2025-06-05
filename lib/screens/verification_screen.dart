// lib/screens/verification_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:schaccs/screens/login_screen.dart';
import 'package:schaccs/screens/registration_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VerificationScreen extends StatefulWidget {
  static const String routeName = '/verify';
  final String schoolCode;

  const VerificationScreen({super.key, required this.schoolCode});

  @override
  _VerificationScreenState createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _admissionController = TextEditingController();
  bool _loading = false;
  String? _errorText;
  List<String> _previousPhones = [];
  List<String> _previousAdmissions = [];
  bool _showPhoneSuggestions = false;
  bool _showAdmissionSuggestions = false;

  // Define custom colors
  final Color primaryColor = Color(0xFFB25900); // Orange-brown
  final Color secondaryColor = Color(0xFFF0E6DD); // Light orange-brown tint
  final Color backgroundColor = Color(0xFFFFF8F2); // Very light orange-brown tint
  final Color textPrimaryColor = Color(0xFF4A3328); // Dark brown/blackish
  final Color textSecondaryColor = Color(0xFF8C7B75); // Greyish with hint of brown
  final Color accentColor = Color(0xFFE67E22); // Brighter orange for accents

  @override
  void initState() {
    super.initState();
    _loadPreviousInputs();
  }

  Future<void> _loadPreviousInputs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _previousPhones = prefs.getStringList('previous_phones') ?? [];
      _previousAdmissions = prefs.getStringList('previous_admissions') ?? [];
    });
  }

  Future<void> _savePreviousInput(String type, String value) async {
    if (value.isEmpty) return;
    
    final prefs = await SharedPreferences.getInstance();
    
    if (type == 'phone') {
      final phones = prefs.getStringList('previous_phones') ?? [];
      if (!phones.contains(value)) {
        phones.insert(0, value);
        if (phones.length > 5) phones.removeLast(); // Keep only latest 5
        await prefs.setStringList('previous_phones', phones);
        setState(() {
          _previousPhones = phones;
        });
      }
    } else if (type == 'admission') {
      final admissions = prefs.getStringList('previous_admissions') ?? [];
      if (!admissions.contains(value)) {
        admissions.insert(0, value);
        if (admissions.length > 5) admissions.removeLast(); // Keep only latest 5
        await prefs.setStringList('previous_admissions', admissions);
        setState(() {
          _previousAdmissions = admissions;
        });
      }
    }
  }

  Future<void> _verify() async {
    final phone = _phoneController.text.trim();
    final admission = _admissionController.text.trim();

    if (phone.isEmpty || admission.isEmpty) {
      setState(() => _errorText = 'All fields are required');
      return;
    }

    setState(() {
      _loading = true;
      _errorText = null;
    });

    // Save inputs for future suggestions
    await _savePreviousInput('phone', phone);
    await _savePreviousInput('admission', admission);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolCode)
          .collection('students')
          .where('parentPhone', isEqualTo: phone)
          .where('admissionNo', isEqualTo: admission)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RegistrationScreen(schoolCode: widget.schoolCode,
        verifiedAdmissionNo: admission, // Pass the verified admission number
        verifiedPhone: phone,),
          ),
        );
      } else {
        setState(() => _errorText = 'Verification failed');
      }
    } catch (e) {
      setState(() => _errorText = 'Error during verification');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _admissionController.dispose();
    super.dispose();
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
    'Student Verification',
    style: TextStyle(
      color: textPrimaryColor,
      fontWeight: FontWeight.w600,
      fontSize: 18,
      letterSpacing: 0.3,
    ),
  ),
  backgroundColor: primaryColor,
  elevation: 2,
  iconTheme: IconThemeData(color: Colors.white),
),

      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text(
              'Verify Your Details',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textPrimaryColor,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Please enter the phone number and admission number registered with the school',
              style: TextStyle(
                fontSize: 14,
                color: textSecondaryColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            if (_errorText != null)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Text(
                  _errorText!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),
            const SizedBox(height: 24),
            Text(
              'Phone Number',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textPrimaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Stack(
              children: [
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(
                    color: textPrimaryColor,
                    fontSize: 16,
                  ),
                  onTap: () {
                    if (_previousPhones.isNotEmpty) {
                      setState(() {
                        _showPhoneSuggestions = true;
                        _showAdmissionSuggestions = false;
                      });
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Enter parent\'s phone number',
                    hintStyle: TextStyle(color: textSecondaryColor.withOpacity(0.7), fontSize: 15),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: Icon(Icons.phone, color: primaryColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: primaryColor, width: 1.5),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
                if (_showPhoneSuggestions && _previousPhones.isNotEmpty)
                  Positioned(
                    top: 56,
                    left: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: _previousPhones.map((phone) {
                          return InkWell(
                            onTap: () {
                              _phoneController.text = phone;
                              setState(() {
                                _showPhoneSuggestions = false;
                              });
                            },
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey.shade200,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Text(
                                phone,
                                style: TextStyle(
                                  color: textPrimaryColor,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Admission Number',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textPrimaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Stack(
              children: [
                TextField(
                  controller: _admissionController,
                  style: TextStyle(
                    color: textPrimaryColor,
                    fontSize: 16,
                  ),
                  onTap: () {
                    if (_previousAdmissions.isNotEmpty) {
                      setState(() {
                        _showAdmissionSuggestions = true;
                        _showPhoneSuggestions = false;
                      });
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Enter student\'s admission number',
                    hintStyle: TextStyle(color: textSecondaryColor.withOpacity(0.7), fontSize: 15),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: Icon(Icons.confirmation_number, color: primaryColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: primaryColor, width: 1.5),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
                if (_showAdmissionSuggestions && _previousAdmissions.isNotEmpty)
                  Positioned(
                    top: 56,
                    left: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: _previousAdmissions.map((admission) {
                          return InkWell(
                            onTap: () {
                              _admissionController.text = admission;
                              setState(() {
                                _showAdmissionSuggestions = false;
                              });
                            },
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey.shade200,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Text(
                                admission,
                                style: TextStyle(
                                  color: textPrimaryColor,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _loading ? null : _verify,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 1,
                ),
                child: _loading
                    ? SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        'VERIFY DETAILS',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                setState(() {
                  _showPhoneSuggestions = false;
                  _showAdmissionSuggestions = false;
                });
              },
              child: Container(
                color: Colors.transparent,
                height: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
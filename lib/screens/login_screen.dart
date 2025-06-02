import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:schaccs/screens/school_code_screen.dart';
import 'package:schaccs/screens/verification_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';

class LoginScreen extends StatefulWidget {
  static const String routeName = '/login';
  final String schoolCode;

  const LoginScreen({super.key, required this.schoolCode});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  bool _loading = false;
  String? _errorText;

  // For email suggestions from Hive
  List<String> _recentEmails = [];
  bool _showEmailSuggestions = false;
  late Box<String> _emailsBox;
  bool _hiveInitialized = false; // Add this flag

  // Define our custom colors
  final Color primaryColor = Color(0xFFB25900); // Orange-brown
  final Color secondaryColor = Color(0xFFD98841); // Lighter orange-brown
  final Color bgColor = Color(0xFFFFF8F2); // Very light orange-brown tint
  final Color textPrimaryColor = Color(0xFF4A4A4A); // Dark grey for primary text
  final Color textSecondaryColor = Color(0xFF888888); // Medium grey for secondary text

  @override
  void initState() {
    super.initState();
    _initHive();
    _emailFocusNode.addListener(_onEmailFocusChange);
  }

  @override
  void dispose() {
    _emailFocusNode.removeListener(_onEmailFocusChange);
    _emailFocusNode.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onEmailFocusChange() {
    // Show suggestions when field gains focus and we have emails OR when Hive is initialized
    if (_emailFocusNode.hasFocus && _hiveInitialized) {
      setState(() {
        _showEmailSuggestions = _recentEmails.isNotEmpty;
      });
    } else if (!_emailFocusNode.hasFocus) {
      // Hide suggestions when field loses focus (with small delay to allow taps)
      Future.delayed(Duration(milliseconds: 150), () {
        if (!_emailFocusNode.hasFocus) {
          setState(() {
            _showEmailSuggestions = false;
          });
        }
      });
    }
  }

  // Initialize Hive box for emails
  Future<void> _initHive() async {
    try {
      _emailsBox = await Hive.openBox<String>('recent_emails_${widget.schoolCode}');
      _loadRecentEmails();
      setState(() {
        _hiveInitialized = true;
      });
    } catch (e) {
      print('Error initializing Hive: $e');
      setState(() {
        _hiveInitialized = true; // Set to true even on error to prevent blocking
      });
    }
  }

  // Load recent emails from Hive
  void _loadRecentEmails() {
    if (_emailsBox.isOpen) {
      setState(() {
        _recentEmails = _emailsBox.values.toList();
      });
    }
  }

  // Save a new email to Hive
  Future<void> _saveRecentEmail(String email) async {
    if (email.isEmpty || !_emailsBox.isOpen) return;
    
    try {
      // Get current emails
      List<String> emails = _emailsBox.values.toList();
      
      // Remove the email if it already exists (to avoid duplicates)
      emails.remove(email);
      
      // Add the new email at the beginning
      emails.insert(0, email);
      
      // Limit to maximum 5 recent emails
      if (emails.length > 5) {
        emails = emails.take(5).toList();
      }
      
      // Clear the box and save updated list
      await _emailsBox.clear();
      for (int i = 0; i < emails.length; i++) {
        await _emailsBox.put(i, emails[i]);
      }
      
      // Update the state
      setState(() {
        _recentEmails = emails;
      });
    } catch (e) {
      print('Error saving recent email: $e');
    }
  }

  void _selectEmailSuggestion(String email) {
    _emailController.text = email;
    setState(() {
      _showEmailSuggestions = false;
    });
    // Don't unfocus immediately, let user continue to password field naturally
  }

  void _hideEmailSuggestions() {
    setState(() {
      _showEmailSuggestions = false;
    });
  }

  void _toggleEmailSuggestions() {
    if (_hiveInitialized && _recentEmails.isNotEmpty) {
      setState(() {
        _showEmailSuggestions = !_showEmailSuggestions;
      });
      if (_showEmailSuggestions) {
        _emailFocusNode.requestFocus();
      }
    }
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _errorText = null;
      _showEmailSuggestions = false;
    });

    final email = _emailController.text.trim();
    final pass = _passwordController.text;
    final code = widget.schoolCode;
    print('🔑 Login attempt: email=$email, schoolCode=$code');

    try {
      // 1) Super-Admin check under schools/supermaster/admins
      final superSnap = await FirebaseFirestore.instance
          .collection('schools')
          .doc('supermaster')
          .collection('admins')
          .where('email', isEqualTo: email)
          .where('password', isEqualTo: pass)
          .limit(1)
          .get();

      if (superSnap.docs.isNotEmpty) {
        print('🚀 Super-Admin login succeeded');
        await _saveRecentEmail(email); // Save email before navigating
        Navigator.pushReplacementNamed(context, '/super-admin-dashboard');
        return;
      }

      // 2) School-Admin check under schools/{schoolCode}/admins
      final adminSnap = await FirebaseFirestore.instance
          .collection('schools')
          .doc(code)
          .collection('admins')
          .where('email', isEqualTo: email)
          .where('password', isEqualTo: pass)
          .limit(1)
          .get();

      if (adminSnap.docs.isNotEmpty) {
        print('🚀 School-Admin login succeeded');
        await _saveRecentEmail(email); // Save email before navigating
        Navigator.pushReplacementNamed(
          context,
          '/admin',
          arguments: {
            'school': code,
            'adminDocId': adminSnap.docs.first.id,
          },
        );
        return;
      }

      // 3) Parent check under schools/{schoolCode}/parents
      final parentSnap = await FirebaseFirestore.instance
          .collection('schools')
          .doc(code)
          .collection('parents')
          .where('email', isEqualTo: email)
          .where('password', isEqualTo: pass)
          .limit(1)
          .get();

      if (parentSnap.docs.isNotEmpty) {
        print('🚀 Parent login succeeded');
        await _saveRecentEmail(email); // Save email before navigating
        Navigator.pushReplacementNamed(
          context,
          '/statement',
          arguments: {
            'school': code,
            'parentDocId': parentSnap.docs.first.id,
            'email': email,
          },
        );
        return;
      }

      // 4) No match found
      print('❌ No user found in any role collection');
      setState(() => _errorText = 'Invalid email or password for this school.');
    } catch (e) {
      print('❌ Login error: $e');
      setState(() => _errorText = 'Login error: $e');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.schoolCode;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 2,
        iconTheme: IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pushNamedAndRemoveUntil(
              SchoolCodeScreen.routeName, // clean and uses your defined constant
              (Route<dynamic> route) => false,
            );
          },
        ),
        title: Text(
          'Sign In',
          style: GoogleFonts.workSans(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: GestureDetector(
        onTap: _hideEmailSuggestions,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),
              Text(
                'Welcome Back',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: textPrimaryColor,
                ),
              ),
              Text(
                'Sign in to continue',
                style: GoogleFonts.workSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: textSecondaryColor,
                ),
              ),
              if (_errorText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorText!,
                            style: GoogleFonts.workSans(
                              color: Colors.red[700],
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 30),
              
              // Email Field with dropdown suggestions
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Email Address',
                    style: GoogleFonts.workSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Stack(
                    children: [
                      Column(
                        children: [
                          TextField(
                            controller: _emailController,
                            focusNode: _emailFocusNode,
                            style: GoogleFonts.workSans(color: textPrimaryColor),
                            onChanged: (value) {
                              // Hide suggestions when user is typing
                              if (_showEmailSuggestions) {
                                setState(() {
                                  _showEmailSuggestions = false;
                                });
                              }
                            },
                            onTap: () {
                              // Show suggestions when tapping the field (if we have emails)
                              if (_hiveInitialized && _recentEmails.isNotEmpty) {
                                setState(() {
                                  _showEmailSuggestions = true;
                                });
                              }
                            },
                            decoration: InputDecoration(
                              fillColor: Colors.white,
                              filled: true,
                              hintText: 'Enter your email',
                              hintStyle: GoogleFonts.workSans(color: Colors.grey[400]),
                              prefixIcon: Icon(Icons.email_outlined, color: secondaryColor),
                              suffixIcon: _hiveInitialized && _recentEmails.isNotEmpty
                                  ? GestureDetector(
                                      onTap: _toggleEmailSuggestions,
                                      child: Icon(
                                        _showEmailSuggestions
                                            ? Icons.keyboard_arrow_up
                                            : Icons.keyboard_arrow_down,
                                        color: secondaryColor,
                                      ),
                                    )
                                  : null,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: secondaryColor),
                              ),
                            ),
                          ),
                          if (_showEmailSuggestions && _recentEmails.isNotEmpty)
                            Container(
                              width: double.infinity,
                              margin: EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.1),
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                padding: EdgeInsets.symmetric(vertical: 4),
                                itemCount: _recentEmails.length,
                                itemBuilder: (context, index) {
                                  final email = _recentEmails[index];
                                  return InkWell(
                                    onTap: () => _selectEmailSuggestion(email),
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      child: Row(
                                        children: [
                                          Icon(Icons.history, size: 16, color: Colors.grey[600]),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              email,
                                              style: GoogleFonts.workSans(
                                                fontSize: 14,
                                                color: textPrimaryColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  
                  // Show helper text if there are recent emails
                  if (_hiveInitialized && _recentEmails.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Tap the field or arrow to see recent emails',
                        style: GoogleFonts.workSans(
                          fontSize: 12,
                          color: textSecondaryColor,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Password Field
              Text(
                'Password',
                style: GoogleFonts.workSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: textPrimaryColor,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: GoogleFonts.workSans(color: textPrimaryColor),
                decoration: InputDecoration(
                  fillColor: Colors.white,
                  filled: true,
                  hintText: 'Enter your password',
                  hintStyle: GoogleFonts.workSans(color: Colors.grey[400]),
                  prefixIcon: Icon(Icons.lock_outline, color: secondaryColor),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: secondaryColor, width: 1.5),
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                ),
              ),
              const SizedBox(height: 36),
              
              // Login Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    disabledBackgroundColor: primaryColor.withOpacity(0.6),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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
                          'Login',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Verification Link
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pushReplacementNamed(
                    context,
                    VerificationScreen.routeName,
                    arguments: code,
                  ),
                  child: Text(
                    'Verify with phone & admission number',
                    style: GoogleFonts.workSans(
                      color: secondaryColor,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
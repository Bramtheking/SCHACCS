import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schaccs/screens/verification_screen.dart';

class RegistrationScreen extends StatefulWidget {
  static const String routeName = '/register';
  final String schoolCode;

  const RegistrationScreen({super.key, required this.schoolCode});

  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  
  bool _loading = false;
  String? _error;
  
  // For field validation
  final Map<String, String?> _fieldErrors = {
    'name': null,
    'email': null,
    'city': null,
    'password': null,
    'confirm': null,
  };
  
  // Password visibility toggles
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  
  // Define our custom colors - keeping consistent with other screens
  final Color primaryColor = Color(0xFFB25900); // Orange-brown
  final Color secondaryColor = Color(0xFFD98841); // Lighter orange-brown
  final Color bgColor = Color(0xFFFFF8F2); // Very light orange-brown tint
  final Color textPrimaryColor = Color(0xFF4A4A4A); // Dark grey for primary text
  final Color textSecondaryColor = Color(0xFF888888); // Medium grey for secondary text
  final Color successColor = Color(0xFF2E7D32); // Green for success messages
  
  // Form validation
  void _validateField(String field) {
    switch (field) {
      case 'name':
        if (_nameCtrl.text.trim().isEmpty) {
          _fieldErrors['name'] = 'Name is required';
        } else if (_nameCtrl.text.trim().length < 3) {
          _fieldErrors['name'] = 'Name must be at least 3 characters';
        } else {
          _fieldErrors['name'] = null;
        }
        break;
        
      case 'email':
        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
        if (_emailCtrl.text.trim().isEmpty) {
          _fieldErrors['email'] = 'Email is required';
        } else if (!emailRegex.hasMatch(_emailCtrl.text.trim())) {
          _fieldErrors['email'] = 'Enter a valid email address';
        } else {
          _fieldErrors['email'] = null;
        }
        break;
        
      case 'city':
        if (_cityCtrl.text.trim().isEmpty) {
          _fieldErrors['city'] = 'City is required';
        } else {
          _fieldErrors['city'] = null;
        }
        break;
        
      case 'password':
        if (_passCtrl.text.isEmpty) {
          _fieldErrors['password'] = 'Password is required';
        } else if (_passCtrl.text.length < 6) {
          _fieldErrors['password'] = 'Password must be at least 6 characters';
        } else {
          _fieldErrors['password'] = null;
        }
        // Also validate confirm password if it has a value
        if (_confirmCtrl.text.isNotEmpty) {
          _validateField('confirm');
        }
        break;
        
      case 'confirm':
        if (_confirmCtrl.text.isEmpty) {
          _fieldErrors['confirm'] = 'Please confirm your password';
        } else if (_confirmCtrl.text != _passCtrl.text) {
          _fieldErrors['confirm'] = 'Passwords don\'t match';
        } else {
          _fieldErrors['confirm'] = null;
        }
        break;
    }
    
    // Trigger UI update
    setState(() {});
  }
  
  bool _validateAllFields() {
    _validateField('name');
    _validateField('email');
    _validateField('city');
    _validateField('password');
    _validateField('confirm');
    
    // Check if any field has an error
    return !_fieldErrors.values.any((error) => error != null);
  }

  Future<void> _register() async {
    // Validate all fields
    if (!_validateAllFields()) {
      setState(() => _error = 'Please correct the errors in the form');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final parentsColl = FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolCode)
          .collection('parents');

      // Using email as unique ID is safer than name
      final docRef = parentsColl.doc();

      await docRef.set({
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'password': _passCtrl.text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      Navigator.pushReplacementNamed(
        context,
        '/statement',
        arguments: {
          'school': widget.schoolCode,
          'parentDocId': docRef.id,
          'email': _emailCtrl.text.trim(),
        },
      );
    } catch (e) {
      setState(() => _error = 'Registration failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
    appBar: AppBar(
  leading: IconButton(
    icon: Icon(Icons.arrow_back, color: Colors.white),
    onPressed: () {
      Navigator.of(context).pushReplacementNamed(
        VerificationScreen.routeName,
        arguments: widget.schoolCode,  // <-- pass the schoolCode String here
      );
    },
  ),
  title: Text('Create Account', /* … */),
  backgroundColor: primaryColor,
  elevation: 2,
  iconTheme: IconThemeData(color: Colors.white),
),


      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Registration Header
                  Text(
                    'Complete Registration',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: textPrimaryColor,
                    ),
                  ),
                  Text(
                    'Create your parent account for ${widget.schoolCode}',
                    style: GoogleFonts.workSans(
                      fontSize: 16,
                      color: textSecondaryColor,
                    ),
                  ),
                  
                  // Error message display
                  if (_error != null)
                    Container(
                      margin: EdgeInsets.only(top: 16),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _error!,
                              style: GoogleFonts.workSans(
                                color: Colors.red[700],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  SizedBox(height: 24),
                  
                  // Registration Form
                  _buildFormField(
                    controller: _nameCtrl,
                    label: 'Full Name',
                    hint: 'Enter your full name',
                    icon: Icons.person_outline,
                    onChanged: (val) => _validateField('name'),
                    errorText: _fieldErrors['name'],
                  ),
                  
                  _buildFormField(
                    controller: _emailCtrl,
                    label: 'Email Address',
                    hint: 'Enter your email address',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (val) => _validateField('email'),
                    errorText: _fieldErrors['email'],
                  ),
                  
                  _buildFormField(
                    controller: _cityCtrl,
                    label: 'City',
                    hint: 'Enter your city',
                    icon: Icons.location_city_outlined,
                    onChanged: (val) => _validateField('city'),
                    errorText: _fieldErrors['city'],
                  ),
                  
                  _buildFormField(
                    controller: _passCtrl,
                    label: 'Password',
                    hint: 'Create a password',
                    icon: Icons.lock_outline,
                    obscureText: !_passwordVisible,
                    onChanged: (val) => _validateField('password'),
                    errorText: _fieldErrors['password'],
                    suffixIcon: IconButton(
                      icon: Icon(
                        _passwordVisible ? Icons.visibility_off : Icons.visibility,
                        color: secondaryColor,
                      ),
                      onPressed: () {
                        setState(() {
                          _passwordVisible = !_passwordVisible;
                        });
                      },
                    ),
                  ),
                  
                  _buildFormField(
                    controller: _confirmCtrl,
                    label: 'Confirm Password',
                    hint: 'Confirm your password',
                    icon: Icons.lock_outline,
                    obscureText: !_confirmPasswordVisible,
                    onChanged: (val) => _validateField('confirm'),
                    errorText: _fieldErrors['confirm'],
                    suffixIcon: IconButton(
                      icon: Icon(
                        _confirmPasswordVisible ? Icons.visibility_off : Icons.visibility,
                        color: secondaryColor,
                      ),
                      onPressed: () {
                        setState(() {
                          _confirmPasswordVisible = !_confirmPasswordVisible;
                        });
                      },
                    ),
                  ),
                  
                  SizedBox(height: 32),
                  
                  // Password strength indicator
                  if (_passCtrl.text.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Password Strength',
                          style: GoogleFonts.workSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: textPrimaryColor,
                          ),
                        ),
                        SizedBox(height: 8),
                        _buildPasswordStrengthIndicator(_passCtrl.text),
                        SizedBox(height: 24),
                      ],
                    ),
                  
                  // Register Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _register,
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
                              'Create Account',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ),
                  ),
                  
                  // Terms & Privacy
                  Container(
                    margin: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'By registering, you agree to our Terms of Service and Privacy Policy',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.workSans(
                          color: textSecondaryColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Function(String)? onChanged,
    String? errorText,
    Widget? suffixIcon,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.workSans(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: textPrimaryColor,
            ),
          ),
          SizedBox(height: 8),
          TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: GoogleFonts.workSans(color: textPrimaryColor),
            onChanged: onChanged,
            decoration: InputDecoration(
              fillColor: Colors.white,
              filled: true,
              hintText: hint,
              hintStyle: GoogleFonts.workSans(color: Colors.grey[400]),
              prefixIcon: Icon(icon, color: secondaryColor),
              suffixIcon: suffixIcon,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: secondaryColor, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.red[400]!, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.red[400]!, width: 1.5),
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              errorText: errorText,
              errorStyle: GoogleFonts.workSans(
                color: Colors.red[700],
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPasswordStrengthIndicator(String password) {
    // Calculate password strength
    int strength = 0;
    
    if (password.length >= 8) strength++;
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    if (password.contains(RegExp(r'[a-z]'))) strength++;
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength++;
    
    // Define strength level
    String strengthText;
    Color strengthColor;
    double strengthPercentage = strength / 5;
    
    if (strength <= 1) {
      strengthText = 'Weak';
      strengthColor = Colors.red;
    } else if (strength <= 3) {
      strengthText = 'Medium';
      strengthColor = Colors.orange;
    } else {
      strengthText = 'Strong';
      strengthColor = successColor;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Strength bar
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(3),
          ),
          child: Row(
            children: [
              Container(
                width: MediaQuery.of(context).size.width * 0.8 * strengthPercentage,
                decoration: BoxDecoration(
                  color: strengthColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        // Strength text
        Row(
          children: [
            Text(
              strengthText,
              style: GoogleFonts.workSans(
                color: strengthColor,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            SizedBox(width: 8),
            if (strength <= 3)
              Text(
                'Add ${strength <= 1 ? 'uppercase, lowercase, numbers, and symbols' : strength <= 2 ? 'more character types' : 'more complexity'}',
                style: GoogleFonts.workSans(
                  color: textSecondaryColor,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
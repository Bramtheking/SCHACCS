// lib/screens/school_code_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:schaccs/screens/login_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class SchoolCodeScreen extends StatefulWidget {
  static const String routeName = '/school-code';
  const SchoolCodeScreen({super.key});

  @override
  _SchoolCodeScreenState createState() => _SchoolCodeScreenState();
}

class _SchoolCodeScreenState extends State<SchoolCodeScreen> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _loading = false;
  String? _errorText;
  
  // List to store recently used school codes from Hive
  List<String> _recentCodes = [];
  bool _showCodeSuggestions = false;
  late Box<String> _codesBox;
  bool _hiveInitialized = false; // Add this flag

  // Define our custom colors - keeping consistent with login screen
  final Color primaryColor = Color(0xFFB25900); // Orange-brown
  final Color secondaryColor = Color(0xFFD98841); // Lighter orange-brown
  final Color bgColor = Color(0xFFFFF8F2); // Very light orange-brown tint
  final Color textPrimaryColor = Color(0xFF4A4A4A); // Dark grey for primary text
  final Color textSecondaryColor = Color(0xFF888888); // Medium grey for secondary text

  @override
  void initState() {
    super.initState();
    _initHive();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    // Show suggestions when field gains focus and we have codes OR when Hive is initialized
    if (_focusNode.hasFocus && _hiveInitialized) {
      setState(() {
        _showCodeSuggestions = _recentCodes.isNotEmpty;
      });
    } else if (!_focusNode.hasFocus) {
      // Hide suggestions when field loses focus (with small delay to allow taps)
      Future.delayed(Duration(milliseconds: 150), () {
        if (!_focusNode.hasFocus) {
          setState(() {
            _showCodeSuggestions = false;
          });
        }
      });
    }
  }

  // Initialize Hive box
  Future<void> _initHive() async {
    try {
      _codesBox = await Hive.openBox<String>('recent_school_codes');
      _loadRecentCodes();
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

  // Load recent codes from Hive
  void _loadRecentCodes() {
    if (_codesBox.isOpen) {
      setState(() {
        _recentCodes = _codesBox.values.toList();
      });
    }
  }

  // Save a new code to Hive
  Future<void> _saveRecentCode(String code) async {
    if (code.isEmpty || !_codesBox.isOpen) return;
    
    try {
      // Get current codes
      List<String> codes = _codesBox.values.toList();
      
      // Remove the code if it already exists (to avoid duplicates)
      codes.remove(code);
      
      // Add the new code at the beginning
      codes.insert(0, code);
      
      // Limit to maximum 5 recent codes
      if (codes.length > 5) {
        codes = codes.take(5).toList();
      }
      
      // Clear the box and save updated list
      await _codesBox.clear();
      for (int i = 0; i < codes.length; i++) {
        await _codesBox.put(i, codes[i]);
      }
      
      // Update the state
      setState(() {
        _recentCodes = codes;
      });
    } catch (e) {
      print('Error saving recent code: $e');
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _errorText = 'Please enter your school code');
      return;
    }

    setState(() {
      _loading = true;
      _errorText = null;
      _showCodeSuggestions = false;
    });

    // Check internet connectivity first
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        setState(() {
          _errorText = 'No internet connection. Please check your network and try again.';
          _loading = false;
        });
        _showRetryDialog();
        return;
      }
    } catch (e) {
      print('Connectivity check error: $e');
      // Continue with verification if connectivity check fails
    }

    // Special "super" shortcut
    if (code == 'super') {
      // Save to recent codes list before navigating
      await _saveRecentCode(code);
      Navigator.pushReplacementNamed(
        context,
        '/superAdmin',
        arguments: code,
      );
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(code)
          .get();

      if (doc.exists) {
        // Save to recent codes list before navigating
        await _saveRecentCode(code);
        
        // Pass code into LoginScreen via constructor
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => LoginScreen(schoolCode: code),
          ),
        );
      } else {
        setState(() => _errorText = 'Invalid school code');
      }
    } catch (e) {
      print('Verification error: $e');
      setState(() => _errorText = 'Error verifying code. Please check your internet connection.');
      _showRetryDialog();
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _showRetryDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.red),
            SizedBox(width: 8),
            Text(
              'Connection Error',
              style: TextStyle(color: Colors.red),
            ),
          ],
        ),
        content: Text(
          'Unable to connect to the server. Please check your internet connection and try again.',
        ),
        actions: [
          TextButton(
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: StadiumBorder(),
            ),
            child: Text('Retry'),
            onPressed: () {
              Navigator.of(ctx).pop();
              _verifyCode();
            },
          ),
        ],
      ),
    );
  }

  void _selectSuggestion(String code) {
    _codeController.text = code;
    setState(() {
      _showCodeSuggestions = false;
    });
    // Don't unfocus immediately, let user continue naturally
  }

  void _hideSuggestions() {
    setState(() {
      _showCodeSuggestions = false;
    });
  }

  void _toggleCodeSuggestions() {
    if (_hiveInitialized && _recentCodes.isNotEmpty) {
      setState(() {
        _showCodeSuggestions = !_showCodeSuggestions;
      });
      if (_showCodeSuggestions) {
        _focusNode.requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 2,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text(
          'School Access',
          style: GoogleFonts.workSans(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: GestureDetector(
        onTap: _hideSuggestions,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),
              Text(
                'Welcome',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: textPrimaryColor,
                ),
              ),
              Text(
                'Enter your school code to continue',
                style: GoogleFonts.workSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: textSecondaryColor,
                ),
              ),
              const SizedBox(height: 36),
              
              // School Code field with label
              Text(
                'School Code',
                style: GoogleFonts.workSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: textPrimaryColor,
                ),
              ),
              const SizedBox(height: 8),
              
              // School Code input field with suggestions
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _codeController,
                    focusNode: _focusNode,
                    keyboardType: TextInputType.text,
                    style: GoogleFonts.workSans(color: textPrimaryColor),
                    onChanged: (value) {
                      // Hide suggestions when user is typing
                      if (_showCodeSuggestions) {
                        setState(() => _showCodeSuggestions = false);
                      }
                    },
                    onTap: () {
                      // Show suggestions when tapping the field (if we have codes)
                      if (_hiveInitialized && _recentCodes.isNotEmpty) {
                        setState(() {
                          _showCodeSuggestions = true;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      fillColor: Colors.white,
                      filled: true,
                      hintText: 'Enter school code',
                      hintStyle: GoogleFonts.workSans(color: Colors.grey[400]),
                      prefixIcon: Icon(Icons.business, color: secondaryColor),
                      suffixIcon: _hiveInitialized && _recentCodes.isNotEmpty
                          ? GestureDetector(
                              onTap: _toggleCodeSuggestions,
                              child: Icon(
                                _showCodeSuggestions
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
                        borderSide: BorderSide(color: secondaryColor, width: 1.5),
                      ),
                      errorText: _errorText,
                      errorStyle: GoogleFonts.workSans(color: Colors.red[700]),
                    ),
                  ),

                  // Show suggestions if available
                  if (_showCodeSuggestions && _recentCodes.isNotEmpty)
                    Container(
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
                      constraints: BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.symmetric(vertical: 4),
                        itemCount: _recentCodes.length,
                        itemBuilder: (context, index) {
                          final code = _recentCodes[index];
                          return InkWell(
                            onTap: () => _selectSuggestion(code),
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              child: Row(
                                children: [
                                  Icon(Icons.history, size: 16, color: Colors.grey[600]),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      code,
                                      style: GoogleFonts.workSans(
                                        fontSize: 14,
                                        color: textPrimaryColor,
                                        fontWeight: FontWeight.w500,
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
              
              // Show helper text if there are recent codes
              if (_hiveInitialized && _recentCodes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Tap the field or arrow to see recent codes',
                    style: GoogleFonts.workSans(
                      fontSize: 12,
                      color: textSecondaryColor,
                    ),
                  ),
                ),
                
              const SizedBox(height: 32),
              
              // Continue Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _verifyCode,
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
                          'Continue',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
              ),
              
              const Spacer(),
              
              // Help Section with Card
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      "Don't have a school code?",
                      style: GoogleFonts.workSans(
                        color: textSecondaryColor,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        // TODO: support action (e.g. open email or call)
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.support_agent, color: secondaryColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Contact your school administrator',
                            style: GoogleFonts.workSans(
                              color: secondaryColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

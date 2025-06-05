import 'package:flutter/material.dart';
import 'package:schaccs/screens/parent_dashboard.dart';
import 'package:google_fonts/google_fonts.dart';

class NewsletterScreen extends StatefulWidget {
  static const String routeName = '/newsletter';
  final String schoolCode;
  final String parentDocId;

  const NewsletterScreen({
    super.key,
    required this.schoolCode,
    required this.parentDocId,
  });

  @override
  _NewsletterScreenState createState() => _NewsletterScreenState();
}

class _NewsletterScreenState extends State<NewsletterScreen> {
  // Color scheme
  final Color primaryColor = Color(0xFFB45309); // Amber 700
  final Color backgroundColor = Color(0xFFFFF7ED); // Orange 50 background
  final Color textPrimaryColor = Color(0xFF4A4A4A);
  final Color textSecondaryColor = Color(0xFF888888);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => ParentDashboard(
                  schoolCode: widget.schoolCode,
                  parentDocId: widget.parentDocId,
                ),
              ),
            );
          },
        ),
        title: Text(
          'School News & Updates',
          style: GoogleFonts.workSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.newspaper,
                  size: 80,
                  color: primaryColor,
                ),
              ),
              SizedBox(height: 32),
              Text(
                'Coming Soon!',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'School News & Newsletter',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: textPrimaryColor,
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'This section will include:',
                      style: GoogleFonts.workSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textPrimaryColor,
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildFeatureItem(Icons.announcement, 'School Announcements'),
                    _buildFeatureItem(Icons.event, 'Upcoming Events'),
                    _buildFeatureItem(Icons.article, 'Monthly Newsletters'),
                    _buildFeatureItem(Icons.photo_library, 'Photo Gallery'),
                    _buildFeatureItem(Icons.calendar_today, 'Academic Calendar'),
                    _buildFeatureItem(Icons.info, 'Important Notices'),
                  ],
                ),
              ),
              SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => ParentDashboard(
                        schoolCode: widget.schoolCode,
                        parentDocId: widget.parentDocId,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Back to Dashboard',
                      style: GoogleFonts.workSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: primaryColor,
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Text(
            text,
            style: GoogleFonts.workSans(
              fontSize: 14,
              color: textSecondaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
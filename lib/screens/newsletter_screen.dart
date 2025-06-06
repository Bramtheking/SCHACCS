import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class NewsletterScreen extends StatefulWidget {
  static const routeName = '/newsletter';
  final String schoolCode;
  final String parentDocId;
  

  const NewsletterScreen({
    Key? key,
    required this.schoolCode,
    required this.parentDocId,
  
  }) : super(key: key);

  @override
  State<NewsletterScreen> createState() => _NewsletterScreenState();
}

class _NewsletterScreenState extends State<NewsletterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCategory = 'all';
  String? _studentClass;
  String? _studentAdmissionNo;

  final List<String> _categories = [
    'all',
    'academic',
    'events',
    'sports',
    'announcements',
    'achievements'
  ];

  final Map<String, String> _categoryLabels = {
    'all': 'All',
    'academic': 'Academic',
    'events': 'Events',
    'sports': 'Sports',
    'announcements': 'Announcements',
    'achievements': 'Achievements',
  };

  final Map<String, IconData> _categoryIcons = {
    'all': Icons.all_inclusive,
    'academic': Icons.school,
    'events': Icons.event,
    'sports': Icons.sports,
    'announcements': Icons.campaign,
    'achievements': Icons.emoji_events,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _loadStudentInfo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStudentInfo() async {
    try {
      final parentDoc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolCode)
          .collection('parents')
          .doc(widget.parentDocId)
          .get();

      if (parentDoc.exists) {
        final parentData = parentDoc.data()!;
        final admissionNo = parentData['admissionNo'] as String?;

        if (admissionNo != null) {
          final studentQuery = await FirebaseFirestore.instance
              .collection('schools')
              .doc(widget.schoolCode)
              .collection('students')
              .where('admissionNo', isEqualTo: admissionNo)
              .get();

          if (studentQuery.docs.isNotEmpty) {
            final studentData = studentQuery.docs.first.data();
            setState(() {
              _studentClass = studentData['class'] as String?;
              _studentAdmissionNo = admissionNo;
            });
          }
        }
      }
    } catch (e) {
      print('Error loading student info: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'School Newsletter',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFFB45309),
        elevation: 4,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          onTap: (index) {
            setState(() {
              _selectedCategory = _categories[index];
            });
          },
          tabs: _categories.map((category) {
            return Tab(
              icon: Icon(_categoryIcons[category]),
              text: _categoryLabels[category],
            );
          }).toList(),
        ),
      ),
      body: Container(
        color: const Color(0xFFFFF7ED),
        child: RefreshIndicator(
          color: const Color(0xFFB45309),
          onRefresh: () async {
            setState(() {});
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: _buildNewsletterContent(),
        ),
      ),
    );
  }

  Widget _buildNewsletterContent() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getNewsletterStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Error loading newsletters',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFB45309),
            ),
          );
        }

        final newsletters = snapshot.data?.docs ?? [];

        if (newsletters.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.newspaper, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No newsletters available',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Check back later for updates',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: newsletters.length,
          itemBuilder: (context, index) {
            final newsletter = newsletters[index];
            final data = newsletter.data() as Map<String, dynamic>;
            return _buildNewsletterCard(newsletter.id, data);
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _getNewsletterStream() {
    final now = Timestamp.now();
    Query query = FirebaseFirestore.instance
        .collection('schools')
        .doc(widget.schoolCode)
        .collection('newsletters')
        .where('publishedAt', isLessThanOrEqualTo: now)
        .orderBy('publishedAt', descending: true);

    // Apply category filter
    if (_selectedCategory != 'all') {
      query = query.where('category', isEqualTo: _selectedCategory);
    }

    return query.snapshots();
  }

  Widget _buildNewsletterCard(String newsletterId, Map<String, dynamic> data) {
    final title = data['title'] as String? ?? 'Untitled';
    final content = data['content'] as String? ?? '';
    final category = data['category'] as String? ?? 'announcements';
    final priority = data['priority'] as String? ?? 'normal';
    final publishedAt = (data['publishedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final authorName = data['authorName'] as String? ?? 'School Admin';
    final imageUrls = List<String>.from(data['imageUrls'] ?? []);

    // Check if this newsletter is targeted to this student
    final targetType = data['targetType'] as String? ?? 'global';
    final targetIds = List<String>.from(data['targetIds'] ?? []);
    
    bool isTargeted = targetType == 'global' ||
        (targetType == 'class' && _studentClass != null && targetIds.contains(_studentClass)) ||
        (targetType == 'student' && _studentAdmissionNo != null && targetIds.contains(_studentAdmissionNo));

    if (!isTargeted) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with priority indicator
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getPriorityColor(priority).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(category),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _categoryIcons[category] ?? Icons.info,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _categoryLabels[category] ?? category.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (priority == 'urgent')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'URGENT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
                
                // Images
                if (imageUrls.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: imageUrls.length,
                      itemBuilder: (context, index) {
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: NetworkImage(imageUrls[index]),
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                
                const SizedBox(height: 12),
                
                // Footer
                Row(
                  children: [
                    Icon(Icons.person, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      authorName,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      _formatTimeAgo(publishedAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const Spacer(),
                    _buildActionButtons(newsletterId, data),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(String newsletterId, Map<String, dynamic> data) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bookmark button
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('schools')
              .doc(widget.schoolCode)
              .collection('newsletterBookmarks')
              .doc(widget.parentDocId)
              .snapshots(),
          builder: (context, snapshot) {
            final isBookmarked = snapshot.data?.data() != null &&
                (snapshot.data!.data() as Map<String, dynamic>?)
                    ?.containsKey(newsletterId) == true;

            return IconButton(
              icon: Icon(
                isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                color: isBookmarked ? const Color(0xFFB45309) : Colors.grey,
                size: 20,
              ),
              onPressed: () => _toggleBookmark(newsletterId, isBookmarked),
            );
          },
        ),
        
        // Like button
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('schools')
              .doc(widget.schoolCode)
              .collection('newsletterReactions')
              .doc(newsletterId)
              .snapshots(),
          builder: (context, snapshot) {
            final reactions = snapshot.data?.data() as Map<String, dynamic>? ?? {};
            final hasLiked = reactions.containsKey(widget.parentDocId);
            final likeCount = reactions.length;

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    hasLiked ? Icons.favorite : Icons.favorite_border,
                    color: hasLiked ? Colors.red : Colors.grey,
                    size: 20,
                  ),
                  onPressed: () => _toggleLike(newsletterId, hasLiked),
                ),
                if (likeCount > 0)
                  Text(
                    likeCount.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            );
          },
        ),
        
        // Share button
        IconButton(
          icon: Icon(Icons.share, color: Colors.grey[600], size: 20),
          onPressed: () => _shareNewsletter(data),
        ),
      ],
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'urgent':
        return Colors.red;
      case 'important':
        return Colors.orange;
      default:
        return const Color(0xFFB45309);
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'academic':
        return Colors.blue;
      case 'events':
        return Colors.purple;
      case 'sports':
        return Colors.green;
      case 'achievements':
        return Colors.amber;
      case 'announcements':
        return const Color(0xFFB45309);
      default:
        return Colors.grey;
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return DateFormat('MMM dd, yyyy').format(dateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _toggleBookmark(String newsletterId, bool isCurrentlyBookmarked) async {
    try {
      final bookmarkRef = FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolCode)
          .collection('newsletterBookmarks')
          .doc(widget.parentDocId);

      if (isCurrentlyBookmarked) {
        await bookmarkRef.update({
          newsletterId: FieldValue.delete(),
        });
      } else {
        await bookmarkRef.set({
          newsletterId: FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating bookmark: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleLike(String newsletterId, bool hasLiked) async {
    try {
      final reactionRef = FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolCode)
          .collection('newsletterReactions')
          .doc(newsletterId);

      if (hasLiked) {
        await reactionRef.update({
          widget.parentDocId: FieldValue.delete(),
        });
      } else {
        await reactionRef.set({
          widget.parentDocId: 'like',
        }, SetOptions(merge: true));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating reaction: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _shareNewsletter(Map<String, dynamic> data) async {
    final title = data['title'] as String? ?? 'School Newsletter';
    final content = data['content'] as String? ?? '';
    
    await Share.share(
      '$title\n\n$content\n\nShared from School App',
      subject: title,
    );
  }
}

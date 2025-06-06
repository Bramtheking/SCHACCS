import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:math' as math;

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
    with TickerProviderStateMixin {
  late AnimationController _heroAnimationController;
  late AnimationController _fabAnimationController;
  late AnimationController _searchAnimationController;
  late Animation<double> _heroAnimation;
  late Animation<double> _fabAnimation;
  late Animation<double> _searchAnimation;
  
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final PageController _pageController = PageController();
  
  String _selectedCategory = 'all';
  String? _studentClass;
  String? _studentAdmissionNo;
  bool _isSearchActive = false;
  bool _showFab = false;
  String _searchQuery = '';
  int _currentPage = 0;
  
  final List<String> _categories = [
    'all',
    'academic',
    'events',
    'sports',
    'announcements',
    'achievements'
  ];

  final Map<String, String> _categoryLabels = {
    'all': 'All Stories',
    'academic': 'Academic',
    'events': 'Events',
    'sports': 'Sports',
    'announcements': 'Announcements',
    'achievements': 'Achievements',
  };

  final Map<String, IconData> _categoryIcons = {
    'all': Icons.dashboard_rounded,
    'academic': Icons.school_rounded,
    'events': Icons.event_rounded,
    'sports': Icons.sports_basketball_rounded,
    'announcements': Icons.campaign_rounded,
    'achievements': Icons.emoji_events_rounded,
  };

  final Map<String, List<Color>> _categoryGradients = {
    'all': [Color(0xFFFF6B35), Color(0xFFFF8E53)],
    'academic': [Color(0xFF667eea), Color(0xFF764ba2)],
    'events': [Color(0xFFf093fb), Color(0xFFf5576c)],
    'sports': [Color(0xFF4facfe), Color(0xFF00f2fe)],
    'announcements': [Color(0xFFB45309), Color(0xFFD97706)],
    'achievements': [Color(0xFFffecd2), Color(0xFFfcb69f)],
  };

  @override
  void initState() {
    super.initState();
    _heroAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _searchAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _heroAnimation = CurvedAnimation(
      parent: _heroAnimationController,
      curve: Curves.easeOutCubic,
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.elasticOut,
    );
    _searchAnimation = CurvedAnimation(
      parent: _searchAnimationController,
      curve: Curves.easeInOut,
    );
    
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
    
    _loadStudentInfo();
    _heroAnimationController.forward();
  }

  @override
  void dispose() {
    _heroAnimationController.dispose();
    _fabAnimationController.dispose();
    _searchAnimationController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.offset > 100 && !_showFab) {
      setState(() => _showFab = true);
      _fabAnimationController.forward();
    } else if (_scrollController.offset <= 100 && _showFab) {
      setState(() => _showFab = false);
      _fabAnimationController.reverse();
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearchActive = !_isSearchActive;
    });
    
    if (_isSearchActive) {
      _searchAnimationController.forward();
    } else {
      _searchAnimationController.reverse();
      _searchController.clear();
    }
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
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildModernAppBar(),
          _buildFeaturedStoriesSliver(),
          _buildCategoryFilter(),
          _buildNewsletterContent(),
        ],
      ),
      floatingActionButton: _buildModernFAB(),
    );
  }

  Widget _buildModernAppBar() {
    return SliverAppBar(
      expandedHeight: 160,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
            ),
          ],
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFFB45309)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
              ),
            ],
          ),
          child: IconButton(
            icon: AnimatedRotation(
              turns: _isSearchActive ? 0.25 : 0,
              duration: const Duration(milliseconds: 300),
              child: Icon(
                _isSearchActive ? Icons.close_rounded : Icons.search_rounded,
                color: const Color(0xFFB45309),
              ),
            ),
            onPressed: _toggleSearch,
          ),
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFB45309),
                Color(0xFFD97706),
                Color(0xFFFF8E53),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Animated background pattern
              AnimatedBuilder(
                animation: _heroAnimation,
                builder: (context, child) {
                  return Positioned(
                    top: -50 + (100 * _heroAnimation.value),
                    right: -50 + (100 * _heroAnimation.value),
                    child: Transform.rotate(
                      angle: _heroAnimation.value * math.pi / 4,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                  );
                },
              ),
              // Title and search
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedBuilder(
                      animation: _heroAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, 30 * (1 - _heroAnimation.value)),
                          child: Opacity(
                            opacity: _heroAnimation.value,
                            child: const Text(
                              'School Stories',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    AnimatedBuilder(
                      animation: _heroAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, 20 * (1 - _heroAnimation.value)),
                          child: Opacity(
                            opacity: _heroAnimation.value * 0.8,
                            child: const Text(
                              'Stay connected with your school community',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    AnimatedBuilder(
                      animation: _searchAnimation,
                      builder: (context, child) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: _isSearchActive ? 50 : 0,
                          child: AnimatedOpacity(
                            opacity: _searchAnimation.value,
                            duration: const Duration(milliseconds: 300),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: _searchController,
                                decoration: const InputDecoration(
                                  hintText: 'Search stories...',
                                  prefixIcon: Icon(Icons.search_rounded),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
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

  Widget _buildFeaturedStoriesSliver() {
    return SliverToBoxAdapter(
      child: Container(
        height: 220,
        margin: const EdgeInsets.only(top: 20),
        child: StreamBuilder<QuerySnapshot>(
          stream: _getFeaturedStoriesStream(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const SizedBox.shrink();
            }

            final featuredStories = snapshot.data!.docs.take(5).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Featured Stories',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemCount: featuredStories.length,
                    itemBuilder: (context, index) {
                      final story = featuredStories[index];
                      final data = story.data() as Map<String, dynamic>;
                      return _buildFeaturedCard(story.id, data, index);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    featuredStories.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 8,
                      width: _currentPage == index ? 24 : 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? const Color(0xFFB45309)
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFeaturedCard(String id, Map<String, dynamic> data, int index) {
    final title = data['title'] as String? ?? 'Untitled';
    final content = data['content'] as String? ?? '';
    final category = data['category'] as String? ?? 'announcements';
    final imageUrls = List<String>.from(data['imageUrls'] ?? []);
    final publishedAt = (data['publishedAt'] as Timestamp?)?.toDate() ?? DateTime.now();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Background image or gradient
            Container(
              height: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _categoryGradients[category] ?? [Colors.grey, Colors.grey.shade400],
                ),
                image: imageUrls.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(imageUrls.first),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black.withOpacity(0.3),
                          BlendMode.overlay,
                        ),
                      )
                    : null,
              ),
            ),
            // Content overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Text(
                        _categoryLabels[category] ?? category.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatTimeAgo(publishedAt),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
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

  Widget _buildCategoryFilter() {
    return SliverToBoxAdapter(
      child: Container(
        height: 120,
        margin: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Categories',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = _selectedCategory == category;
                  
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategory = category;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? LinearGradient(
                                  colors: _categoryGradients[category] ??
                                      [const Color(0xFFB45309), const Color(0xFFD97706)],
                                )
                              : null,
                          color: isSelected ? null : Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: isSelected
                                  ? (_categoryGradients[category]?.first ?? const Color(0xFFB45309))
                                      .withOpacity(0.3)
                                  : Colors.black.withOpacity(0.05),
                              blurRadius: isSelected ? 12 : 6,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _categoryIcons[category],
                              color: isSelected ? Colors.white : const Color(0xFF6B7280),
                              size: 24,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _categoryLabels[category] ?? category,
                              style: TextStyle(
                                color: isSelected ? Colors.white : const Color(0xFF6B7280),
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsletterContent() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getNewsletterStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: _buildErrorState(),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverToBoxAdapter(
            child: _buildLoadingState(),
          );
        }

        final newsletters = snapshot.data?.docs ?? [];
        final filteredNewsletters = _filterNewsletters(newsletters);

        if (filteredNewsletters.isEmpty) {
          return SliverToBoxAdapter(
            child: _buildEmptyState(),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final newsletter = filteredNewsletters[index];
              final data = newsletter.data() as Map<String, dynamic>;
              return AnimatedContainer(
                duration: Duration(milliseconds: 300 + (index * 100)),
                margin: const EdgeInsets.only(bottom: 16),
                child: _buildModernNewsletterCard(newsletter.id, data, index),
              );
            },
            childCount: filteredNewsletters.length,
          ),
        );
      },
    );
  }

  List<QueryDocumentSnapshot> _filterNewsletters(List<QueryDocumentSnapshot> newsletters) {
    if (_searchQuery.isEmpty) return newsletters;
    
    return newsletters.where((newsletter) {
      final data = newsletter.data() as Map<String, dynamic>;
      final title = (data['title'] as String? ?? '').toLowerCase();
      final content = (data['content'] as String? ?? '').toLowerCase();
      return title.contains(_searchQuery) || content.contains(_searchQuery);
    }).toList();
  }

  Widget _buildModernNewsletterCard(String newsletterId, Map<String, dynamic> data, int index) {
    final title = data['title'] as String? ?? 'Untitled';
    final content = data['content'] as String? ?? '';
    final category = data['category'] as String? ?? 'announcements';
    final priority = data['priority'] as String? ?? 'normal';
    final publishedAt = (data['publishedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final authorName = data['authorName'] as String? ?? 'School Admin';
    final imageUrls = List<String>.from(data['imageUrls'] ?? []);

    // Check targeting
    final targetType = data['targetType'] as String? ?? 'global';
    final targetIds = List<String>.from(data['targetIds'] ?? []);
    
    bool isTargeted = targetType == 'global' ||
        (targetType == 'class' && _studentClass != null && targetIds.contains(_studentClass)) ||
        (targetType == 'student' && _studentAdmissionNo != null && targetIds.contains(_studentAdmissionNo));

    if (!isTargeted) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        elevation: 0,
        borderRadius: BorderRadius.circular(24),
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with glassmorphism effect
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _categoryGradients[category] ??
                        [const Color(0xFFB45309), const Color(0xFFD97706)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        _categoryIcons[category] ?? Icons.info_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _categoryLabels[category] ?? category.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatTimeAgo(publishedAt),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (priority == 'urgent')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.shade400,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.priority_high_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'URGENT',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              
              // Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      content,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF6B7280),
                        height: 1.6,
                      ),
                    ),
                    
                    // Images with modern layout
                    if (imageUrls.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      if (imageUrls.length == 1)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            imageUrls.first,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: imageUrls.length > 2 ? 2 : imageUrls.length,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1.2,
                          ),
                          itemCount: math.min(imageUrls.length, 4),
                          itemBuilder: (context, imageIndex) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(
                                    imageUrls[imageIndex],
                                    fit: BoxFit.cover,
                                  ),
                                  if (imageIndex == 3 && imageUrls.length > 4)
                                    Container(
                                      color: Colors.black.withOpacity(0.6),
                                      child: Center(
                                        child: Text(
                                          '+${imageUrls.length - 4}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                    
                    const SizedBox(height: 20),
                    
                    // Author and engagement section
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: _getCategoryColor(category).withOpacity(0.1),
                          child: Icon(
                            Icons.person_rounded,
                            size: 16,
                            color: _getCategoryColor(category),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            authorName,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        _buildModernActionButtons(newsletterId, data),
                      ],
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

  Widget _buildModernActionButtons(String newsletterId, Map<String, dynamic> data) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Modern Like Button
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

            return GestureDetector(
              onTap: () => _toggleLike(newsletterId, hasLiked),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: hasLiked ? Colors.red.shade50 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: hasLiked ? Colors.red.shade200 : Colors.grey.shade200,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      size: 16,
                      color: hasLiked ? Colors.red : Colors.grey.shade600,
                    ),
                    if (likeCount > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        likeCount.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: hasLiked ? Colors.red : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
        
        const SizedBox(width: 8),
        
        // Modern Bookmark Button
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

            return GestureDetector(
              onTap: () => _toggleBookmark(newsletterId, isBookmarked),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isBookmarked ? const Color(0xFFB45309).withOpacity(0.1) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isBookmarked ? const Color(0xFFB45309).withOpacity(0.3) : Colors.grey.shade200,
                    width: 1,
                  ),
                ),
                child: Icon(
                  isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  size: 18,
                  color: isBookmarked ? const Color(0xFFB45309) : Colors.grey.shade600,
                ),
              ),
            );
          },
        ),
        
        const SizedBox(width: 8),
        
        // Modern Share Button
        GestureDetector(
          onTap: () => _shareNewsletter(data),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey.shade200,
                width: 1,
              ),
            ),
            child: Icon(
              Icons.share_rounded,
              size: 18,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernFAB() {
    return AnimatedBuilder(
      animation: _fabAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _fabAnimation.value,
          child: FloatingActionButton.extended(
            onPressed: () {
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
              );
            },
            backgroundColor: const Color(0xFFB45309),
            elevation: 8,
            icon: const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white),
            label: const Text(
              'Top',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Container(
      height: 300,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Colors.red.shade400,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Oops! Something went wrong',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please check your connection and try again',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {});
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB45309),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: 400,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFB45309), Color(0xFFD97706)],
              ),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Loading amazing stories...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 400,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFB45309).withOpacity(0.1),
                  const Color(0xFFD97706).withOpacity(0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_stories_rounded,
              size: 64,
              color: const Color(0xFFB45309).withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No stories yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty 
                ? 'Try adjusting your search terms'
                : 'New stories will appear here when published',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (_searchQuery.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                _searchController.clear();
                _toggleSearch();
              },
              icon: const Icon(Icons.clear_rounded),
              label: const Text('Clear Search'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFB45309),
              ),
            ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getFeaturedStoriesStream() {
    final now = Timestamp.now();
    return FirebaseFirestore.instance
        .collection('schools')
        .doc(widget.schoolCode)
        .collection('newsletters')
        .where('publishedAt', isLessThanOrEqualTo: now)
        .where('priority', isEqualTo: 'urgent')
        .orderBy('publishedAt', descending: true)
        .limit(5)
        .snapshots();
  }

  Stream<QuerySnapshot> _getNewsletterStream() {
    final now = Timestamp.now();
    Query query = FirebaseFirestore.instance
        .collection('schools')
        .doc(widget.schoolCode)
        .collection('newsletters')
        .where('publishedAt', isLessThanOrEqualTo: now)
        .orderBy('publishedAt', descending: true);

    if (_selectedCategory != 'all') {
      query = query.where('category', isEqualTo: _selectedCategory);
    }

    return query.snapshots();
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
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _shareNewsletter(Map<String, dynamic> data) async {
    final title = data['title'] as String? ?? 'School Newsletter';
    final content = data['content'] as String? ?? '';
    
    await Share.share(
      '$title\n\n$content\n\nShared from School Stories 📚',
      subject: title,
    );
  }
}
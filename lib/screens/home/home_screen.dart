import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/constants.dart';
import '../../services/notification_service.dart';
import 'home_feed_screen.dart';
import 'create_post_screen.dart';
import '../matches/matches_screen.dart';
import '../wallet/wallet_screen.dart';
import '../suggestions/suggestions_screen.dart';
import '../teams/teams_screen.dart';
import '../profile/profile_screen.dart';
import '../notifications/notifications_screen.dart';
import '../tournaments/tournaments_screen.dart';
import '../bets/bets_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  int _unreadCount = 0;

  int _adminTitleTapCount = 0;
  DateTime? _lastAdminTitleTapTime;

  final List<Widget> _screens = const [
    HomeFeedScreen(),
    MatchesScreen(),
    TeamsScreen(),
    WalletScreen(),
    SuggestionsScreen(),
    ProfileScreen(),
    TournamentsScreen(),
    BetsScreen(),
  ];

  final List<String> _titles = const [
    'JC Sports Hub',
    'Matches',
    'Teams',
    'Wallet',
    'Suggestions',
    'My Profile',
    'Tournaments',
    'My Bets',
  ];

  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final String _userInitial =
      (FirebaseAuth.instance.currentUser?.displayName?.isNotEmpty == true)
          ? FirebaseAuth.instance.currentUser!.displayName![0].toUpperCase()
          : 'U';

  bool _isGuest = false;
  String _userType = '';

  final NotificationService _notificationService = NotificationService();

  int get _bottomNavIndex {
    switch (_selectedIndex) {
      case 0:
        return 0;
      case 1:
        return 1;
      case 6:
        return 2;
      case 4:
        return 3;
      case 5:
        return 4;
      default:
        return 0;
    }
  }

  void _onBottomNavTapped(int index) {
    switch (index) {
      case 0:
        _onItemTapped(0);
        break;
      case 1:
        _onItemTapped(1);
        break;
      case 2:
        _onItemTapped(6);
        break;
      case 3:
        _onItemTapped(4);
        break;
      case 4:
        _onItemTapped(5);
        break;
    }
  }

  void _navigateToCreatePost() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || _isGuest) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreatePostScreen(
          userId: currentUser.uid,
          userName: currentUser.displayName ?? currentUser.email ?? 'User',
          userType: _userType.isEmpty ? 'guest' : _userType,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
    _checkVerification();
  }

  Future<void> _checkVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _isGuest = data['userType'] == 'guest';
        _userType = (data['userType'] ?? '') as String;
        var isVerified =
            data['isVerified'] == true || user.emailVerified == true;
        if (!isVerified) {
          final otpDoc = await FirebaseFirestore.instance
              .collection('otps')
              .doc(user.uid)
              .get();
          isVerified = otpDoc.data()?['verified'] == true;
        }
        if (!isVerified && mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/verify-otp',
            arguments: {
              'userId': user.uid,
              'email': data['email'] ?? user.email ?? '',
              'name': data['fullName'] ?? '',
            },
          );
        }
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _loadUnreadCount() async {
    final count = await _notificationService.getUnreadCount();
    if (mounted) {
      setState(() => _unreadCount = count);
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  void _handleTitleTap() {
    if (_selectedIndex != 0) return;

    final now = DateTime.now();
    if (_lastAdminTitleTapTime != null &&
        now.difference(_lastAdminTitleTapTime!).inSeconds > 3) {
      _adminTitleTapCount = 0;
    }

    _lastAdminTitleTapTime = now;
    _adminTitleTapCount++;

    if (_adminTitleTapCount >= 5) {
      _adminTitleTapCount = 0;
      Navigator.pushNamed(context, '/admin-login');
    }
  }

  // Asks the user to confirm before leaving the app when the Android back
  // button is pressed on the main screen.
  Future<bool> _confirmExit() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Exit App'),
        content: const Text('Are you sure you want to quit JC Sports Hub?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    return shouldExit ?? false;
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      title: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTitleTap,
        child: Text(
          _titles[_selectedIndex],
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      actions: [
        if (_selectedIndex == 0)
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.white,
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationsScreen(),
                    ),
                  );
                  _loadUnreadCount();
                },
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      '$_unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _confirmExit();
        if (shouldExit && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 600;

          final content = IndexedStack(
            index: _selectedIndex,
            children: _screens,
          );

          if (isWide) {
            return Row(
              children: [
                Container(
                  width: 260,
                  color: AppColors.primary,
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 32,
                                    backgroundColor: Colors.white,
                                    child: Text(
                                      _userInitial,
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _currentUser?.displayName ?? 'User',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _currentUser?.email ?? '',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const Divider(color: Colors.white24, height: 1),
                            _buildSidebarItem(
                              icon: Icons.home,
                              label: 'Home',
                              isSelected: _selectedIndex == 0,
                              onTap: () => _onItemTapped(0),
                            ),
                            _buildSidebarItem(
                              icon: Icons.sports_soccer,
                              label: 'Matches',
                              isSelected: _selectedIndex == 1,
                              onTap: () => _onItemTapped(1),
                            ),
                            _buildSidebarItem(
                              icon: Icons.groups,
                              label: 'Teams',
                              isSelected: _selectedIndex == 2,
                              onTap: () => _onItemTapped(2),
                            ),
                            _buildSidebarItem(
                              icon: Icons.account_balance_wallet,
                              label: 'Wallet',
                              isSelected: _selectedIndex == 3,
                              onTap: () => _onItemTapped(3),
                            ),
                            _buildSidebarItem(
                              icon: Icons.lightbulb,
                              label: 'Suggestions',
                              isSelected: _selectedIndex == 4,
                              onTap: () => _onItemTapped(4),
                            ),
                            _buildSidebarItem(
                              icon: Icons.person,
                              label: 'Profile',
                              isSelected: _selectedIndex == 5,
                              onTap: () => _onItemTapped(5),
                            ),
                            _buildSidebarItem(
                              icon: Icons.emoji_events,
                              label: 'Tournaments',
                              isSelected: _selectedIndex == 6,
                              onTap: () => _onItemTapped(6),
                            ),
                            _buildSidebarItem(
                              icon: Icons.receipt_long,
                              label: 'My Bets',
                              isSelected: _selectedIndex == 7,
                              onTap: () => _onItemTapped(7),
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: Colors.white24, height: 1),
                      InkWell(
                        onTap: () async {
                          await FirebaseAuth.instance.signOut();
                          if (mounted) {
                            Navigator.pushReplacementNamed(
                                context, '/onboarding');
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 20),
                          child: const Row(
                            children: [
                              Icon(Icons.logout,
                                  color: Colors.white70, size: 20),
                              SizedBox(width: 16),
                              Text('Logout',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 15)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Scaffold(
                    appBar: _buildAppBar(),
                    body: content,
                  ),
                ),
              ],
            );
          }

          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: _buildAppBar(),
            drawer: Drawer(
              backgroundColor: AppColors.primary,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white,
                          child: Text(
                            _userInitial,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _currentUser?.displayName ?? 'User',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentUser?.email ?? '',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  _buildSidebarItem(
                    icon: Icons.home,
                    label: 'Home',
                    isSelected: _selectedIndex == 0,
                    onTap: () {
                      _onItemTapped(0);
                      Navigator.pop(context);
                    },
                  ),
                  _buildSidebarItem(
                    icon: Icons.sports_soccer,
                    label: 'Matches',
                    isSelected: _selectedIndex == 1,
                    onTap: () {
                      _onItemTapped(1);
                      Navigator.pop(context);
                    },
                  ),
                  _buildSidebarItem(
                    icon: Icons.groups,
                    label: 'Teams',
                    isSelected: _selectedIndex == 2,
                    onTap: () {
                      _onItemTapped(2);
                      Navigator.pop(context);
                    },
                  ),
                  _buildSidebarItem(
                    icon: Icons.account_balance_wallet,
                    label: 'Wallet',
                    isSelected: _selectedIndex == 3,
                    onTap: () {
                      _onItemTapped(3);
                      Navigator.pop(context);
                    },
                  ),
                  _buildSidebarItem(
                    icon: Icons.lightbulb,
                    label: 'Suggestions',
                    isSelected: _selectedIndex == 4,
                    onTap: () {
                      _onItemTapped(4);
                      Navigator.pop(context);
                    },
                  ),
                  _buildSidebarItem(
                    icon: Icons.person,
                    label: 'Profile',
                    isSelected: _selectedIndex == 5,
                    onTap: () {
                      _onItemTapped(5);
                      Navigator.pop(context);
                    },
                  ),
                  _buildSidebarItem(
                    icon: Icons.emoji_events,
                    label: 'Tournaments',
                    isSelected: _selectedIndex == 6,
                    onTap: () {
                      _onItemTapped(6);
                      Navigator.pop(context);
                    },
                  ),
                  _buildSidebarItem(
                    icon: Icons.receipt_long,
                    label: 'My Bets',
                    isSelected: _selectedIndex == 7,
                    onTap: () {
                      _onItemTapped(7);
                      Navigator.pop(context);
                    },
                  ),
                  const Divider(),
                  InkWell(
                    onTap: () async {
                      Navigator.pop(context);
                      await FirebaseAuth.instance.signOut();
                      if (mounted) {
                        Navigator.pushReplacementNamed(context, '/onboarding');
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 20),
                      child: const Row(
                        children: [
                          Icon(Icons.logout, color: Colors.white70, size: 20),
                          SizedBox(width: 16),
                          Text('Logout',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 15)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            body: content,
            floatingActionButton: _selectedIndex == 0 && !_isGuest
                ? FloatingActionButton(
                    onPressed: _navigateToCreatePost,
                    backgroundColor: AppColors.primary,
                    child: const Icon(Icons.add),
                  )
                : null,
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _bottomNavIndex,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: AppColors.primary,
              unselectedItemColor: Colors.grey.shade600,
              onTap: _onBottomNavTapped,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.sports_soccer),
                  label: 'Matches',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.emoji_events),
                  label: 'Tournaments',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.lightbulb),
                  label: 'Suggestions',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        color: isSelected ? Colors.white.withOpacity(0.15) : Colors.transparent,
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white70,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

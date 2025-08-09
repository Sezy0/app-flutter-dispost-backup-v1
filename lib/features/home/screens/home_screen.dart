import 'package:flutter/material.dart';
import 'package:dispost_autopost/features/autopost/screens/autopost_screen.dart';
import 'package:dispost_autopost/features/plan/screens/plan_screen.dart';
import 'package:dispost_autopost/features/more/screens/more_screen.dart';
import 'package:provider/provider.dart';
import 'package:dispost_autopost/core/providers/language_provider.dart';
import 'package:dispost_autopost/widgets/gradient_text.dart';
import 'package:dispost_autopost/core/services/user_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dispost_autopost/core/utils/timezone_utils.dart';
import 'package:timezone/timezone.dart' as tz;
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0; // Set Home as initially selected
  UserProfile? _userProfile;
  bool _isLoading = true;
  
  // Configuration usage tracking
  int _usedConfig = 0;
  int _totalActiveJobs = 0;
  
  // Real-time subscription
  RealtimeChannel? _profileSubscription;
  RealtimeChannel? _configSubscription;
  Timer? _refreshTimer;
  bool _isSubscribed = false;
  bool _isConfigSubscribed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserProfile();
    _setupRealtimeListener();
    _setupPeriodicRefresh();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanupSubscriptions();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        // App kembali ke foreground - restart realtime
        debugPrint('App resumed - restarting realtime listener');
        _restartRealtimeListener();
        _loadUserProfile(); // Refresh data immediately
        break;
      case AppLifecycleState.paused:
        // App ke background - cleanup connections
        debugPrint('App paused - cleaning up connections');
        _cleanupSubscriptions();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await UserService.getCurrentUserProfile();
      if (!mounted) return;
      // Check if user is banned and redirect
      if (profile != null && profile.isBanned) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/banned');
        return;
      }
      
      // Load configuration usage data
      await _loadConfigurationData();
      
      setState(() {
        _userProfile = profile;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadConfigurationData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      
      // Get total config count across all servers
      final countResponse = await Supabase.instance.client
          .from('autopost_config')
          .select('id')
          .eq('user_id', user.id);
      
      _usedConfig = (countResponse as List).length;
      
      // Get total active jobs across all servers
      final activeJobsResponse = await Supabase.instance.client
          .from('autopost_config')
          .select('id')
          .eq('user_id', user.id)
          .eq('status', true);
      
      _totalActiveJobs = (activeJobsResponse as List).length;
      
    } catch (e) {
      debugPrint('Error loading configuration data: $e');
      _usedConfig = 0;
      _totalActiveJobs = 0;
    }
  }
  
  void _setupRealtimeListener() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      debugPrint('No authenticated user found for realtime listener');
      return;
    }
    
    if (_isSubscribed) {
      debugPrint('Realtime listener already subscribed');
      return;
    }
    
    debugPrint('Setting up realtime listener for user: ${user.id}');
    
    try {
      // Profile subscription
      _profileSubscription = Supabase.instance.client
          .channel('profile_changes_${user.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'profiles',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: user.id,
            ),
            callback: (payload) {
              debugPrint('🔄 Profile realtime update received: ${payload.eventType}');
              debugPrint('New data: ${payload.newRecord}');
              
              if (mounted) {
                // Immediate UI update
                _loadUserProfile();
              }
            },
          )
          .subscribe((status, [error]) {
            debugPrint('📡 Profile subscription status: $status');
            if (error != null) {
              debugPrint('❌ Profile realtime error: $error');
            }
            if (status == RealtimeSubscribeStatus.subscribed) {
              _isSubscribed = true;
              debugPrint('✅ Profile listener successfully subscribed');
            }
          });
      
      // Config subscription for real-time updates
      _setupConfigRealtimeListener(user.id);
      
    } catch (e) {
      debugPrint('❌ Error setting up realtime listener: $e');
    }
  }
  
  void _setupConfigRealtimeListener(String userId) {
    if (_isConfigSubscribed) {
      debugPrint('Config realtime listener already subscribed');
      return;
    }
    
    try {
      _configSubscription = Supabase.instance.client
          .channel('config_changes_${userId}_home')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'autopost_config',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              debugPrint('🔄 Config realtime update received: ${payload.eventType}');
              
              if (mounted) {
                // Reload configuration data
                _loadConfigurationData().then((_) {
                  if (mounted) {
                    setState(() {
                      // Trigger UI rebuild with new config data
                    });
                  }
                });
              }
            },
          )
          .subscribe((status, [error]) {
            debugPrint('📡 Config subscription status: $status');
            if (error != null) {
              debugPrint('❌ Config realtime error: $error');
            }
            if (status == RealtimeSubscribeStatus.subscribed) {
              _isConfigSubscribed = true;
              debugPrint('✅ Config listener successfully subscribed');
            }
          });
    } catch (e) {
      debugPrint('❌ Error setting up config realtime listener: $e');
    }
  }
  
  void _setupPeriodicRefresh() {
    // Refresh profile data every 15 seconds to ensure data is up to date
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) {
        debugPrint('⏰ Periodic refresh triggered');
        _loadUserProfile();
      }
    });
  }
  
  void _cleanupSubscriptions() {
    debugPrint('🧹 Cleaning up subscriptions');
    _profileSubscription?.unsubscribe();
    _profileSubscription = null;
    _configSubscription?.unsubscribe();
    _configSubscription = null;
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _isSubscribed = false;
    _isConfigSubscribed = false;
  }
  
  void _restartRealtimeListener() {
    debugPrint('🔄 Restarting realtime listener');
    _cleanupSubscriptions();
    
    // Wait a moment before reestablishing connection
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _setupRealtimeListener();
        _setupPeriodicRefresh();
      }
    });
  }

  List<Widget> get _widgetOptions => <Widget>[
    _buildHomeContent(),
    AutopostScreen(),
    PlanScreen(),
    MoreScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildNavigationBar() {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          items: <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined),
              activeIcon: const Icon(Icons.home),
              label: languageProvider.getLocalizedText('home'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.auto_awesome_outlined),
              activeIcon: const Icon(Icons.auto_awesome),
              label: languageProvider.getLocalizedText('autopost'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.local_offer_outlined),
              activeIcon: const Icon(Icons.local_offer),
              label: languageProvider.getLocalizedText('plan'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.more_horiz_outlined),
              activeIcon: const Icon(Icons.more_horiz),
              label: languageProvider.getLocalizedText('more'),
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Theme.of(context).bottomNavigationBarTheme.selectedItemColor,
          unselectedItemColor: Theme.of(context).bottomNavigationBarTheme.unselectedItemColor,
          backgroundColor: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
          elevation: Theme.of(context).bottomNavigationBarTheme.elevation ?? 8,
          onTap: _onItemTapped,
        );
      },
    );
  }

  Widget _buildHomeContent() {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return RefreshIndicator(
          onRefresh: _loadUserProfile,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Responsive padding based on screen size
              EdgeInsets responsivePadding;
              double headerSpacing;
              
              if (constraints.maxWidth <= 600) {
                // Mobile: minimal padding
                responsivePadding = const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 16.0);
                headerSpacing = 0.0;
              } else {
                // Tablet/Desktop: normal padding
                responsivePadding = const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0);
                headerSpacing = 2.0;
              }
              
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: responsivePadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                // Dashboard Cards
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_userProfile == null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.account_circle_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Profile Setup Required',
                            style: Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your profile is being set up. Please try refreshing or contact support if this persists.',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadUserProfile,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section Header
                      Text(
                        'Dashboard Overview',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      SizedBox(height: headerSpacing),
                      
                      // Dashboard Cards Layout
                      Column(
                        children: [
                          // First Row - Plan Status & Max Config
                          IntrinsicHeight(
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildDashboardCard(
                                    icon: Icons.schedule,
                                    title: 'Plan Status',
                                    value: _userProfile!.isPlanActive 
                                      ? '${_userProfile!.daysUntilExpired} days left'
                                      : 'No active plan',
                                    subtitle: _userProfile!.expiredPlan != null 
                                      ? 'Expires: ${_formatDate(_userProfile!.expiredPlan!)}'
                                      : 'No expiration date',
                                    color: _userProfile!.isPlanActive 
                                      ? Colors.green 
                                      : Colors.orange,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildDashboardCard(
                                    icon: Icons.storage_outlined,
                                    title: 'Plan Limit',
                                    value: (_userProfile!.maxConfig != null && _userProfile!.maxConfig! > 0)
                                      ? '${_userProfile!.maxConfig} configs'
                                      : 'No limit set',
                                    subtitle: (_userProfile!.maxConfig != null && _userProfile!.maxConfig! > 0)
                                      ? 'Maximum allowed configs'
                                      : 'Contact support for limits',
                                    color: Colors.indigo,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Second Row - Config Usage & Active Jobs
                          IntrinsicHeight(
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildDashboardCard(
                                    icon: Icons.settings_outlined,
                                    title: 'Config Usage',
                                    value: '$_usedConfig / ${_userProfile!.maxConfig ?? 0}',
                                    subtitle: _usedConfig >= (_userProfile!.maxConfig ?? 0) 
                                      ? 'Quota limit reached'
                                      : '${(_userProfile!.maxConfig ?? 0) - _usedConfig} slots remaining',
                                    color: _usedConfig >= (_userProfile!.maxConfig ?? 0) 
                                      ? Colors.orange
                                      : Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildDashboardCard(
                                    icon: Icons.play_circle_outline,
                                    title: 'Active Jobs',
                                    value: _totalActiveJobs.toString(),
                                    subtitle: 'Currently running jobs',
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Third Row - Total Sent
                          Row(
                            children: [
                              Expanded(
                                child: _buildDashboardCard(
                                  icon: Icons.send,
                                  title: 'Total Sent',
                                  value: _userProfile!.totalSent.toString(),
                                  subtitle: 'Posts sent successfully',
                                  color: Colors.purple,
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Empty space to maintain layout balance
                              Expanded(
                                child: Container(), // Empty placeholder
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // Helper function to format date using Jakarta timezone
  String _formatDate(DateTime date) {
    // Import timezone utils di bagian atas file jika belum ada
    final jakartaDate = tz.TZDateTime.from(date, TimezoneUtils.jakartaLocation);
    
    if (TimezoneUtils.isToday(jakartaDate)) {
      return 'Today';
    } else if (TimezoneUtils.isTomorrow(jakartaDate)) {
      return 'Tomorrow';
    } else {
      final daysDiff = TimezoneUtils.daysDifferenceFromNow(jakartaDate);
      if (daysDiff < 0) {
        return 'Expired ${(-daysDiff)} days ago';
      } else {
        return TimezoneUtils.formatJakartaDate(jakartaDate, format: 'dd/MM/yyyy');
      }
    }
  }

  Widget _buildDashboardCard({
    required IconData icon,
    required String title,
    required String value,
    String? subtitle,
    required Color color,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          // Tambahkan sedikit gradient untuk depth visual
          gradient: Theme.of(context).brightness == Brightness.dark
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF3A3A3A),
                    const Color(0xFF353535),
                  ],
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with icon and title
            Row(
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Main value
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            // Subtitle if provided
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48.0), // Reduce AppBar height
        child: AppBar(
          title: const GradientText(text: 'DisPost'),
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          elevation: 0,
          iconTheme: Theme.of(context).appBarTheme.iconTheme,
          centerTitle: false,
          titleSpacing: 16.0,
        ),
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: _buildNavigationBar(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dispost_autopost/core/providers/language_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dispost_autopost/core/widgets/custom_notification.dart';
import 'package:dispost_autopost/features/autopost/screens/add_config_screen.dart';
import 'package:dispost_autopost/features/autopost/screens/edit_config_screen.dart';
import 'package:dispost_autopost/core/utils/timezone_utils.dart';
import 'dart:async';

class Server1Screen extends StatefulWidget {
  const Server1Screen({super.key});

  @override
  State<Server1Screen> createState() => _Server1ScreenState();
}

class _Server1ScreenState extends State<Server1Screen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = false;
  List<Map<String, dynamic>> _autopostConfigs = [];
  List<Map<String, dynamic>> _tokens = [];
  int _maxConfig = 0;
  int _usedConfig = 0;
  int _totalActiveJobs = 0; // Total active jobs across all servers
  Timer? _countdownTimer;
  StreamSubscription? _configSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startCountdownTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _configSubscription?.cancel();
    super.dispose();
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          // Trigger rebuild every second to update countdown
        });
      }
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Load user profile to get max_config
      final profileResponse = await _supabase
          .from('profiles')
          .select('max_config')
          .eq('id', user.id)
          .maybeSingle();

      _maxConfig = profileResponse?['max_config'] ?? 0;

      // Load tokens
      final tokensResponse = await _supabase
          .from('tokens')
          .select()
          .eq('user_id', user.id)
          .eq('status', true)
          .order('created_at', ascending: false);

      _tokens = List<Map<String, dynamic>>.from(tokensResponse);

      // Load autopost configurations for Server 1 with token information
      final configsResponse = await _supabase
          .from('autopost_config')
          .select('''
            *,
            tokens!inner(
              name,
              discord_id
            )
          ''')
          .eq('user_id', user.id)
          .eq('server_type', 'server_1')
          .order('created_at', ascending: false);

      _autopostConfigs = List<Map<String, dynamic>>.from(configsResponse);
      
      // Get total config count across all servers for quota display
      final countResponse = await _supabase
          .from('autopost_config')
          .select('id')
          .eq('user_id', user.id);
      
      _usedConfig = (countResponse as List).length;
      
      // Get total active jobs across all servers
      final activeJobsResponse = await _supabase
          .from('autopost_config')
          .select('id')
          .eq('user_id', user.id)
          .eq('status', true);
      
      _totalActiveJobs = (activeJobsResponse as List).length;
      
      // Set up real-time subscription for config changes
      _setupRealtimeSubscription();
      
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
    
    setState(() {
      _isLoading = false;
    });
  }
  
  void _setupRealtimeSubscription() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    
    // Cancel existing subscription
    _configSubscription?.cancel();
    
    try {
      // Listen to changes in autopost_config table for this user
      _configSubscription = _supabase
          .from('autopost_config')
          .stream(primaryKey: ['id'])
          .eq('user_id', user.id)
          .handleError((error) {
            debugPrint('Realtime subscription error: $error');
            // On error, fall back to periodic refresh
            _fallbackToPeriodicRefresh();
          })
          .listen((data) {
            if (mounted) {
              _handleRealtimeUpdate(data);
            }
          }, onError: (error) {
            debugPrint('Realtime stream error: $error');
            // On error, fall back to periodic refresh
            _fallbackToPeriodicRefresh();
          });
    } catch (e) {
      debugPrint('Failed to setup realtime subscription: $e');
      // Fall back to periodic refresh if realtime setup fails
      _fallbackToPeriodicRefresh();
    }
  }
  
  void _fallbackToPeriodicRefresh() {
    debugPrint('Falling back to periodic refresh due to realtime issues');
    // Cancel any existing realtime subscription
    _configSubscription?.cancel();
    _configSubscription = null;
    
    // Set up periodic refresh every 10 seconds as fallback
    Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _loadData();
      } else {
        timer.cancel();
      }
    });
  }
  
  void _handleRealtimeUpdate(List<dynamic> data) {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    
    try {
      // Safely cast the dynamic data to the expected type
      final safeData = data.cast<Map<String, dynamic>>();
      
      // Filter data for current server type
      final server1Configs = safeData.where((config) => config['server_type'] == 'server_1').toList();
      
      // Update total active jobs count
      final totalActiveConfigs = safeData.where((config) => config['status'] == true).toList();
    
    setState(() {
      // Update server 1 configs with token information
      _autopostConfigs = server1Configs.map((config) {
        // Find matching token data from existing configs or tokens list
        final existingConfig = _autopostConfigs.firstWhere(
          (existing) => existing['id'] == config['id'],
          orElse: () => {},
        );
        
        if (existingConfig.isNotEmpty && existingConfig['tokens'] != null) {
          config['tokens'] = existingConfig['tokens'];
        } else {
          // Try to find token from tokens list
          final token = _tokens.firstWhere(
            (t) => t['id'] == config['token_id'],
            orElse: () => {'name': 'Unknown Token', 'discord_id': ''},
          );
          config['tokens'] = token;
        }
        
        return config;
      }).toList();
      
      _totalActiveJobs = totalActiveConfigs.length;
    });
    } catch (e) {
      debugPrint('Error in realtime update: $e');
      // If there's an error, just reload the data
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
      appBar: AppBar(
        title: Text(languageProvider.getLocalizedText('server_1')),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        iconTheme: Theme.of(context).appBarTheme.iconTheme,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _canCreateNewConfig() ? () => _showCreateConfigDialog(languageProvider) : null,
            tooltip: _canCreateNewConfig() 
              ? 'Add New Configuration'
              : 'Configuration quota limit reached',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : () {
              _loadData();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildServerHeader(languageProvider),
                        const SizedBox(height: 16),
                        _buildQuickStats(languageProvider),
                        const SizedBox(height: 16),
                        _buildConfigurationsList(languageProvider),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildServerHeader(LanguageProvider languageProvider) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).cardColor,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud,
                size: 24,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    languageProvider.getLocalizedText('server_1'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    languageProvider.getLocalizedText('free_trial_access'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'ACTIVE',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(LanguageProvider languageProvider) {
    return Column(
      children: [
        // Config Quota Card
        _buildQuotaCard(),
        const SizedBox(height: 10),
        _buildStatCard(
          icon: Icons.vpn_key_outlined,
          title: 'Available Tokens',
          value: '${_tokens.length}',
          subtitle: 'Active Discord tokens',
        ),
        const SizedBox(height: 10),
        _buildStatCard(
          icon: Icons.schedule_outlined,
          title: 'Active Jobs',
          value: '$_totalActiveJobs',
          subtitle: 'All servers running jobs',
        ),
      ],
    );
  }

  Widget _buildQuotaCard() {
    final remainingConfig = _maxConfig - _usedConfig;
    final isLimitReached = remainingConfig <= 0;
    final progressPercentage = _maxConfig > 0 ? (_usedConfig / _maxConfig) : 0.0;
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isLimitReached 
            ? Colors.orange.withValues(alpha: 0.3)
            : Theme.of(context).dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isLimitReached 
                      ? Colors.orange.withValues(alpha: 0.1)
                      : Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.settings_outlined,
                    color: isLimitReached 
                      ? Colors.orange
                      : Theme.of(context).primaryColor.withValues(alpha: 0.8),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Configuration Quota',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '$_usedConfig / $_maxConfig',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isLimitReached ? Colors.orange : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isLimitReached 
                          ? 'Quota limit reached'
                          : '$remainingConfig slots remaining',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isLimitReached 
                            ? Colors.orange 
                            : Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Progress Bar
            Container(
              width: double.infinity,
              height: 6,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progressPercentage.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: isLimitReached 
                      ? Colors.orange 
                      : Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Theme.of(context).primaryColor.withValues(alpha: 0.8),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        value,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigurationsList(LanguageProvider languageProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Autopost Configurations',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_tokens.isNotEmpty && _canCreateNewConfig())
              TextButton.icon(
                onPressed: () => _showCreateConfigDialog(languageProvider),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add New'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_tokens.isEmpty)
          _buildNoTokensMessage(languageProvider)
        else if (_autopostConfigs.isEmpty)
          _buildNoConfigsMessage(languageProvider)
        else
          ..._autopostConfigs.map((config) => _buildConfigCard(config, languageProvider)),
      ],
    );
  }

  Widget _buildNoTokensMessage(LanguageProvider languageProvider) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.vpn_key_off_outlined,
              size: 40,
              color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'No Discord Tokens Found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'You need to add at least one Discord token before creating autopost configurations.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/manage-token'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Discord Token'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoConfigsMessage(LanguageProvider languageProvider) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.settings_outlined,
              size: 40,
              color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'No Configurations Yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Create your first autopost configuration to get started with Server 1.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _canCreateNewConfig() ? () => _showCreateConfigDialog(languageProvider) : null,
              icon: const Icon(Icons.add, size: 18),
              label: Text(_canCreateNewConfig() ? 'Create Configuration' : 'Quota Limit Reached'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _canCreateNewConfig() ? Theme.of(context).primaryColor : Colors.grey,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDelay(int delaySeconds) {
    if (delaySeconds < 60) {
      return '${delaySeconds}s';
    } else if (delaySeconds < 3600) {
      final minutes = delaySeconds ~/ 60;
      final seconds = delaySeconds % 60;
      return seconds > 0 ? '${minutes}m ${seconds}s' : '${minutes}m';
    } else {
      final hours = delaySeconds ~/ 3600;
      final minutes = (delaySeconds % 3600) ~/ 60;
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    }
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match match) => '${match[1]}.',
    );
  }

  String _calculateNextRun(Map<String, dynamic> config) {
    final nextRunString = config['next_run'];
    if (nextRunString == null) return 'Not scheduled';
    
    try {
      final nextRun = DateTime.parse(nextRunString);
      final now = DateTime.now();
      final difference = nextRun.difference(now);
      
      if (difference.isNegative) {
        return 'Wait';
      } else if (difference.inSeconds < 60) {
        return '${difference.inSeconds}s';
      } else if (difference.inMinutes < 60) {
        final minutes = difference.inMinutes;
        final seconds = difference.inSeconds % 60;
        return '${minutes}m ${seconds}s'; // Always show seconds
      } else if (difference.inHours < 24) {
        final hours = difference.inHours;
        final minutes = difference.inMinutes % 60;
        final seconds = difference.inSeconds % 60;
        return '${hours}h ${minutes}m ${seconds}s'; // Always show seconds
      } else {
        final days = difference.inDays;
        final hours = difference.inHours % 24;
        final minutes = difference.inMinutes % 60;
        final seconds = difference.inSeconds % 60;
        return '${days}d ${hours}h ${minutes}m ${seconds}s'; // Always show seconds
      }
    } catch (e) {
      return 'Invalid date';
    }
  }

  String _formatEndTimeDisplay(String endTimeString) {
    try {
      final jakartaDateTime = TimezoneUtils.parseToJakartaTime(endTimeString);
      
      // Format: 08-08-2000 21:01:00
      return '${jakartaDateTime.day.toString().padLeft(2, '0')}-'
             '${jakartaDateTime.month.toString().padLeft(2, '0')}-'
             '${jakartaDateTime.year} '
             '${jakartaDateTime.hour.toString().padLeft(2, '0')}:'
             '${jakartaDateTime.minute.toString().padLeft(2, '0')}:'
             '${jakartaDateTime.second.toString().padLeft(2, '0')}';
      
    } catch (e) {
      return 'Invalid date';
    }
  }

  String _truncateConfigName(String configName) {
    if (configName.length <= 20) {
      return configName;
    }
    return '${configName.substring(0, 20)}...';
  }

  Widget _buildConfigCard(Map<String, dynamic> config, LanguageProvider languageProvider) {
    final isActive = config['status'] ?? false;
    final tokenData = config['tokens'] as Map<String, dynamic>?;
    final tokenName = tokenData?['name'] ?? 'Unknown Token';
    final configName = config['name'] ?? 'Untitled Config';
    final delay = config['delay'] ?? 0;
    final minDelay = config['min_delay'] ?? 0;
    final maxDelay = config['max_delay'] ?? 0;
    final totalSent = config['total_sent'] ?? 0;
    final endTime = config['end_time'];
    final nextRun = _calculateNextRun(config);
    
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive 
                      ? Theme.of(context).primaryColor 
                      : Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _truncateConfigName(configName),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Token: $tokenName',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isActive 
                      ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                      : Theme.of(context).dividerColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isActive ? 'ACTIVE' : 'INACTIVE',
                    style: TextStyle(
                      color: isActive 
                        ? Theme.of(context).primaryColor
                        : Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Row 1: Delay
            Row(
              children: [
                Icon(
                  Icons.timer_outlined, 
                  size: 14, 
                  color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6)
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        'Delay: ',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          '${_formatDelay(delay)} (${_formatDelay(minDelay)}-${_formatDelay(maxDelay)})',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Row 2: Total Sent
            Row(
              children: [
                Icon(
                  Icons.send_outlined, 
                  size: 14, 
                  color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6)
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        'Total Sent: ',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          '${_formatNumber(totalSent)} messages',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Row 3: Next Run
            Row(
              children: [
                Icon(
                  Icons.schedule_outlined,
                  size: 14, 
                  color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6)
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        'Next Run: ',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          isActive ? nextRun : 'Paused',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (endTime != null) ...[
              const SizedBox(height: 6),
              // Row 4: End Time
              Row(
                children: [
                  Icon(
                    Icons.event_outlined, 
                    size: 14, 
                    color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6)
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          'End Time: ',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            _formatEndTimeDisplay(endTime!),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () => _editConfig(config, languageProvider),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  style: IconButton.styleFrom(
                    foregroundColor: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                  tooltip: 'Edit',
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => _toggleConfigStatus(config['id'], !isActive),
                  icon: Icon(
                    isActive ? Icons.pause_outlined : Icons.play_arrow_outlined,
                    size: 18,
                  ),
                  style: IconButton.styleFrom(
                    foregroundColor: isActive 
                      ? Colors.orange 
                      : Theme.of(context).primaryColor,
                  ),
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                  tooltip: isActive ? 'Pause' : 'Start',
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => _deleteConfig(config['id']),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  style: IconButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                  tooltip: 'Delete',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _canCreateNewConfig() {
    if (_tokens.isEmpty) return false;
    if (_maxConfig <= 0) return false;
    return _usedConfig < _maxConfig;
  }

  void _showCreateConfigDialog(LanguageProvider languageProvider) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const AddConfigScreen(serverType: 'server_1'),
      ),
    );

    // If config was created successfully, reload data
    if (result == true && mounted) {
      _loadData();
    }
  }



  void _editConfig(Map<String, dynamic> config, LanguageProvider languageProvider) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => EditConfigScreen(config: config),
      ),
    );

    // If config was updated successfully, reload data
    if (result == true && mounted) {
      _loadData();
    }
  }

  Future<void> _toggleConfigStatus(String configId, bool newStatus) async {
    // Update UI immediately for smooth experience
    final configIndex = _autopostConfigs.indexWhere((c) => c['id'] == configId);
    if (configIndex != -1) {
      setState(() {
        _autopostConfigs[configIndex]['status'] = newStatus;
        
        // Update total active jobs count immediately
        if (newStatus) {
          _totalActiveJobs++;
        } else {
          _totalActiveJobs = (_totalActiveJobs - 1).clamp(0, double.infinity).toInt();
        }
        
        // Don't set next_run here - let the backend server handle it
        // Just update the status, next_run will be updated via realtime subscription
      });
    }
    
    // UI updated immediately, no notification needed
    
    // Update database in background
    try {
      debugPrint('Syncing config $configId to status: $newStatus');
      
      Map<String, dynamic> updateData = {
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      // Don't modify next_run - let it remain as is in database
      // Backend server will handle next_run scheduling when status is active
      
      await _supabase
          .from('autopost_config')
          .update(updateData)
          .eq('id', configId);
      
      debugPrint('Config $configId synced successfully');
      
    } catch (e) {
      debugPrint('Error syncing config status: $e');
      
      // Revert UI change if database update failed
      if (configIndex != -1 && mounted) {
        setState(() {
          _autopostConfigs[configIndex]['status'] = !newStatus;
          
          // Revert total active jobs count
          if (newStatus) {
            // We tried to activate but failed, so decrease count
            _totalActiveJobs = (_totalActiveJobs - 1).clamp(0, double.infinity).toInt();
          } else {
            // We tried to deactivate but failed, so increase count
            _totalActiveJobs++;
          }
          
          // Don't manually set next_run, let realtime subscription handle it
        });
        
        showCustomNotification(
          context,
          'Failed to sync configuration. Please try again.',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  Future<void> _deleteConfig(String configId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.red[900]?.withValues(alpha: 0.3) : Colors.red[50],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.red[800] : Colors.red[100],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.warning,
                          color: isDarkMode ? Colors.red[300] : Colors.red[700],
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Delete Configuration?',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.red[300] : Colors.red[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Are you sure you want to delete this configuration? This action cannot be undone.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
                // Actions
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[800] : Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: isDarkMode ? Colors.grey[600]! : Colors.grey[300]!,
                              ),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 1,
                          ),
                          child: const Text(
                            'Delete',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true && mounted) {
      // Find the config to get its status before deletion
      final configToDelete = _autopostConfigs.firstWhere(
        (config) => config['id'] == configId,
        orElse: () => {},
      );
      final wasActive = configToDelete['status'] ?? false;
      
      // Update UI immediately - remove from list
      setState(() {
        _autopostConfigs.removeWhere((config) => config['id'] == configId);
        _usedConfig = _usedConfig > 0 ? _usedConfig - 1 : 0;
        if (wasActive) {
          _totalActiveJobs = _totalActiveJobs > 0 ? _totalActiveJobs - 1 : 0;
        }
      });
      
      try {
        await _supabase
            .from('autopost_config')
            .delete()
            .eq('id', configId);
        
        if (mounted) {
          showCustomNotification(
            context,
            'Configuration deleted successfully',
            backgroundColor: Colors.blue,
          );
        }
      } catch (e) {
        if (mounted) {
          // Revert UI changes if delete failed
          setState(() {
            if (configToDelete.isNotEmpty) {
              _autopostConfigs.add(configToDelete);
              _usedConfig++;
              if (wasActive) {
                _totalActiveJobs++;
              }
            }
          });
          
          showCustomNotification(
            context,
            'Failed to delete configuration',
            backgroundColor: Colors.red,
          );
        }
      }
    }
  }
}

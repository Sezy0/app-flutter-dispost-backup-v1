import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dispost_autopost/core/providers/language_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dispost_autopost/core/widgets/custom_notification.dart';
import 'package:dispost_autopost/features/autopost/screens/add_config_screen.dart';
import 'package:dispost_autopost/features/autopost/screens/edit_config_screen.dart';
import 'package:dispost_autopost/core/utils/timezone_utils.dart';
import 'dart:async';

class Server3Screen extends StatefulWidget {
  const Server3Screen({super.key});

  @override
  State<Server3Screen> createState() => _Server3ScreenState();
}

class _Server3ScreenState extends State<Server3Screen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = false;
  List<Map<String, dynamic>> _autopostConfigs = [];
  List<Map<String, dynamic>> _tokens = [];
  int _maxConfig = 0;
  int _usedConfig = 0;
  int _totalActiveJobs = 0; // Total active jobs across all servers
  Timer? _countdownTimer;
  StreamSubscription? _configSubscription;
  final Set<String> _duplicatedConfigIds = <String>{}; // Track duplicated config IDs
  final Map<String, int> _duplicateCooldowns = <String, int>{}; // Track duplicate cooldowns
  Timer? _duplicateCooldownTimer;
  
  // Multi-select functionality
  bool _isSelectionMode = false;
  final Set<String> _selectedConfigIds = <String>{}; // Track selected config IDs

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
    _duplicateCooldownTimer?.cancel();
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

      // Load autopost configurations for Server 3 with token information
      final configsResponse = await _supabase
          .from('autopost_config')
          .select('''
            *,
            tokens!inner(
              name,
              discord_id,
              avatar_url
            )
          ''')
          .eq('user_id', user.id)
          .eq('server_type', 'server_3')
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
      final server3Configs = safeData.where((config) => config['server_type'] == 'server_3').toList();
      
      // Update total active jobs count
      final totalActiveConfigs = safeData.where((config) => config['status'] == true).toList();
    
    setState(() {
      // Don't update the configs list from realtime if we recently added a duplicate
      // This prevents the newly added config from being moved by realtime updates
      if (_duplicatedConfigIds.isNotEmpty) {
        debugPrint('Skipping realtime update due to recent duplicate operation');
        _totalActiveJobs = totalActiveConfigs.length;
        return;
      }
      
      // Update server 3 configs with token information
      _autopostConfigs = server3Configs.map((config) {
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
      
      // Sort by created_at descending to maintain newest first order
      _autopostConfigs.sort((a, b) {
        final aCreatedAt = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime.now();
        final bCreatedAt = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime.now();
        return bCreatedAt.compareTo(aCreatedAt); // Newest first
      });
      
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
            title: Text(_isSelectionMode 
              ? '${_selectedConfigIds.length} selected'
              : languageProvider.getLocalizedText('server_3')),
            backgroundColor: _isSelectionMode 
              ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
              : Theme.of(context).scaffoldBackgroundColor,
            foregroundColor: Theme.of(context).textTheme.titleLarge?.color,
            elevation: 0,
            actions: _isSelectionMode ? [
              // Selection mode actions
              IconButton(
                icon: const Icon(Icons.select_all),
                onPressed: _selectAll,
                tooltip: 'Select All',
              ),
              IconButton(
                icon: const Icon(Icons.play_arrow),
                onPressed: _selectedConfigIds.isNotEmpty ? _startAllSelected : null,
                tooltip: 'Start Selected',
              ),
              IconButton(
                icon: const Icon(Icons.stop),
                onPressed: _selectedConfigIds.isNotEmpty ? _stopAllSelected : null,
                tooltip: 'Stop Selected',
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: _selectedConfigIds.isNotEmpty ? _deleteAllSelected : null,
                tooltip: 'Delete Selected',
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
                tooltip: 'Cancel',
              ),
            ] : [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _canCreateNewConfig() ? () => _showCreateConfigDialog(languageProvider) : null,
                tooltip: _canCreateNewConfig() 
                  ? 'Add New Configuration'
                  : 'Configuration quota limit reached',
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadData,
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
                Icons.cloud_done,
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
                    languageProvider.getLocalizedText('server_3'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    languageProvider.getLocalizedText('pro_plan_access'),
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
              'Create your first autopost configuration to get started with Server 3.',
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
    final delay = config['delay'] ?? 0;
    final minDelay = config['min_delay'] ?? 0;
    final maxDelay = config['max_delay'] ?? 0;
    final totalSent = config['total_sent'] ?? 0;
    final endTime = config['end_time'];
    final nextRun = _calculateNextRun(config);
    final configId = config['id'] as String;
    final isSelected = _selectedConfigIds.contains(configId);
    
    return GestureDetector(
      onLongPress: () => _onConfigLongPress(configId),
      onTap: _isSelectionMode ? () => _toggleSelection(configId) : null,
      child: Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected 
            ? Theme.of(context).primaryColor.withValues(alpha: 0.7)
            : Theme.of(context).dividerColor.withValues(alpha: 0.2),
          width: isSelected ? 2 : 1,
        ),
      ),
      color: isSelected 
        ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
        : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (_isSelectionMode) ...[
                  Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected 
                          ? Theme.of(context).primaryColor
                          : Theme.of(context).dividerColor,
                        width: 2,
                      ),
                      color: isSelected 
                        ? Theme.of(context).primaryColor
                        : Colors.transparent,
                    ),
                    child: isSelected 
                      ? Icon(
                          Icons.check,
                          size: 14,
                          color: Colors.white,
                        )
                      : null,
                  ),
                ] else ...[
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
                ],
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _truncateConfigName(config['name'] ?? 'Untitled Config'),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: ClipOval(
                              child: tokenData?['avatar_url'] != null && 
                                     tokenData!['avatar_url'].toString().isNotEmpty
                                  ? Image.network(
                                      tokenData['avatar_url'],
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Icon(
                                        Icons.person,
                                        color: Theme.of(context).primaryColor,
                                        size: 10,
                                      ),
                                    )
                                  : Icon(
                                      Icons.person,
                                      color: Theme.of(context).primaryColor,
                                      size: 10,
                                    ),
                            ),
                          ),
                          Flexible(
                            child: Text(
                              'Token: $tokenName',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                                color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Show DUPLICATE label if this config was just duplicated
                if (_duplicatedConfigIds.contains(config['id']))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7D3DFE).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'DUPLICATE',
                      style: TextStyle(
                        color: const Color(0xFF7D3DFE),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
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
                Text(
                  'Delay: ',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  '${_formatDelay(delay)} (${_formatDelay(minDelay)}-${_formatDelay(maxDelay)})',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
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
                Text(
                  'Total Sent: ',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  '${_formatNumber(totalSent)} messages',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
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
                Text(
                  'Next Run: ',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  isActive ? nextRun : 'Paused',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
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
                  Text(
                    'End Time: ',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                    ),
                  ),
                  Text(
                    _formatEndTimeDisplay(endTime!),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            if (!_isSelectionMode) 
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
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        onPressed: (_canDuplicateConfig(configId) && _duplicateCooldowns.isEmpty) ? () => _duplicateConfig(config) : null,
                        icon: const Icon(Icons.content_copy_outlined, size: 18),
                        style: IconButton.styleFrom(
                          foregroundColor: (_canDuplicateConfig(configId) && _duplicateCooldowns.isEmpty)
                            ? const Color(0xFF7D3DFE)
                            : Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.3),
                        ),
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                        tooltip: _getDuplicateTooltip(configId),
                      ),
                      if (_duplicateCooldowns.containsKey(configId))
                        Text(
                          '${_duplicateCooldowns[configId]}',
                          style: TextStyle(
                            color: const Color(0xFF7D3DFE),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
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
      ),
    );
  }

  void _showCreateConfigDialog(LanguageProvider languageProvider) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const AddConfigScreen(serverType: 'server_3'),
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

  Future<void> _duplicateConfig(Map<String, dynamic> originalConfig) async {
    // First check local state
    if (!_canCreateNewConfig()) {
      showCustomNotification(
        context,
        'Configuration quota limit reached ($_usedConfig/$_maxConfig)',
        backgroundColor: Colors.orange,
      );
      return;
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Double-check quota limit with real-time data from database before proceeding
      debugPrint('🔍 Checking real-time quota before duplicate operation...');
      
      final profileResponse = await _supabase
          .from('profiles')
          .select('max_config')
          .eq('id', user.id)
          .maybeSingle();
      
      final currentMaxConfig = profileResponse?['max_config'] ?? 0;
      
      final countResponse = await _supabase
          .from('autopost_config')
          .select('id')
          .eq('user_id', user.id);
      
      final currentUsedConfig = (countResponse as List).length;
      
      // Update local state with real data
      if (mounted) {
        setState(() {
          _maxConfig = currentMaxConfig;
          _usedConfig = currentUsedConfig;
        });
      }
      
      // Final quota validation with proper error handling
      debugPrint('📊 Real-time quota check: $currentUsedConfig/$currentMaxConfig');
      
      if (currentUsedConfig >= currentMaxConfig) {
        debugPrint('❌ Quota exceeded: $currentUsedConfig/$currentMaxConfig');
        if (mounted) {
          showCustomNotification(
            context,
            'Configuration quota limit reached ($currentUsedConfig/$currentMaxConfig)',
            backgroundColor: Colors.orange,
          );
        }
        return;
      }
      
      debugPrint('✅ Quota check passed: $currentUsedConfig/$currentMaxConfig - proceeding with duplicate');

      // Create a duplicate config with status inactive
      final duplicateData = {
        'user_id': user.id,
        'token_id': originalConfig['token_id'],
        'server_type': 'server_3',
        'channel_id': originalConfig['channel_id'],
        'webhook_url': originalConfig['webhook_url'],
        'delay': originalConfig['delay'],
        'min_delay': originalConfig['min_delay'],
        'max_delay': originalConfig['max_delay'],
        'message': originalConfig['message'],
        'end_time': originalConfig['end_time'],
        'status': false, // Always inactive when duplicated
        'total_sent': 0, // Reset counter for duplicate
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('autopost_config')
          .insert(duplicateData)
          .select('''
            *,
            tokens!inner(
              name,
              discord_id
            )
          ''')
          .single();

      final newConfigId = response['id'] as String;
      
      // Create new config object with token data
      final newConfigWithToken = Map<String, dynamic>.from(response);
      
      // Ensure token data is properly set
      if (newConfigWithToken['tokens'] == null) {
        final originalToken = originalConfig['tokens'];
        if (originalToken != null) {
          newConfigWithToken['tokens'] = originalToken;
        } else {
          // Try to find token from tokens list
          final token = _tokens.firstWhere(
            (t) => t['id'] == originalConfig['token_id'],
            orElse: () => {'name': 'Unknown Token', 'discord_id': ''},
          );
          newConfigWithToken['tokens'] = token;
        }
      }

      if (mounted) {
        showCustomNotification(
          context,
          'Configuration duplicated successfully',
          backgroundColor: const Color(0xFF7D3DFE),
        );
        
        // Add new config to the top of list and update counts
        setState(() {
          // Insert at beginning for newest first
          _autopostConfigs.insert(0, newConfigWithToken);
          _usedConfig++; // Update used config count
          _duplicatedConfigIds.add(newConfigId);
        });
        
        // Start duplicate cooldown for 5 seconds
        _startDuplicateCooldown(newConfigId);
        
        // Remove the duplicate label after 5 seconds
        Timer(const Duration(seconds: 5), () {
          if (mounted) {
            setState(() {
              _duplicatedConfigIds.remove(newConfigId);
            });
          }
        });
        
        // No need to reload data since we already added to list
      }
    } catch (e) {
      debugPrint('❌ Error duplicating config: $e');
      if (mounted) {
        // Check if it's a quota-related error in the message
        final errorMessage = e.toString().toLowerCase();
        if (errorMessage.contains('quota') || errorMessage.contains('limit') || errorMessage.contains('exceed')) {
          showCustomNotification(
            context,
            'Configuration quota limit reached',
            backgroundColor: Colors.orange,
          );
        } else {
          showCustomNotification(
            context,
            'Failed to duplicate configuration',
            backgroundColor: Colors.red,
          );
        }
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
  
  // Multi-select functionality methods
  void _onConfigLongPress(String configId) {
    setState(() {
      _isSelectionMode = true;
      _selectedConfigIds.add(configId);
    });
  }
  
  void _toggleSelection(String configId) {
    setState(() {
      if (_selectedConfigIds.contains(configId)) {
        _selectedConfigIds.remove(configId);
        if (_selectedConfigIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedConfigIds.add(configId);
      }
    });
  }
  
  void _selectAll() {
    setState(() {
      _selectedConfigIds.clear();
      _selectedConfigIds.addAll(_autopostConfigs.map((config) => config['id'] as String));
    });
  }
  
  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedConfigIds.clear();
    });
  }
  
  Future<void> _startAllSelected() async {
    if (_selectedConfigIds.isEmpty) return;
    
    try {
      // Update all selected configs to active status
      final updates = <Future>[];
      
      for (final configId in _selectedConfigIds) {
        final configIndex = _autopostConfigs.indexWhere((c) => c['id'] == configId);
        if (configIndex != -1) {
          // Update UI immediately
          setState(() {
            _autopostConfigs[configIndex]['status'] = true;
          });
          
          // Add database update to batch
          updates.add(
            _supabase
                .from('autopost_config')
                .update({
                  'status': true,
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('id', configId)
          );
        }
      }
      
      // Execute all updates
      await Future.wait(updates);
      
      if (mounted) {
        // Update total active jobs count
        setState(() {
          _totalActiveJobs = _autopostConfigs.where((config) => config['status'] == true).length;
        });
        
        showCustomNotification(
          context,
          'Started ${_selectedConfigIds.length} configurations',
          backgroundColor: Colors.green,
        );
        
        _exitSelectionMode();
      }
    } catch (e) {
      debugPrint('Error starting selected configs: $e');
      if (mounted) {
        showCustomNotification(
          context,
          'Failed to start some configurations',
          backgroundColor: Colors.red,
        );
      }
    }
  }
  
  Future<void> _stopAllSelected() async {
    if (_selectedConfigIds.isEmpty) return;
    
    try {
      // Update all selected configs to inactive status
      final updates = <Future>[];
      
      for (final configId in _selectedConfigIds) {
        final configIndex = _autopostConfigs.indexWhere((c) => c['id'] == configId);
        if (configIndex != -1) {
          // Update UI immediately
          setState(() {
            _autopostConfigs[configIndex]['status'] = false;
          });
          
          // Add database update to batch
          updates.add(
            _supabase
                .from('autopost_config')
                .update({
                  'status': false,
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('id', configId)
          );
        }
      }
      
      // Execute all updates
      await Future.wait(updates);
      
      if (mounted) {
        // Update total active jobs count
        setState(() {
          _totalActiveJobs = _autopostConfigs.where((config) => config['status'] == true).length;
        });
        
        showCustomNotification(
          context,
          'Stopped ${_selectedConfigIds.length} configurations',
          backgroundColor: Colors.orange,
        );
        
        _exitSelectionMode();
      }
    } catch (e) {
      debugPrint('Error stopping selected configs: $e');
      if (mounted) {
        showCustomNotification(
          context,
          'Failed to stop some configurations',
          backgroundColor: Colors.red,
        );
      }
    }
  }
  
  Future<void> _deleteAllSelected() async {
    if (_selectedConfigIds.isEmpty) return;
    
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
                          'Delete ${_selectedConfigIds.length} Configurations?',
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
                    'Are you sure you want to delete ${_selectedConfigIds.length} selected configurations? This action cannot be undone.',
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
                            'Delete All',
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
      try {
        // Delete all selected configs
        final deletes = <Future>[];
        final configsToRemove = <Map<String, dynamic>>[];
        
        for (final configId in _selectedConfigIds) {
          final config = _autopostConfigs.firstWhere(
            (c) => c['id'] == configId,
            orElse: () => {},
          );
          if (config.isNotEmpty) {
            configsToRemove.add(config);
            deletes.add(
              _supabase
                  .from('autopost_config')
                  .delete()
                  .eq('id', configId)
            );
          }
        }
        
        // Update UI immediately
        setState(() {
          _autopostConfigs.removeWhere(
            (config) => _selectedConfigIds.contains(config['id']),
          );
          _usedConfig = (_usedConfig - _selectedConfigIds.length).clamp(0, double.infinity).toInt();
        });
        
        // Execute all deletes
        await Future.wait(deletes);
        
        if (mounted) {
          showCustomNotification(
            context,
            'Deleted ${_selectedConfigIds.length} configurations',
            backgroundColor: Colors.blue,
          );
          
          _exitSelectionMode();
        }
      } catch (e) {
        debugPrint('Error deleting selected configs: $e');
        if (mounted) {
          showCustomNotification(
            context,
            'Failed to delete some configurations',
            backgroundColor: Colors.red,
          );
          // Don't reload, UI changes already reverted above
        }
      }
    }
  }
  
  bool _canCreateNewConfig() {
    if (_tokens.isEmpty) return false;
    if (_maxConfig <= 0) return false;
    return _usedConfig < _maxConfig;
  }
  
  bool _canDuplicateConfig(String configId) {
    if (!_canCreateNewConfig()) return false;
    return !_duplicateCooldowns.containsKey(configId);
  }
  
  String _getDuplicateTooltip(String configId) {
    if (!_canCreateNewConfig()) return 'Quota limit reached';
    if (_duplicateCooldowns.isNotEmpty) {
      return 'Wait ${_duplicateCooldowns.values.first}s before duplicating again';
    }
    return 'Duplicate';
  }
  
  void _startDuplicateCooldown(String configId) {
    setState(() {
      _duplicateCooldowns[configId] = 5;
    });
    
    // Cancel existing timer if any
    _duplicateCooldownTimer?.cancel();
    
    // Start countdown timer
    _duplicateCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          for (final key in _duplicateCooldowns.keys.toList()) {
            _duplicateCooldowns[key] = _duplicateCooldowns[key]! - 1;
            if (_duplicateCooldowns[key]! <= 0) {
              _duplicateCooldowns.remove(key);
            }
          }
        });
        
        // Cancel timer if no more cooldowns
        if (_duplicateCooldowns.isEmpty) {
          timer.cancel();
        }
      } else {
        timer.cancel();
      }
    });
  }
}

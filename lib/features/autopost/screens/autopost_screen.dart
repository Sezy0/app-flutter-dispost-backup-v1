import 'package:dispost_autopost/core/services/user_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dispost_autopost/core/providers/language_provider.dart';
import 'package:dispost_autopost/core/routing/app_routes.dart';
import 'package:dispost_autopost/core/widgets/custom_notification.dart';

class AutopostScreen extends StatefulWidget {
  const AutopostScreen({super.key});

  @override
  State<AutopostScreen> createState() => _AutopostScreenState();
}

class _AutopostScreenState extends State<AutopostScreen> {
  bool _hasFreeTrial = false;
  bool _hasBasicPlan = false;
  bool _hasProPlan = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkUserAccess();
  }

  Future<void> _checkUserAccess() async {
    try {
      // Optimasi: gunakan single query daripada 3 query terpisah
      final userAccessSummary = await UserService.getUserAccessSummary();
      
      if (mounted) {
        setState(() {
          final availableServers = userAccessSummary['availableServers'] as List<int>;
          _hasFreeTrial = availableServers.contains(1);
          _hasBasicPlan = availableServers.contains(2);
          _hasProPlan = availableServers.contains(3);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking user access: $e');
      if (mounted) {
        setState(() {
          _hasFreeTrial = false;
          _hasBasicPlan = false;
          _hasProPlan = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading server access...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return RefreshIndicator(
          onRefresh: _checkUserAccess,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                _buildHeader(languageProvider),
                const SizedBox(height: 16),
                
                // Manage Token Card - Always available with 1 max config
                _buildServerCard(
                  context: context,
                  languageProvider: languageProvider,
                  title: languageProvider.getLocalizedText('manage_token'),
                  subtitle: languageProvider.getLocalizedText('universal_access'),
                  description: languageProvider.getLocalizedText('manage_token_description'),
                  icon: Icons.token,
                  iconColor: Theme.of(context).primaryColor,
                  gradientColors: [Theme.of(context).primaryColor.withValues(alpha: 0.1), Theme.of(context).primaryColor.withValues(alpha: 0.05)],
                  isEnabled: true, // Always enabled
                  onTap: () => Navigator.of(context).pushNamed(AppRoutes.manageTokenRoute),
                ),
                const SizedBox(height: 8),
                
                // Server Cards - Urutan berdasarkan prioritas
                _buildServerCard(
                  context: context,
                  languageProvider: languageProvider,
                  title: languageProvider.getLocalizedText('server_1'),
                  subtitle: languageProvider.getLocalizedText('free_trial_access'),
                  description: languageProvider.getLocalizedText('basic_autopost_features'),
                  icon: Icons.cloud,
                  iconColor: Theme.of(context).primaryColor,
                  gradientColors: [Theme.of(context).primaryColor.withValues(alpha: 0.1), Theme.of(context).primaryColor.withValues(alpha: 0.05)],
                  isEnabled: _hasFreeTrial,
                  onTap: () => Navigator.of(context).pushNamed('/server1'),
                ),
                const SizedBox(height: 8),
                
                _buildServerCard(
                  context: context,
                  languageProvider: languageProvider,
                  title: languageProvider.getLocalizedText('server_2'),
                  subtitle: languageProvider.getLocalizedText('basic_plan_access'),
                  description: languageProvider.getLocalizedText('enhanced_features_basic'),
                  icon: Icons.cloud_queue,
                  iconColor: Theme.of(context).primaryColor,
                  gradientColors: [Theme.of(context).primaryColor.withValues(alpha: 0.1), Theme.of(context).primaryColor.withValues(alpha: 0.05)],
                  isEnabled: _hasBasicPlan,
                  onTap: () => Navigator.of(context).pushNamed('/server2'),
                ),
                const SizedBox(height: 8),
                
                _buildServerCard(
                  context: context,
                  languageProvider: languageProvider,
                  title: languageProvider.getLocalizedText('server_3'),
                  subtitle: languageProvider.getLocalizedText('pro_plan_access'),
                  description: languageProvider.getLocalizedText('premium_features_advanced'),
                  icon: Icons.cloud_done,
                  iconColor: Theme.of(context).primaryColor,
                  gradientColors: [Theme.of(context).primaryColor.withValues(alpha: 0.1), Theme.of(context).primaryColor.withValues(alpha: 0.05)],
                  isEnabled: _hasProPlan,
                  onTap: () => Navigator.of(context).pushNamed('/server3'),
                ),
                
                const SizedBox(height: 16),
                _buildFooterInfo(languageProvider),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildHeader(LanguageProvider languageProvider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).primaryColor.withValues(alpha: 0.1),
            Theme.of(context).primaryColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.auto_awesome,
            size: 28,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(height: 8),
          Text(
            languageProvider.getLocalizedText('autopost_servers'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            languageProvider.getLocalizedText('choose_server_based_on_plan'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildFooterInfo(LanguageProvider languageProvider) {
    return Column(
      children: [
        // Server Access Info Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.grey.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.blue,
                size: 16,
              ),
              const SizedBox(height: 6),
              Text(
                languageProvider.getLocalizedText('server_access_info'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                languageProvider.getLocalizedText('server_access_based_on_plan'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        
        // AutoPost Policy Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.orange.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_outlined,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.orange.shade400
                        : Colors.orange.shade700,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    languageProvider.getLocalizedText('important_notice'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.orange.shade300
                          : Colors.orange.shade800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                languageProvider.getLocalizedText('plan_expiry_notice'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.orange.shade300
                      : Colors.orange.shade800,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              _buildPolicyItem(
                languageProvider.getLocalizedText('autopost_stopped'),
              ),
              const SizedBox(height: 3),
              _buildPolicyItem(
                languageProvider.getLocalizedText('config_deletion_warning'),
              ),
              const SizedBox(height: 3),
              _buildPolicyItem(
                languageProvider.getLocalizedText('renew_plan_reminder'),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.orange.withValues(alpha: 0.15)
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.orange.withValues(alpha: 0.4)
                        : Colors.orange.shade200,
                  ),
                ),
                child: Text(
                  languageProvider.getLocalizedText('contact_support_before_deletion'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.orange.shade300  // Warna lebih terang untuk tema gelap
                        : Colors.orange.shade800,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildPolicyItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 6.0),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.orange.shade400  // Warna lebih terang untuk tema gelap
              : Colors.orange.shade700,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildServerCard({
    required BuildContext context,
    required LanguageProvider languageProvider,
    required String title,
    required String subtitle,
    required String description,
    required IconData icon,
    required Color iconColor,
    required List<Color> gradientColors,
    required bool isEnabled,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Card(
        elevation: isEnabled ? 6 : 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: isEnabled 
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradientColors,
                  )
                : null,
            color: !isEnabled ? Colors.grey.withValues(alpha: 0.1) : null,
          ),
          child: InkWell(
            onTap: isEnabled ? onTap : () {
              showCustomNotification(
                context,
                'Access to $title requires ${subtitle.toLowerCase()}',
                backgroundColor: Colors.orange,
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  // Icon Container
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isEnabled 
                          ? iconColor.withValues(alpha: 0.2)
                          : Colors.grey.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: isEnabled ? iconColor : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isEnabled 
                                ? Theme.of(context).textTheme.titleMedium?.color
                                : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isEnabled ? iconColor : Colors.grey,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          description,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isEnabled 
                                ? Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6)
                                : Colors.grey.withValues(alpha: 0.6),
                            fontSize: 11,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  // Status Icon
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isEnabled 
                          ? iconColor.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      isEnabled ? Icons.arrow_forward_ios : Icons.lock_outline,
                      size: 12,
                      color: isEnabled ? iconColor : Colors.grey,
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
}

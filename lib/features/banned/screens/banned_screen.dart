import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dispost_autopost/core/providers/language_provider.dart';
import 'package:dispost_autopost/core/services/user_service.dart';
import 'package:url_launcher/url_launcher.dart';

class BannedScreen extends StatefulWidget {
  final String? reason;
  final DateTime? bannedUntil;

  const BannedScreen({
    super.key,
    this.reason,
    this.bannedUntil,
  });

  @override
  State<BannedScreen> createState() => _BannedScreenState();
}

class _BannedScreenState extends State<BannedScreen> {
  UserProfile? _userProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await UserService.getCurrentUserProfile();
      if (!mounted) return;
      setState(() {
        _userProfile = profile;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final String? banReason = widget.reason ?? _userProfile?.banReason;
    final DateTime? banUntil = widget.bannedUntil ?? _userProfile?.bannedUntil;

    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.red.withValues(alpha: 0.1),
                  Colors.orange.withValues(alpha: 0.1),
                  Colors.white,
                ],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Warning Icon
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.red,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.block,
                        size: 60,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Title
                    Text(
                      languageProvider.getLocalizedText('account_suspended'),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Description
                    Text(
                      languageProvider.getLocalizedText('account_suspended_desc'),
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Ban Details Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            languageProvider.getLocalizedText('ban_details'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).textTheme.headlineMedium?.color,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Reason
                          if (banReason != null) ...[
                            _buildDetailItem(
                              Icons.info_outline,
                              languageProvider.getLocalizedText('reason'),
                              banReason,
                              context,
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Ban Duration
                          _buildDetailItem(
                            Icons.access_time,
                            languageProvider.getLocalizedText('ban_duration'),
                            banUntil != null
                                ? _formatBanDuration(banUntil, languageProvider)
                                : languageProvider.getLocalizedText('permanent'),
                            context,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Contact Support Section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.support_agent,
                            size: 32,
                            color: Colors.blue,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            languageProvider.getLocalizedText('need_help'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            languageProvider.getLocalizedText('contact_support_desc'),
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _contactSupport(context),
                            icon: Icon(Icons.chat),
                            label: Text(languageProvider.getLocalizedText('contact_support')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Logout Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _logout(context),
                        icon: Icon(Icons.logout),
                        label: Text(languageProvider.getLocalizedText('logout')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value, BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 16,
            color: Colors.red,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatBanDuration(DateTime bannedUntil, LanguageProvider languageProvider) {
    final now = DateTime.now();
    final difference = bannedUntil.difference(now);

    if (difference.isNegative) {
      return languageProvider.getLocalizedText('ban_expired');
    }

    if (difference.inDays > 0) {
      return '${difference.inDays} ${languageProvider.getLocalizedText('days_remaining')}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${languageProvider.getLocalizedText('hours_remaining')}';
    } else {
      return '${difference.inMinutes} ${languageProvider.getLocalizedText('minutes_remaining')}';
    }
  }

  Future<void> _openDiscordLink() async {
    const discordUrl = 'https://discord.gg/X3JCuRBgvf';
    final Uri url = Uri.parse(discordUrl);
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        // Handle error - could show a snackbar or alert
        debugPrint('Could not launch Discord URL');
      }
    } catch (e) {
      debugPrint('Error launching Discord URL: $e');
    }
  }

  void _contactSupport(BuildContext context) {
    // Implement contact support functionality
    // This could open email, open web browser, or show contact information
    showDialog(
      context: context,
      builder: (context) => Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) => AlertDialog(
          title: Text(languageProvider.getLocalizedText('contact_support')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(languageProvider.getLocalizedText('join_discord_support')),
              const SizedBox(height: 16),
              Text('Discord Server: DisPost'),
              const SizedBox(height: 8),
              SelectableText('https://discord.gg/X3JCuRBgvf'),
              const SizedBox(height: 8),
              Text('Hubungi admin: @Foxzys'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _openDiscordLink();
                  },
                  icon: Icon(Icons.open_in_new),
                  label: Text(languageProvider.getLocalizedText('open_discord')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF5865F2), // Discord brand color
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(languageProvider.getLocalizedText('close')),
            ),
          ],
        ),
      ),
    );
  }

  void _logout(BuildContext context) async {
    try {
      await UserService.logout();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      // Handle logout error silently or show notification
    }
  }
}

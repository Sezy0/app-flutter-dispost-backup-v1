import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dispost_autopost/core/routing/app_routes.dart';
import 'package:provider/provider.dart';
import 'package:dispost_autopost/core/providers/language_provider.dart';
import 'package:dispost_autopost/core/services/user_service.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
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
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    
    // Show confirmation dialog
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageProvider.getLocalizedText('sign_out')),
        content: Text(languageProvider.getLocalizedText('sign_out_confirmation')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(languageProvider.getLocalizedText('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(languageProvider.getLocalizedText('sign_out')),
          ),
        ],
      ),
    );

    if (shouldSignOut == true) {
      try {
        await Supabase.instance.client.auth.signOut();
        if (mounted) {
          // Navigate to login screen and clear all previous routes
          Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.loginRoute,
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${languageProvider.getLocalizedText('error_signing_out')}: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive padding based on screen size
          EdgeInsets responsivePadding;
          
          if (constraints.maxWidth <= 600) {
            // Mobile: minimal top padding
            responsivePadding = const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0);
          } else {
            // Tablet/Desktop: slightly more padding
            responsivePadding = const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0);
          }
          
          return ListView(
            padding: responsivePadding,
            children: [
          Consumer<LanguageProvider>(
            builder: (context, languageProvider, child) {
              return Column(
                children: [
                  _buildSection(
                    title: languageProvider.getLocalizedText('account'),
                    items: [
                      _buildMenuItem(
                        icon: Icons.email,
                        title: languageProvider.getLocalizedText('email'),
                        subtitle: Supabase.instance.client.auth.currentUser?.email ?? 
                          languageProvider.getLocalizedText('not_logged_in'),
                        onTap: () {
                          // Email tidak bisa diubah
                        },
                      ),
                      _buildMenuItem(
                        icon: Icons.person,
                        title: 'User ID',
                        subtitle: _isLoading 
                          ? 'Loading...' 
                          : (_userProfile?.userId ?? 'Not available'),
                        onTap: () {
                          // User ID tidak bisa diubah
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    title: languageProvider.getLocalizedText('preferences'),
                    items: [
                      _buildMenuItem(
                        icon: Icons.language,
                        title: languageProvider.getLocalizedText('language'),
                        subtitle: languageProvider.getLocalizedText('change_app_language'),
                        onTap: () {
                          Navigator.of(context).pushNamed(AppRoutes.languageRoute);
                        },
                      ),
                      _buildMenuItem(
                        icon: Icons.palette,
                        title: languageProvider.getLocalizedText('theme'),
                        subtitle: languageProvider.getLocalizedText('customize_app_appearance'),
                        onTap: () {
                          Navigator.of(context).pushNamed(AppRoutes.themeRoute);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    title: languageProvider.getLocalizedText('account_actions'),
                    items: [
                      _buildMenuItem(
                        icon: Icons.logout,
                        title: languageProvider.getLocalizedText('sign_out'),
                        subtitle: languageProvider.getLocalizedText('sign_out_description'),
                        onTap: _signOut,
                        isDestructive: true,
                      ),
                    ],
                  ),
                ],
              );
            },
            ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> items}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: items,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon, 
        color: isDestructive ? Colors.red : Theme.of(context).iconTheme.color,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive 
            ? Colors.red 
            : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark 
              ? Colors.white.withValues(alpha: 0.7) 
              : Colors.black.withValues(alpha: 0.7),
          fontSize: 14,
        ),
      ),
      trailing: (title == 'Email' || title == 'User ID') 
        ? null 
        : (title == 'Sign Out' || title.contains('Sign Out'))
          ? null
          : Icon(
              Icons.arrow_forward_ios,
              color: Theme.of(context).iconTheme.color!.withValues(alpha: 0.7),
              size: 16,
            ),
      onTap: onTap,
    );
  }
} 
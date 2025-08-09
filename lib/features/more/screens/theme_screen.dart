import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dispost_autopost/core/providers/theme_provider.dart';
import 'package:dispost_autopost/core/providers/language_provider.dart';

class ThemeScreen extends StatefulWidget {
  const ThemeScreen({super.key});

  @override
  State<ThemeScreen> createState() => _ThemeScreenState();
}

class _ThemeScreenState extends State<ThemeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Consumer<LanguageProvider>(
          builder: (context, languageProvider, child) {
            return Text(languageProvider.getLocalizedText('theme'), 
              style: TextStyle(color: Theme.of(context).appBarTheme.foregroundColor));
          },
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        iconTheme: Theme.of(context).appBarTheme.iconTheme,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return Column(
                children: [
                  _buildThemeOption(
                    title: 'Light',
                    subtitle: 'Light theme',
                    icon: Icons.light_mode,
                    isSelected: themeProvider.isLightMode,
                    onTap: () async {
                      await themeProvider.setTheme('light');
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildThemeOption(
                    title: 'Dark',
                    subtitle: 'Dark theme',
                    icon: Icons.dark_mode,
                    isSelected: themeProvider.isDarkMode,
                    onTap: () async {
                      await themeProvider.setTheme('dark');
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected 
          ? const Color(0xFF7d3dfe).withValues(alpha: 0.1)
          : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: isSelected
          ? Border.all(color: const Color(0xFF7d3dfe), width: 2)
          : null,
      ),
      child: ListTile(
        leading: Icon(
          icon,
            color: isSelected 
              ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF7d3dfe))
              : Theme.of(context).iconTheme.color,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected 
              ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF7d3dfe))
              : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: isSelected 
              ? (Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white.withValues(alpha: 0.8)
                  : const Color(0xFF7d3dfe).withValues(alpha: 0.7))
              : (Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white.withValues(alpha: 0.7) 
                  : Colors.black.withValues(alpha: 0.7)),
            fontSize: 14,
          ),
        ),
        trailing: isSelected 
          ? Icon(
              Icons.check_circle,
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF7d3dfe),
            )
          : null,
        onTap: onTap,
      ),
    );
  }
} 
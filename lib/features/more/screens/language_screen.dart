import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dispost_autopost/core/providers/language_provider.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Consumer<LanguageProvider>(
          builder: (context, languageProvider, child) {
            return Text(languageProvider.getLocalizedText('language'), 
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
          Consumer<LanguageProvider>(
            builder: (context, languageProvider, child) {
              return Column(
                children: [
                  _buildLanguageOption(
                    title: languageProvider.getLocalizedText('english'),
                    subtitle: languageProvider.getLocalizedText('english'),
                    isSelected: languageProvider.currentLanguage == 'English',
                    onTap: () async {
                      await languageProvider.setLanguage('English');
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildLanguageOption(
                    title: languageProvider.getLocalizedText('indonesia'),
                    subtitle: languageProvider.getLocalizedText('bahasa_indonesia'),
                    isSelected: languageProvider.currentLanguage == 'Indonesia',
                    onTap: () async {
                      await languageProvider.setLanguage('Indonesia');
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

  Widget _buildLanguageOption({
    required String title,
    required String subtitle,
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
          isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
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
        onTap: onTap,
      ),
    );
  }
} 
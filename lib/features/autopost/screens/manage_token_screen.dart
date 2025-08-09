import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dispost_autopost/core/providers/language_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dispost_autopost/core/widgets/custom_notification.dart';

class ManageTokenScreen extends StatefulWidget {
  const ManageTokenScreen({super.key});

  @override
  State<ManageTokenScreen> createState() => _ManageTokenScreenState();
}

class TokenData {
  final String id;
  final String name;
  final String token;
  final String discordId;
  final String avatarUrl;
  final bool status;
  final int configCount;

  TokenData({
    required this.id,
    required this.name,
    required this.token,
    required this.discordId,
    required this.avatarUrl,
    required this.status,
    this.configCount = 0,
  });

  factory TokenData.fromJson(Map<String, dynamic> json) {
    return TokenData(
      id: json['id'],
      name: json['name'],
      token: json['token'],
      discordId: json['discord_id'],
      avatarUrl: json['avatar_url'],
      status: json['status'] ?? false,
      configCount: json['config_count'] ?? 0,
    );
  }
}

class _ManageTokenScreenState extends State<ManageTokenScreen> {
  final TextEditingController _tokenController = TextEditingController();
  final SupabaseClient _supabase = Supabase.instance.client;
  
  bool _isLoading = false;
  bool _tokenVisible = false;
  final List<TokenData> _tokens = [];

  @override
  void initState() {
    super.initState();
    _loadTokens();
  }

  Future<void> _loadTokens() async {
    setState(() {
      _isLoading = true;
      _tokens.clear(); // Reset tokens list
    });
    
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Get tokens first
      final response = await _supabase
          .from('tokens')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final tokens = (response as List)
          .map((token) => TokenData.fromJson(token))
          .toList();

      // Get config count for each token
      for (int i = 0; i < tokens.length; i++) {
        final configCountResponse = await _supabase
            .from('autopost_config')
            .select('id')
            .eq('token_id', tokens[i].id);
        
        final configCount = (configCountResponse as List).length;
        
        // Create new token data with config count
        _tokens.add(TokenData(
          id: tokens[i].id,
          name: tokens[i].name,
          token: tokens[i].token,
          discordId: tokens[i].discordId,
          avatarUrl: tokens[i].avatarUrl,
          status: tokens[i].status,
          configCount: configCount,
        ));
      }
    } catch (e) {
      debugPrint('Error loading tokens: $e');
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<Map<String, dynamic>?> _validateDiscordToken(String token) async {
    try {
      final response = await http.get(
        Uri.parse('https://discord.com/api/users/@me'),
        headers: {
          'Authorization': token, // User token langsung tanpa prefix
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      debugPrint('Error validating token: $e');
    }
    return null;
  }

  Future<void> _addToken(LanguageProvider languageProvider) async {
    if (_tokenController.text.isEmpty) {
      showCustomNotification(
        context,
        languageProvider.getLocalizedText('please_enter_token'),
        backgroundColor: Colors.red,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Validate Discord token
      final userData = await _validateDiscordToken(_tokenController.text);
      if (userData == null) {
        if (mounted) {
          showCustomNotification(
            context,
            languageProvider.getLocalizedText('invalid_token'),
            backgroundColor: Colors.red,
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Check if token already exists
      final existingToken = await _supabase
          .from('tokens')
          .select()
          .eq('user_id', user.id)
          .eq('discord_id', userData['id'])
          .maybeSingle();

      if (existingToken != null) {
        if (mounted) {
          showCustomNotification(
            context,
            languageProvider.getLocalizedText('token_already_exists'),
            backgroundColor: Colors.orange,
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Save to database
      await _supabase.from('tokens').insert({
        'user_id': user.id,
        'name': userData['username'] ?? 'Discord User',
        'token': _tokenController.text,
        'discord_id': userData['id'],
        'avatar_url': userData['avatar'] != null 
            ? 'https://cdn.discordapp.com/avatars/${userData['id']}/${userData['avatar']}.png'
            : '',
        'status': true,
      });

      _tokenController.clear();
      if (mounted) {
        showCustomNotification(
          context,
          languageProvider.getLocalizedText('token_added_successfully'),
          backgroundColor: Colors.green,
        );
      }
      _loadTokens();
    } catch (e) {
      if (mounted) {
        showCustomNotification(
          context,
          languageProvider.getLocalizedText('error_adding_token'),
          backgroundColor: Colors.red,
        );
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _deleteToken(String tokenId, LanguageProvider languageProvider) async {
    // Get token data to show config count in warning
    final tokenIndex = _tokens.indexWhere((t) => t.id == tokenId);
    final tokenData = tokenIndex != -1 ? _tokens[tokenIndex] : null;
    
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
                          'Delete Token?',
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Are you sure you want to delete this token? This action cannot be undone.',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      if (tokenData != null && tokenData.configCount > 0) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDarkMode 
                                ? Colors.orange.withValues(alpha: 0.1)
                                : Colors.orange.withValues(alpha: 0.08),
                            border: Border.all(
                              color: isDarkMode 
                                  ? Colors.orange.withValues(alpha: 0.3)
                                  : Colors.orange.withValues(alpha: 0.2),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.orange[700],
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Warning: ${tokenData.configCount} autopost configuration${tokenData.configCount > 1 ? 's' : ''} using this token will also be deleted permanently.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDarkMode ? Colors.orange[300] : Colors.orange[800],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
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
                            languageProvider.getLocalizedText('cancel'),
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
                          child: Text(
                            languageProvider.getLocalizedText('delete'),
                            style: const TextStyle(
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

    if (confirmed == true) {
      try {
        await _supabase.from('tokens').delete().eq('id', tokenId);
        if (mounted) {
          showCustomNotification(
            context,
            languageProvider.getLocalizedText('token_deleted_successfully'),
            backgroundColor: const Color(0xFF7d3dfe),
          );
        }
        _loadTokens();
      } catch (e) {
        if (mounted) {
          showCustomNotification(
            context,
            languageProvider.getLocalizedText('error_deleting_token'),
            backgroundColor: Colors.red,
          );
        }
      }
    }
  }

  Future<void> _checkTokenValidity(String tokenId, String token, LanguageProvider languageProvider) async {
    // Find token index in current list
    final tokenIndex = _tokens.indexWhere((t) => t.id == tokenId);
    if (tokenIndex == -1) return;
    
    // Show loading only for the specific token being validated
    setState(() {
      _tokens[tokenIndex] = TokenData(
        id: _tokens[tokenIndex].id,
        name: _tokens[tokenIndex].name,
        token: _tokens[tokenIndex].token,
        discordId: _tokens[tokenIndex].discordId,
        avatarUrl: _tokens[tokenIndex].avatarUrl,
        status: _tokens[tokenIndex].status,
        configCount: _tokens[tokenIndex].configCount,
      );
    });
    
    try {
      // Validate token dengan Discord API
      final userData = await _validateDiscordToken(token);
      
      if (userData != null) {
        // Token valid - update dengan data dari Discord
        await _supabase
            .from('tokens')
            .update({
              'status': true,
              'name': userData['username'] ?? 'Discord User',
              'avatar_url': userData['avatar'] != null 
                  ? 'https://cdn.discordapp.com/avatars/${userData['id']}/${userData['avatar']}.png'
                  : ''
            })
            .eq('id', tokenId);
        
        // Update only this specific token in the list
        setState(() {
          _tokens[tokenIndex] = TokenData(
            id: _tokens[tokenIndex].id,
            name: userData['username'] ?? 'Discord User',
            token: _tokens[tokenIndex].token,
            discordId: _tokens[tokenIndex].discordId,
            avatarUrl: userData['avatar'] != null 
                ? 'https://cdn.discordapp.com/avatars/${userData['id']}/${userData['avatar']}.png'
                : '',
            status: true,
            configCount: _tokens[tokenIndex].configCount,
          );
        });
        
        if (mounted) {
          showCustomNotification(
            context,
            '${languageProvider.getLocalizedText('token_valid')}: ${userData['username'] ?? 'Unknown'}',
            backgroundColor: Colors.green,
          );
        }
      } else {
        // Token invalid - update database
        await _supabase
            .from('tokens')
            .update({
              'status': false,
              'name': 'Invalid Token',
              'avatar_url': ''
            })
            .eq('id', tokenId);
        
        // Update only this specific token in the list
        setState(() {
          _tokens[tokenIndex] = TokenData(
            id: _tokens[tokenIndex].id,
            name: 'Invalid Token',
            token: _tokens[tokenIndex].token,
            discordId: _tokens[tokenIndex].discordId,
            avatarUrl: '',
            status: false,
            configCount: _tokens[tokenIndex].configCount,
          );
        });
        
        if (mounted) {
          showCustomNotification(
            context,
            languageProvider.getLocalizedText('token_invalid'),
            backgroundColor: Colors.red,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showCustomNotification(
          context,
          languageProvider.getLocalizedText('error_checking_token'),
          backgroundColor: Colors.red,
        );
      }
    }
  }

  Future<void> _showChangeTokenDialog(TokenData currentToken, LanguageProvider languageProvider) async {
    final TextEditingController newTokenController = TextEditingController();
    bool isTokenVisible = false;
    bool isValidating = false;
    Map<String, dynamic>? newTokenData;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                constraints: const BoxConstraints(
                  maxWidth: 350,
                  maxHeight: 420,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header - Simplified
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.swap_horiz,
                            color: const Color(0xFF7d3dfe),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Change Token',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                            iconSize: 20,
                            onPressed: () {
                              newTokenController.dispose();
                              Navigator.of(context).pop();
                            },
                            icon: Icon(
                              Icons.close,
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Divider
                    Divider(
                      height: 1,
                      color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                    ),
                    
                    // Content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Current Token Info - Compact
                            Text(
                              'Current',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                                  backgroundImage: currentToken.avatarUrl.isNotEmpty 
                                      ? NetworkImage(currentToken.avatarUrl) 
                                      : null,
                                  child: currentToken.avatarUrl.isEmpty 
                                      ? Icon(Icons.person, color: isDarkMode ? Colors.grey[600] : Colors.grey[500], size: 14)
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        currentToken.name,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        currentToken.discordId,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                                          fontSize: 11,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // New Token Input
                            Text(
                              'New Token',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 38,
                              child: TextFormField(
                                controller: newTokenController,
                                obscureText: !isTokenVisible,
                                style: const TextStyle(fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'Paste your Discord token',
                                  hintStyle: TextStyle(
                                    color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                                    fontSize: 13,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.key, 
                                    color: isDarkMode ? Colors.grey[600] : Colors.grey[500],
                                    size: 16,
                                  ),
                                  suffixIcon: IconButton(
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(8),
                                    iconSize: 16,
                                    icon: Icon(
                                      isTokenVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      color: isDarkMode ? Colors.grey[600] : Colors.grey[500],
                                    ),
                                    onPressed: () {
                                      setDialogState(() {
                                        isTokenVisible = !isTokenVisible;
                                      });
                                    },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFF7d3dfe), width: 1.5),
                                  ),
                                  filled: true,
                                  fillColor: isDarkMode ? Colors.grey[850] : Colors.grey[50],
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            // Validation Button
                            SizedBox(
                              width: double.infinity,
                              height: 34,
                              child: ElevatedButton(
                                onPressed: isValidating ? null : () async {
                                  if (newTokenController.text.trim().isEmpty) {
                                    showCustomNotification(
                                      context,
                                      'Please enter a token',
                                      backgroundColor: Colors.red,
                                    );
                                    return;
                                  }
                                  
                                  setDialogState(() {
                                    isValidating = true;
                                    newTokenData = null;
                                  });
                                  
                                  final userData = await _validateDiscordToken(newTokenController.text.trim());
                                  
                                  setDialogState(() {
                                    isValidating = false;
                                    newTokenData = userData;
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF7d3dfe),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: isValidating 
                                    ? SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: isDarkMode ? Colors.white : Colors.black87,
                                        ),
                                      )
                                    : Text(
                                        'Validate',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                              ),
                            ),
                            
                            // Validation Result - Minimal
                            if (newTokenData != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isDarkMode 
                                      ? Colors.green.withValues(alpha: 0.1)
                                      : Colors.green.withValues(alpha: 0.08),
                                  border: Border.all(
                                    color: isDarkMode 
                                        ? Colors.green.withValues(alpha: 0.3)
                                        : Colors.green.withValues(alpha: 0.2),
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            newTokenData!['username'] ?? 'Discord User',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: isDarkMode ? Colors.green[400] : Colors.green[700],
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            newTokenData!['id'],
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDarkMode ? Colors.green[600] : Colors.green[600],
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    
                    // Divider
                    Divider(
                      height: 1,
                      color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                    ),
                    
                    // Actions - Simplified
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                newTokenController.dispose();
                                Navigator.of(context).pop();
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: (newTokenData != null && !isValidating) ? () async {
                                final navigator = Navigator.of(context);
                                final confirmed = await _showChangeTokenConfirmation(
                                  currentToken, 
                                  newTokenData!, 
                                  languageProvider
                                );
                                
                                if (confirmed == true) {
                                  navigator.pop();
                                  await _changeToken(
                                    currentToken.id, 
                                    newTokenController.text.trim(), 
                                    newTokenData!, 
                                    languageProvider
                                  );
                                }
                              } : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7d3dfe),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'Change Token',
                                style: TextStyle(
                                  fontSize: 13,
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
      },
    );
  }
  
  Future<bool?> _showChangeTokenConfirmation(
    TokenData currentToken, 
    Map<String, dynamic> newTokenData, 
    LanguageProvider languageProvider
  ) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        
        return Dialog(
          backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            constraints: const BoxConstraints(
              maxWidth: 320,
              maxHeight: 380,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header - Minimal
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        Icons.swap_horiz,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                        size: 24,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Confirm Change',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Divider
                Divider(
                  height: 1,
                  color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                ),
                
                // Content - Simplified
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Current token
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                                    backgroundImage: currentToken.avatarUrl.isNotEmpty 
                                        ? NetworkImage(currentToken.avatarUrl) 
                                        : null,
                                    child: currentToken.avatarUrl.isEmpty 
                                        ? Icon(Icons.person, color: isDarkMode ? Colors.grey[600] : Colors.grey[500], size: 12)
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          currentToken.name,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          currentToken.discordId,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        // Arrow
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Icon(
                            Icons.arrow_downward,
                            color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                            size: 16,
                          ),
                        ),
                        
                        // New token
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7d3dfe).withValues(alpha: isDarkMode ? 0.1 : 0.05),
                            border: Border.all(
                              color: const Color(0xFF7d3dfe).withValues(alpha: isDarkMode ? 0.3 : 0.2),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'New',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF7d3dfe),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                                    backgroundImage: newTokenData['avatar'] != null 
                                        ? NetworkImage('https://cdn.discordapp.com/avatars/${newTokenData['id']}/${newTokenData['avatar']}.png') 
                                        : null,
                                    child: newTokenData['avatar'] == null 
                                        ? Icon(Icons.person, color: isDarkMode ? Colors.grey[600] : Colors.grey[500], size: 12)
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          newTokenData['username'] ?? 'Discord User',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          newTokenData['id'],
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Divider
                Divider(
                  height: 1,
                  color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                ),
                
                // Actions - Minimal
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7d3dfe),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Confirm',
                            style: TextStyle(
                              fontSize: 13,
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
  }
  
  Future<void> _changeToken(
    String tokenId, 
    String newToken, 
    Map<String, dynamic> newTokenData, 
    LanguageProvider languageProvider
  ) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      
      // Check if new token already exists for another entry
      final existingToken = await _supabase
          .from('tokens')
          .select()
          .eq('user_id', user.id)
          .eq('discord_id', newTokenData['id'])
          .neq('id', tokenId)
          .maybeSingle();
      
      if (existingToken != null) {
        if (mounted) {
          showCustomNotification(
            context,
            'This Discord account already has a token registered',
            backgroundColor: Colors.orange,
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // Update token in database
      await _supabase
          .from('tokens')
          .update({
            'token': newToken,
            'name': newTokenData['username'] ?? 'Discord User',
            'discord_id': newTokenData['id'],
            'avatar_url': newTokenData['avatar'] != null 
                ? 'https://cdn.discordapp.com/avatars/${newTokenData['id']}/${newTokenData['avatar']}.png'
                : '',
            'status': true,
          })
          .eq('id', tokenId);
      
      // This ensures continuity of service when token is changed
      await _updateConfigurationsForToken(tokenId, newToken);
      
      if (mounted) {
        showCustomNotification(
          context,
          'Token changed successfully to: ${newTokenData['username']}',
          backgroundColor: Colors.green,
        );
      }
      _loadTokens();
      
    } catch (e) {
      debugPrint('Error changing token: $e');
      if (mounted) {
        showCustomNotification(
          context,
          'Error changing token',
          backgroundColor: Colors.red,
        );
      }
    }
    
    setState(() {
      _isLoading = false;
    });
  }
  
  Future<void> _updateConfigurationsForToken(String tokenId, String newToken) async {
    try {
      // Update all autopost configurations that use this token
      // This ensures continuity of service when token is changed
      await _supabase
          .from('autopost_config')
          .update({'token': newToken, 'updated_at': DateTime.now().toIso8601String()})
          .eq('token_id', tokenId);
      
      debugPrint('Updated configurations for token: $tokenId');
    } catch (e) {
      debugPrint('Error updating configurations: $e');
    }
  }



  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(languageProvider.getLocalizedText('manage_token')),
            elevation: 0,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            foregroundColor: Theme.of(context).textTheme.titleLarge?.color,
          ),
          body: _isLoading && _tokens.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadTokens,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Add Token Form
                        _buildAddTokenForm(languageProvider),
                        const SizedBox(height: 24),

                        // Add Token Button
                        _buildAddTokenButton(languageProvider),
                        const SizedBox(height: 24),

                        // Token List
                        _buildTokenList(languageProvider),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }


  Widget _buildAddTokenForm(LanguageProvider languageProvider) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[800]!
              : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                  color: const Color(0xFF7d3dfe).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.add,
                    color: const Color(0xFF7d3dfe),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  languageProvider.getLocalizedText('add_token'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Discord Token Field
            SizedBox(
              height: 40,
              child: TextFormField(
                controller: _tokenController,
                obscureText: !_tokenVisible,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  labelText: languageProvider.getLocalizedText('discord_token'),
                  hintText: languageProvider.getLocalizedText('enter_discord_token'),
                  hintStyle: const TextStyle(fontSize: 14),
                  labelStyle: const TextStyle(fontSize: 14),
                  prefixIcon: const Icon(Icons.vpn_key, size: 18),
                  suffixIcon: IconButton(
                    iconSize: 18,
                    icon: Icon(_tokenVisible ? Icons.visibility_off : Icons.visibility),
                    onPressed: () {
                      setState(() {
                        _tokenVisible = !_tokenVisible;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF7d3dfe), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddTokenButton(LanguageProvider languageProvider) {
    return SizedBox(
      width: double.infinity,
      height: 36,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : () => _addToken(languageProvider),
        icon: _isLoading 
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.add, size: 16),
        label: Text(
          _isLoading 
              ? languageProvider.getLocalizedText('validating_token')
              : languageProvider.getLocalizedText('add_token'),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7d3dfe),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          elevation: 1,
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildTokenList(LanguageProvider languageProvider) {
    if (_tokens.isEmpty) {
      return SizedBox(
        width: double.infinity,
        child: Container(
          margin: const EdgeInsets.only(top: 20),
          child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]?.withValues(alpha: 0.5)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[700]!
                      : Colors.grey[200]!,
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[700]
                          : Colors.grey[200],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.token,
                      size: 48,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[400]
                          : Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    languageProvider.getLocalizedText('no_tokens_found'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[300]
                          : Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    languageProvider.getLocalizedText('add_first_token'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[400]
                          : Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${languageProvider.getLocalizedText('your_tokens')} (${_tokens.length})',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(_tokens.length, (index) {
          final token = _tokens[index];
          return _buildTokenCard(token, languageProvider);
        }),
      ],
    );
  }

  Widget _buildTokenCard(TokenData token, LanguageProvider languageProvider) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[800]!
              : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Baris 1: Avatar + Username (kiri) dan Status Badge (kanan)
                Row(
                  children: [
                    // Avatar
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFF7d3dfe).withValues(alpha: 0.1),
                      backgroundImage: token.avatarUrl.isNotEmpty 
                          ? NetworkImage(token.avatarUrl) 
                          : null,
                      child: token.avatarUrl.isEmpty 
                          ? Icon(Icons.person, color: const Color(0xFF7d3dfe), size: 16)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    
                    // Username
                    Expanded(
                      child: Text(
                        token.name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: token.status ? Colors.green.withAlpha(30) : Colors.red.withAlpha(30),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            token.status ? Icons.check_circle : Icons.error,
                            size: 12,
                            color: token.status ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            token.status 
                                ? languageProvider.getLocalizedText('valid')
                                : languageProvider.getLocalizedText('invalid'),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: token.status ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w500,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 6),
                
                // Baris 2: ID (kiri) dan Action Buttons (kanan)
                Row(
                  children: [
                    // ID dan Config Count dengan indentasi sejajar username
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 42), // 32 (radius*2) + 10 (spacing)
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ID: ${token.discordId}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.settings_outlined,
                                  size: 10,
                                  color: token.configCount > 0 
                                      ? const Color(0xFF7d3dfe)
                                      : Colors.grey[500],
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${token.configCount} config${token.configCount != 1 ? 's' : ''}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: token.configCount > 0 
                                        ? const Color(0xFF7d3dfe)
                                        : Colors.grey[500],
                                    fontSize: 10,
                                    fontWeight: token.configCount > 0 
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Action Buttons di pojok kanan - tetap ukuran
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Check Validity Button
                        InkWell(
                          onTap: () => _checkTokenValidity(token.id, token.token, languageProvider),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.refresh,
                              size: 16,
                              color: const Color(0xFF7d3dfe),
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        // Change Token Button
                        InkWell(
                          onTap: () => _showChangeTokenDialog(token, languageProvider),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.edit,
                              size: 16,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        // Delete Button
                        InkWell(
                          onTap: () => _deleteToken(token.id, languageProvider),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.delete_outline,
                              size: 16,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }
}

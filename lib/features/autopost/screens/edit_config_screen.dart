import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dispost_autopost/core/providers/language_provider.dart';
import 'package:dispost_autopost/core/services/autopost_config_service.dart';
import 'package:dispost_autopost/core/models/autopost_config.dart';
import 'package:dispost_autopost/core/widgets/custom_notification.dart';
import 'package:dispost_autopost/core/utils/timezone_utils.dart';
import 'package:timezone/timezone.dart' as tz;

class EditConfigScreen extends StatefulWidget {
  final Map<String, dynamic> config;

  const EditConfigScreen({
    super.key,
    required this.config,
  });

  @override
  State<EditConfigScreen> createState() => _EditConfigScreenState();
}

class _EditConfigScreenState extends State<EditConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _channelIdController = TextEditingController();
  final _webhookUrlController = TextEditingController();
  final _delayController = TextEditingController();
  final _minDelayController = TextEditingController();
  final _maxDelayController = TextEditingController();
  final _messageController = TextEditingController();

  List<TokenOption> _tokens = [];
  TokenOption? _selectedToken;
  tz.TZDateTime? _selectedEndTime;
  bool _isLoading = false;
  bool _isLoadingTokens = true;

  @override
  void initState() {
    super.initState();
    _loadTokens();
    _populateFields();
    
    // Add listeners for real-time validation
    _delayController.addListener(_validateDelays);
    _minDelayController.addListener(_validateDelays);
    _maxDelayController.addListener(_validateDelays);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _channelIdController.dispose();
    _webhookUrlController.dispose();
    _delayController.dispose();
    _minDelayController.dispose();
    _maxDelayController.dispose();
    _messageController.dispose();
    super.dispose();
  }
  
  void _validateDelays() {
    // Delay validation is handled in form validation
  }
  

  void _populateFields() {
    try {
      // Fill form fields with existing config data
      _nameController.text = widget.config['name']?.toString() ?? '';
      _channelIdController.text = widget.config['channel_id']?.toString() ?? '';
      _webhookUrlController.text = widget.config['webhook_url']?.toString() ?? '';
      
      // Get delay values and validate them
      int delay = widget.config['delay'] ?? 300;
      int minDelay = widget.config['min_delay'] ?? 60;
      int maxDelay = widget.config['max_delay'] ?? 600;
      
      // Fix invalid delay hierarchy by setting sensible defaults
      if (!AutopostConfigService.isValidDelayHierarchy(minDelay, delay, maxDelay)) {
        debugPrint('Invalid delay hierarchy detected. Fixing: min=$minDelay, delay=$delay, max=$maxDelay');
        
        // If delay is way too high, reset to reasonable values
        if (delay > 86400) { // More than 24 hours
          delay = 300; // 5 minutes default
        }
        
        // Ensure min <= delay <= max
        if (minDelay > delay) {
          minDelay = delay;
        }
        if (maxDelay < delay) {
          maxDelay = delay;
        }
        
        // Show warning to user
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showCustomNotification(
              context,
              'Invalid delay configuration detected and auto-corrected. Please verify the values.',
              backgroundColor: Colors.orange,
            );
          });
        }
      }
      
      _delayController.text = delay.toString();
      _minDelayController.text = minDelay.toString();
      _maxDelayController.text = maxDelay.toString();
      _messageController.text = widget.config['message']?.toString() ?? '';

      // Parse end_time if exists
      if (widget.config['end_time'] != null) {
        final endTimeStr = widget.config['end_time'].toString();
        if (endTimeStr.isNotEmpty && endTimeStr != 'null') {
          try {
            final utcDateTime = DateTime.parse(endTimeStr);
            _selectedEndTime = tz.TZDateTime.from(utcDateTime, TimezoneUtils.jakartaLocation);
          } catch (e) {
            debugPrint('Error parsing end_time: $e');
            // If parsing fails, clear the end time
            _selectedEndTime = null;
          }
        }
      }
    } catch (e) {
      debugPrint('Error populating fields: $e');
      // Show error notification
      if (mounted) {
        showCustomNotification(
          context,
          'Error loading configuration data',
          backgroundColor: Colors.orange,
        );
      }
    }
  }

  Future<void> _loadTokens() async {
    try {
      final tokens = await AutopostConfigService.getUserTokens();
      if (mounted) {
        setState(() {
          _tokens = tokens;
          _isLoadingTokens = false;
          
          // Select the token that matches the config's token_id
          final configTokenId = widget.config['token_id']?.toString();
          if (configTokenId != null && configTokenId.isNotEmpty) {
            try {
              _selectedToken = tokens.firstWhere(
                (token) => token.id == configTokenId,
              );
            } catch (e) {
              // Token not found in current active tokens
              debugPrint('Selected token not found in active tokens: $configTokenId');
              // Create a placeholder token or set to null
              if (tokens.isNotEmpty) {
                _selectedToken = tokens.first;
                if (mounted) {
                  showCustomNotification(
                    context,
                    'Original token not found. Please select a new token.',
                    backgroundColor: Colors.orange,
                  );
                }
              }
            }
          } else if (tokens.isNotEmpty) {
            // No token_id specified, select first available
            _selectedToken = tokens.first;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading tokens: $e');
      if (mounted) {
        setState(() {
          _isLoadingTokens = false;
        });
        showCustomNotification(
          context,
          'Failed to load Discord tokens. Please try refreshing.',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  Future<void> _selectEndTime() async {
    final now = TimezoneUtils.nowInJakarta();
    
    // Use existing end time as initial, or tomorrow if none
    final initialDateTime = _selectedEndTime ?? now.add(const Duration(days: 1));
    
    // Select date
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDateTime.isAfter(now) ? initialDateTime : now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (selectedDate == null) return;

    if (!mounted) return;

    // Select time
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: initialDateTime.hour, 
        minute: initialDateTime.minute,
      ),
    );

    if (selectedTime == null) return;

    // Combine date and time in Jakarta timezone
    final jakartaDateTime = tz.TZDateTime(
      TimezoneUtils.jakartaLocation,
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    if (mounted) {
      setState(() {
        _selectedEndTime = jakartaDateTime;
      });
    }
  }

  Future<void> _updateConfig() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      showCustomNotification(
        context,
        'Please fix the validation errors before saving.',
        backgroundColor: Colors.orange,
      );
      return;
    }

    // Validate token selection
    if (_selectedToken == null) {
      showCustomNotification(
        context,
        'Please select a Discord token',
        backgroundColor: Colors.red,
      );
      return;
    }

    // Parse and validate delay values
    final delay = int.tryParse(_delayController.text.trim()) ?? 0;
    final minDelay = int.tryParse(_minDelayController.text.trim()) ?? 0;
    final maxDelay = int.tryParse(_maxDelayController.text.trim()) ?? 0;

    // Validate individual delays
    if (!AutopostConfigService.isValidDelay(minDelay) ||
        !AutopostConfigService.isValidDelay(delay) ||
        !AutopostConfigService.isValidDelay(maxDelay)) {
      showCustomNotification(
        context,
        'Delay values must be between 10 seconds and 24 hours (86400 seconds)',
        backgroundColor: Colors.red,
      );
      return;
    }

    // Validate delay hierarchy
    if (!AutopostConfigService.isValidDelayHierarchy(minDelay, delay, maxDelay)) {
      showCustomNotification(
        context,
        'Invalid delay configuration: Min Delay ≤ Delay ≤ Max Delay\n\nCurrent values:\n• Min: ${minDelay}s\n• Delay: ${delay}s\n• Max: ${maxDelay}s\n\n⚠️ Main Delay (${delay}s) must be between Min Delay (${minDelay}s) and Max Delay (${maxDelay}s)',
        backgroundColor: Colors.red,
      );
      return;
    }

    // Validate end time is in the future (if set)
    if (_selectedEndTime != null) {
      final now = TimezoneUtils.nowInJakarta();
      if (_selectedEndTime!.isBefore(now)) {
        showCustomNotification(
          context,
          'End time must be in the future',
          backgroundColor: Colors.red,
        );
        return;
      }
    }

    // Validate message content
    final messageContent = _messageController.text.trim();
    if (messageContent.isEmpty) {
      showCustomNotification(
        context,
        'Message content cannot be empty',
        backgroundColor: Colors.red,
      );
      return;
    }

    if (messageContent.length > 2000) {
      showCustomNotification(
        context,
        'Message content is too long (${messageContent.length}/2000 characters)',
        backgroundColor: Colors.red,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final configId = widget.config['id']?.toString();
      if (configId == null || configId.isEmpty) {
        throw Exception('Configuration ID not found');
      }

      final success = await AutopostConfigService.updateConfig(
        configId: configId,
        tokenId: _selectedToken!.id,
        name: _nameController.text.trim().isEmpty 
            ? 'My Config' 
            : _nameController.text.trim(),
        channelId: _channelIdController.text.trim(),
        webhookUrl: _webhookUrlController.text.trim().isEmpty 
            ? null 
            : _webhookUrlController.text.trim(),
        delay: delay,
        endTime: _selectedEndTime,
        minDelay: minDelay,
        maxDelay: maxDelay,
        message: messageContent,
      );

      if (mounted) {
        if (success) {
          showCustomNotification(
            context,
            'Configuration updated successfully!',
            backgroundColor: Colors.green,
          );
          Navigator.of(context).pop(true); // Return true to indicate success
        } else {
          showCustomNotification(
            context,
            'Failed to update configuration. Please check your input and try again.',
            backgroundColor: Colors.red,
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating configuration: $e');
      if (mounted) {
        String errorMessage = 'Error updating configuration';
        if (e.toString().contains('timeout')) {
          errorMessage = 'Request timed out. Please check your internet connection.';
        } else if (e.toString().contains('not found')) {
          errorMessage = 'Configuration not found. It may have been deleted.';
        } else if (e.toString().contains('permission')) {
          errorMessage = 'You do not have permission to update this configuration.';
        }
        
        showCustomNotification(
          context,
          errorMessage,
          backgroundColor: Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ===== Shared UI components to match Add Config =====
  Widget _buildModernTokenSelection(LanguageProvider languageProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _showTokenPickerBottomSheet,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(
                color: _selectedToken == null
                    ? Theme.of(context).dividerColor.withValues(alpha: 0.6)
                    : Theme.of(context).primaryColor.withValues(alpha: 0.5),
                width: _selectedToken == null ? 1 : 2,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: _selectedToken != null &&
                            _selectedToken!.avatarUrl != null &&
                            _selectedToken!.avatarUrl!.isNotEmpty
                        ? Image.network(
                            _selectedToken!.avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.person,
                              color: Theme.of(context).primaryColor,
                            ),
                          )
                        : Icon(
                            Icons.person_add_outlined,
                            color: Theme.of(context).primaryColor,
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _selectedToken?.displayName ?? 'Select Discord Token',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedToken != null
                            ? 'ID: ${_selectedToken!.discordId}'
                            : 'Choose which bot token to use',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color
                                  ?.withValues(alpha: 0.65),
                            ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ),
          ),
        ),
        if (_selectedToken != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Selected: ${_selectedToken!.displayName}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _showTokenPickerBottomSheet() async {
    final selected = await showModalBottomSheet<TokenOption>(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.token, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Choose Discord Token',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(this.context).pushNamed('/manage-token');
                      },
                      icon: const Icon(Icons.manage_accounts_outlined, size: 18),
                      label: const Text('Manage'),
                    )
                  ],
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _tokens.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                  ),
                  itemBuilder: (context, index) {
                    final t = _tokens[index];
                    final isSelected = _selectedToken?.id == t.id;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: CircleAvatar(
                        radius: 22,
                        backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                        foregroundColor: Theme.of(context).primaryColor,
                        backgroundImage: (t.avatarUrl != null && t.avatarUrl!.isNotEmpty)
                            ? NetworkImage(t.avatarUrl!)
                            : null,
                        child: (t.avatarUrl == null || t.avatarUrl!.isEmpty)
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(
                        t.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      subtitle: Row(
                        children: [
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'ID: ${t.discordId}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: Theme.of(context).primaryColor)
                          : const Icon(Icons.radio_button_unchecked),
                      onTap: () => Navigator.of(context).pop(t),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedToken = selected;
      });
    }
  }

  // Helper function to get server icon
  IconData _getServerIcon() {
    final serverType = widget.config['server_type'] ?? 'unknown';
    switch (serverType) {
      case 'server_1':
        return Icons.looks_one_rounded;
      case 'server_2':
        return Icons.looks_two_rounded;
      case 'server_3':
        return Icons.looks_3_rounded;
      default:
        return Icons.dns_rounded;
    }
  }


  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              _getServerIcon(),
              color: Theme.of(context).primaryColor,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Editing ${AutopostConfigService.getServerDisplayName(widget.config['server_type'] ?? 'unknown')} Configuration',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Update your configuration settings as needed',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    bool isRequired = false,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    icon,
                    color: Theme.of(context).primaryColor,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (isRequired)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Required',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildModernNameField(LanguageProvider languageProvider) {
    return TextFormField(
      controller: _nameController,
      decoration: InputDecoration(
        labelText: 'Configuration Name (Optional)',
        hintText: 'My awesome auto-post config',
        helperText: 'Give your configuration a memorable name',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
        prefixIcon: Icon(
          Icons.edit_rounded,
          color: Theme.of(context).primaryColor,
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
      ),
      maxLength: 50,
      validator: (value) {
        if (value != null && value.length > 50) {
          return 'Name too long (max 50 characters)';
        }
        return null;
      },
    );
  }

  Widget _buildModernChannelIdField(LanguageProvider languageProvider) {
    return TextFormField(
      controller: _channelIdController,
      decoration: InputDecoration(
        labelText: 'Discord Channel ID',
        hintText: '1234567890123456789',
        helperText: 'Right-click on Discord channel → Copy Channel ID',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
        prefixIcon: Icon(
          Icons.tag_rounded,
          color: Theme.of(context).primaryColor,
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Channel ID is required';
        }
        if (value.length < 17 || value.length > 19) {
          return 'Channel ID should be 17-19 digits';
        }
        return null;
      },
    );
  }

  Widget _buildModernWebhookUrlField(LanguageProvider languageProvider) {
    return TextFormField(
      controller: _webhookUrlController,
      decoration: InputDecoration(
        labelText: 'Discord Webhook URL (Optional)',
        hintText: 'https://discord.com/api/webhooks/...',
        helperText: 'Leave empty if not using webhooks',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
        prefixIcon: Icon(
          Icons.webhook_rounded,
          color: Theme.of(context).primaryColor,
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
      ),
      keyboardType: TextInputType.url,
      validator: (value) {
        if (value != null && value.isNotEmpty) {
          if (!value.startsWith('https://discord.com/api/webhooks/') &&
              !value.startsWith('https://discordapp.com/api/webhooks/')) {
            return 'Invalid Discord webhook URL format';
          }
        }
        return null;
      },
    );
  }

  Widget _buildModernDelaySection(LanguageProvider languageProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: const Color(0xFF7D3DFE).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: const Color(0xFF7D3DFE).withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: const Color(0xFF7D3DFE),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Final delay = Main Delay + (random between Min Delay and Max Delay) (10s - 86400s)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF7D3DFE),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _delayController,
                decoration: InputDecoration(
                  labelText: 'Main Delay',
                  suffixText: 's',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  final delay = int.tryParse(value ?? '');
                  if (delay == null) return 'Required';
                  if (delay < 10 || delay > 86400) {
                    return '10-86400s';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _minDelayController,
                decoration: InputDecoration(
                  labelText: 'Min Delay',
                  suffixText: 's',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  final delay = int.tryParse(value ?? '');
                  if (delay == null) return 'Required';
                  if (delay < 10 || delay > 86400) {
                    return '10-86400s';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _maxDelayController,
                decoration: InputDecoration(
                  labelText: 'Max Delay',
                  suffixText: 's',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  final delay = int.tryParse(value ?? '');
                  if (delay == null) return 'Required';
                  if (delay < 10 || delay > 86400) {
                    return '10-86400s';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModernMessageField(LanguageProvider languageProvider) {
    return TextFormField(
      controller: _messageController,
      decoration: InputDecoration(
        labelText: 'Auto-post Message',
        hintText: 'Enter the message that will be posted automatically...',
        helperText: 'This message will be sent to Discord automatically',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, top: 12),
          child: Icon(
            Icons.message_rounded,
            color: Theme.of(context).primaryColor,
          ),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        alignLabelWithHint: true,
      ),
      maxLines: 5,
      minLines: 3,
      maxLength: 2000,
      textInputAction: TextInputAction.newline,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Message is required';
        }
        if (value.length > 2000) {
          return 'Message too long (max 2000 characters)';
        }
        return null;
      },
    );
  }

  Widget _buildActionButtons(LanguageProvider languageProvider) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _updateConfig,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: const Color(0xFF7D3DFE),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Theme.of(context).disabledColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: _isLoading ? 0 : 2,
            ),
            child: _isLoading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Updating Configuration...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.save_rounded,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Update Configuration',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.7),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernEndTimeSection(LanguageProvider languageProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _selectEndTime,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: _selectedEndTime != null
                    ? Theme.of(context).primaryColor.withValues(alpha: 0.5)
                    : Theme.of(context).dividerColor.withValues(alpha: 0.5),
                width: _selectedEndTime != null ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).colorScheme.surface,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  color: Theme.of(context).primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedEndTime != null ? 'Auto-stop time selected' : 'Set auto-stop time (optional)',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: _selectedEndTime != null
                              ? Theme.of(context).textTheme.bodyLarge?.color
                              : Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (_selectedEndTime != null)
                        Text(
                          TimezoneUtils.formatJakartaDate(_selectedEndTime!, format: 'EEEE, dd MMMM yyyy • HH:mm WIB'),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      else
                        Text(
                          'Configuration will run indefinitely',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_selectedEndTime != null)
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedEndTime = null;
                      });
                    },
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                    ),
                  )
                else
                  Icon(
                    Icons.keyboard_arrow_right_rounded,
                    color: Theme.of(context).primaryColor,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Edit Configuration'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        iconTheme: Theme.of(context).appBarTheme.iconTheme,
      ),
      body: Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
          if (_isLoadingTokens) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading tokens...'),
                ],
              ),
            );
          }

          if (_tokens.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.token_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Discord Tokens Found',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You need Discord tokens to edit this configuration.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pushNamed('/manage-token'),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Token'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Progress indicator
                  _buildProgressIndicator(),
                  const SizedBox(height: 16),
                  
                  // Token Selection Card
                  _buildSectionCard(
                    title: 'Discord Bot Token',
                    icon: Icons.token,
                    isRequired: true,
                    child: _buildModernTokenSelection(languageProvider),
                  ),
                  const SizedBox(height: 12),
                  
                  // Configuration Name Card
                  _buildSectionCard(
                    title: 'Configuration Name',
                    icon: Icons.edit_rounded,
                    isRequired: false,
                    child: _buildModernNameField(languageProvider),
                  ),
                  const SizedBox(height: 12),
                  
                  // Channel Configuration Card
                  _buildSectionCard(
                    title: 'Channel Configuration',
                    icon: Icons.tag,
                    isRequired: true,
                    child: Column(
                      children: [
                        _buildModernChannelIdField(languageProvider),
                        const SizedBox(height: 12),
                        _buildModernWebhookUrlField(languageProvider),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Timing Configuration Card
                  _buildSectionCard(
                    title: 'Timing Configuration',
                    icon: Icons.schedule,
                    isRequired: true,
                    child: Column(
                      children: [
                        _buildModernDelaySection(languageProvider),
                        const SizedBox(height: 12),
                        _buildModernEndTimeSection(languageProvider),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Message Card
                  _buildSectionCard(
                    title: 'Message Content',
                    icon: Icons.message,
                    isRequired: true,
                    child: _buildModernMessageField(languageProvider),
                  ),
                  const SizedBox(height: 16),
                  
                  // Action Buttons
                  _buildActionButtons(languageProvider),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dispost_autopost/core/providers/language_provider.dart';
import 'package:dispost_autopost/core/models/autopost_config.dart';
import 'package:dispost_autopost/core/services/autopost_config_service.dart';
import 'package:dispost_autopost/core/widgets/custom_notification.dart';
import 'package:dispost_autopost/core/utils/timezone_utils.dart';
import 'package:timezone/timezone.dart' as tz;

class AddConfigScreen extends StatefulWidget {
  final String serverType;

  const AddConfigScreen({
    super.key,
    required this.serverType,
  });

  @override
  State<AddConfigScreen> createState() => _AddConfigScreenState();
}

class _AddConfigScreenState extends State<AddConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _channelIdController = TextEditingController();
  final _webhookUrlController = TextEditingController();
  final _delayController = TextEditingController(text: '300');
  final _minDelayController = TextEditingController(text: '60');
  final _maxDelayController = TextEditingController(text: '600');
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

  Future<void> _loadTokens() async {
    try {
      final tokens = await AutopostConfigService.getUserTokens();
      if (mounted) {
        setState(() {
          _tokens = tokens;
          _isLoadingTokens = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingTokens = false;
        });
        showCustomNotification(
          context,
          'Failed to load tokens: $e',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  Future<void> _selectEndTime() async {
    final now = TimezoneUtils.nowInJakarta();
    
    // Select date
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (selectedDate == null) return;

    if (!mounted) return;

    // Select time
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: now.hour, minute: now.minute),
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

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedToken == null) {
      if (mounted) {
        showCustomNotification(
          context,
          'Please select a Discord token',
          backgroundColor: Colors.red,
        );
      }
      return;
    }

    // Validate delay values
    final delay = int.tryParse(_delayController.text) ?? 0;
    final minDelay = int.tryParse(_minDelayController.text) ?? 0;
    final maxDelay = int.tryParse(_maxDelayController.text) ?? 0;

    // Validate individual delays first
    if (!AutopostConfigService.isValidDelay(minDelay) ||
        !AutopostConfigService.isValidDelay(delay) ||
        !AutopostConfigService.isValidDelay(maxDelay)) {
      if (mounted) {
        showCustomNotification(
          context,
          'Delay values must be between 10 seconds and 24 hours (86400 seconds)',
          backgroundColor: Colors.red,
        );
      }
      return;
    }

    // Validate min_delay ≤ max_delay for random range
    if (!AutopostConfigService.isValidDelayHierarchy(minDelay, delay, maxDelay)) {
      if (mounted) {
        showCustomNotification(
          context,
          'Invalid random delay range: Min Delay ≤ Max Delay\n\nCurrent values:\n• Min Delay: ${minDelay}s\n• Max Delay: ${maxDelay}s\n\n⚠️ Min Delay (${minDelay}s) must be ≤ Max Delay (${maxDelay}s)',
          backgroundColor: Colors.red,
        );
      }
      return;
    }

    // Check if user can create config
    final canCreate = await AutopostConfigService.canCreateConfig(widget.serverType);
    if (!canCreate) {
      if (mounted) {
        showCustomNotification(
          context,
          'You have reached your configuration limit or your plan has expired',
          backgroundColor: Colors.red,
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await AutopostConfigService.createConfig(
        tokenId: _selectedToken!.id,
        serverType: widget.serverType,
        name: _nameController.text.trim().isEmpty 
            ? 'My Config'
            : _nameController.text.trim(),
        channelId: _channelIdController.text,
        webhookUrl: _webhookUrlController.text.isEmpty ? null : _webhookUrlController.text,
        delay: delay,
        endTime: _selectedEndTime,
        minDelay: minDelay,
        maxDelay: maxDelay,
        message: _messageController.text,
      );

      if (mounted) {
        if (success) {
          showCustomNotification(
            context,
            'Configuration created successfully!',
            backgroundColor: Colors.green,
          );
          Navigator.of(context).pop(true); // Return true to indicate success
        } else {
          showCustomNotification(
            context,
            'Failed to create configuration. Please try again.',
            backgroundColor: Colors.red,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showCustomNotification(
          context,
          'Error creating configuration: $e',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Add ${AutopostConfigService.getServerDisplayName(widget.serverType)} Configuration'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        iconTheme: Theme.of(context).appBarTheme.iconTheme,
      ),
      body: Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
          return _buildContent(languageProvider, Theme.of(context).brightness == Brightness.dark);
        },
      ),
    );
  }


  // Helper function to get server icon
  IconData _getServerIcon() {
    switch (widget.serverType) {
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


  Widget _buildContent(LanguageProvider languageProvider, bool isDark) {
    if (_isLoadingTokens) {
      return _buildLoadingState();
    }

    if (_tokens.isEmpty) {
      return _buildEmptyTokensState();
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
  }

  Widget _buildLoadingState() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.5,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading Discord tokens...',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTokensState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.token_outlined,
                size: 60,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Discord Tokens Found',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You need to add Discord bot tokens first\nbefore creating autopost configurations.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pushNamed('/manage-token'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text(
                  'Add Discord Token',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
                  'Setting up ${AutopostConfigService.getServerDisplayName(widget.serverType)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Fill in all required fields to create your configuration',
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

  Widget _buildModernTokenSelection(LanguageProvider languageProvider) {
    // Ganti dropdown default dengan selector bergaya bottom sheet agar lebih rapi.
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
                // Avatar / icon
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
                // Texts
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
        if (_selectedToken != null) ..._buildSelectedTokenFeedback(),
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
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
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

  List<Widget> _buildSelectedTokenFeedback() {
    return [
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.green.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              size: 16,
              color: Colors.green,
            ),
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
    ];
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
            onPressed: _isLoading ? null : _saveConfig,
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
                        'Creating Configuration...',
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
                        Icons.rocket_launch_rounded,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Create Configuration',
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
}

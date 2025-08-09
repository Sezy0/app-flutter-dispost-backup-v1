import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dispost_autopost/core/providers/language_provider.dart';
import 'package:dispost_autopost/core/services/pricing_service.dart';
import 'package:dispost_autopost/core/widgets/custom_notification.dart';
import 'package:dispost_autopost/core/services/payment_account_service.dart';
import 'package:dispost_autopost/core/models/payment_account.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dispost_autopost/core/services/image_upload_service.dart';
import 'dart:io';

class PaymentMethodScreen extends StatefulWidget {
  final PricingPlan plan;

  const PaymentMethodScreen({super.key, required this.plan});

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  String _selectedPaymentMethod = '';
  bool _isProcessing = false;
  final _transactionIdController = TextEditingController();
  final _notesController = TextEditingController();
  
  // Image upload variables
  File? _selectedImage;
  bool _isUploading = false;
  String? _uploadedImageUrl;
  final ImagePicker _imagePicker = ImagePicker();
  double _uploadProgress = 0.0;
  
  // Anti-reload state
  bool _hasUnsavedChanges = false;

  @override
  void dispose() {
    _transactionIdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return PopScope(
          canPop: !_hasUnsavedChanges,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop || !_hasUnsavedChanges) return;
            final shouldPop = await _showExitConfirmation(languageProvider);
            if (shouldPop == true && context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(
              languageProvider.getLocalizedText('payment_method'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.headlineLarge?.color,
              ),
            ),
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
            elevation: 0,
            iconTheme: Theme.of(context).appBarTheme.iconTheme,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!widget.plan.name.toLowerCase().contains('free')) ...[
                  Text(languageProvider.getLocalizedText('select_payment_method'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                ],
                _buildPlanSummary(languageProvider),
                const SizedBox(height: 16),
                if (!widget.plan.name.toLowerCase().contains('free')) ...[
                  _buildPaymentMethods(languageProvider),
                  const SizedBox(height: 16),
                  if (_selectedPaymentMethod.isNotEmpty) _buildPaymentDetails(languageProvider),
                  const SizedBox(height: 16),
                ],
                _buildProceedButton(languageProvider),
              ],
            ),
          ),
        ),
        );
      },
    );
  }

  // Upload progress simulation methods
  Future<void> _simulateUploadProgress() async {
    const totalDuration = 3000; // 3 seconds
    const updateInterval = 50; // Update every 50ms
    const steps = totalDuration ~/ updateInterval;
    
    for (int i = 0; i <= steps && _isUploading && mounted; i++) {
      await Future.delayed(const Duration(milliseconds: updateInterval));
      if (mounted && _isUploading) {
        setState(() {
          // Use ease-out curve for more realistic progress
          double progress = i / steps;
          progress = 1 - (1 - progress) * (1 - progress); // Ease-out curve
          _uploadProgress = (progress * 90).clamp(0.0, 90.0); // Cap at 90% until real upload completes
        });
      }
    }
  }

  Future<void> _waitForUploadProgress() async {
    // Wait until simulated progress reaches near completion
    while (_uploadProgress < 80 && _isUploading && mounted) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  // Anti-reload confirmation dialog
  Future<bool?> _showExitConfirmation(LanguageProvider languageProvider) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            languageProvider.getLocalizedText('unsaved_changes'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            languageProvider.getLocalizedText('unsaved_changes_message'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                languageProvider.getLocalizedText('stay'),
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(languageProvider.getLocalizedText('leave')),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPlanSummary(LanguageProvider languageProvider) {
    bool isFree = widget.plan.name.toLowerCase().contains('free');
    double discountPercent = 0;
    if (widget.plan.discountPrice != null && widget.plan.discountPrice! > 0) {
      discountPercent = ((widget.plan.pricing - widget.plan.finalPrice) / widget.plan.pricing) * 100;
    }
    
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isFree 
            ? Colors.green.withValues(alpha: 0.1)
            : primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFree ? Colors.green : primaryColor, 
          width: 2
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                languageProvider.getLocalizedText('plan_summary'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (discountPercent > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${discountPercent.toStringAsFixed(0)}% OFF',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.plan.name,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (!isFree) ...[
            if (widget.plan.discountPrice != null && widget.plan.discountPrice! > 0) ...[
              Text(
                'Rp ${_formatPrice(widget.plan.pricing)}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              'Rp ${_formatPrice(widget.plan.finalPrice)}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ] else ...[
            Text(
              'FREE',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.settings, size: 16, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
                  const SizedBox(width: 6),
                  Text('${widget.plan.maxConfig} Configs', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7))),
                  const SizedBox(width: 16),
                  Icon(Icons.access_time, size: 16, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
                  const SizedBox(width: 6),
                  Text('${widget.plan.expiredPlan} Days', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7))),
                ],
              ),
        ],
      ),
    );
  }


  Widget _buildPaymentMethods(LanguageProvider languageProvider) {
    return FutureBuilder<List<PaymentAccount>>(
      future: PaymentAccountService.getActivePaymentAccounts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Text(languageProvider.getLocalizedText('error_loading_payment_methods'));
        } else {
          final paymentAccounts = snapshot.data ?? [];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(languageProvider.getLocalizedText('payment_methods'), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._buildGroupedPaymentOptions(paymentAccounts),
            ],
          );
        }
      },
    );
  }

  List<Widget> _buildGroupedPaymentOptions(List<PaymentAccount> paymentAccounts) {
    List<Widget> options = [];
    
    // Group accounts by type
    Map<String, List<PaymentAccount>> groupedAccounts = {};
    for (var account in paymentAccounts) {
      if (!groupedAccounts.containsKey(account.type)) {
        groupedAccounts[account.type] = [];
      }
      groupedAccounts[account.type]!.add(account);
    }
    
    // Build options for each type
    for (var entry in groupedAccounts.entries) {
      String type = entry.key;
      List<PaymentAccount> accounts = entry.value;
      
      if (accounts.isNotEmpty) {
        PaymentAccount representativeAccount = accounts.first;
        
        // For ewallet, show combined subtitle
        String subtitle;
        if (type == 'ewallet') {
          List<String> providerNames = accounts
              .map((acc) => PaymentAccountService.getProviderDisplayName(acc.provider))
              .toList();
          final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
          subtitle = '${languageProvider.getLocalizedText('pay_with')} ${providerNames.join(', ')}';
        } else {
          subtitle = _buildSubtitleForAccount(representativeAccount);
        }
        
        // Parse color dari hex string ke Color
        final color = Color(int.parse(
          PaymentAccountService.getProviderColor(representativeAccount.provider).replaceFirst('#', '0xFF'),
        ));
        
        options.add(_buildPaymentOption(
          type,
          _getTypeDisplayName(type),
          subtitle,
          _getIconForAccount(representativeAccount),
          color,
        ));
      }
    }
    
    return options;
  }
  
  String _getTypeDisplayName(String type) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    switch (type) {
      case 'bank':
        return languageProvider.getLocalizedText('bank_transfer');
      case 'ewallet':
        return languageProvider.getLocalizedText('ewallet');
      case 'qris':
        return languageProvider.getLocalizedText('qris');
      default:
        return type.toUpperCase();
    }
  }


  String _buildSubtitleForAccount(PaymentAccount account) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    switch (account.type) {
      case 'bank':
        return '${languageProvider.getLocalizedText('transfer_to')} ${account.accountName}';
      case 'ewallet':
        return '${languageProvider.getLocalizedText('pay_using')} ${PaymentAccountService.formatAccountNumber(account)}';
      case 'qris':
        return languageProvider.getLocalizedText('scan_qr_code_to_pay');
      default:
        return '${languageProvider.getLocalizedText('pay_using')} ${account.provider}';
    }
  }

  IconData _getIconForAccount(PaymentAccount account) {
    switch (account.type) {
      case 'bank':
        return Icons.account_balance;
      case 'ewallet':
        return Icons.account_balance_wallet;
      case 'qris':
        return Icons.qr_code;
      default:
        return Icons.payment;
    }
  }

  Widget _buildPaymentOption(
    String method,
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    bool isSelected = _selectedPaymentMethod == method;
    bool isFree = widget.plan.name.toLowerCase().contains('free');
    
    // Free plan only allows bank transfer method
    bool isEnabled = isFree ? method == 'bank' : true;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? color : (Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade600 : Colors.grey.shade300),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: GestureDetector(
        onTap: isEnabled
            ? () {
                if (mounted) {
                  setState(() {
                    _selectedPaymentMethod = isSelected ? '' : method;
                    _hasUnsavedChanges = true;
                  });
                }
              }
            : null,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: (isEnabled ? color : Colors.grey).withValues(alpha: 0.1),
                child: Icon(
                  icon,
                  color: isEnabled ? color : Colors.grey,
                  size: 18,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: isEnabled ? null : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isEnabled ? Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7) : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentDetails(LanguageProvider languageProvider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade700 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            languageProvider.getLocalizedText('payment_details'),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildPaymentInstructions(),
          const SizedBox(height: 12),
          if (_selectedPaymentMethod != 'qris') ...[
            TextField(
              controller: _transactionIdController,
              decoration: InputDecoration(
                labelText: languageProvider.getLocalizedText('transaction_id'),
                hintText: languageProvider.getLocalizedText('enter_id_after_payment'),
                labelStyle: Theme.of(context).textTheme.bodySmall,
                hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: _notesController,
            maxLines: 1,
            decoration: InputDecoration(
              labelText: languageProvider.getLocalizedText('notes'),
              hintText: languageProvider.getLocalizedText('additional_notes'),
              labelStyle: Theme.of(context).textTheme.bodySmall,
              hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          
          // Payment Proof Upload Section
          _buildPaymentProofSection(languageProvider),
        ],
      ),
    );
  }

  Widget _buildPaymentInstructions() {
    switch (_selectedPaymentMethod) {
      case 'bank':
        return _buildBankTransferInstructions();
      case 'ewallet':
        return _buildEWalletInstructions();
      case 'qris':
        return _buildQRISInstructions();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBankTransferInstructions() {
    return FutureBuilder<List<PaymentAccount>>(
      future: PaymentAccountService.getBankAccounts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Text('Error loading bank details.');
        } else {
          final bankAccounts = snapshot.data ?? [];
          if (bankAccounts.isEmpty) {
            return Text('No bank accounts available.');
          }
          
          final bankAccount = bankAccounts.first; // Use first bank account
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bank Transfer Details',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildBankDetail('Bank Name', PaymentAccountService.getProviderDisplayName(bankAccount.provider)),
                    _buildBankDetail('Account Number', PaymentAccountService.formatAccountNumber(bankAccount)),
                    _buildBankDetail('Account Name', bankAccount.accountName),
                    _buildBankDetail('Amount', 'Rp ${_formatPrice(widget.plan.finalPrice)}'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Instructions:',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '1. Transfer the exact amount to the bank account above\n'
                '2. Keep your transfer receipt\n'
                '3. Enter transaction ID if available\n'
                '4. Click "Complete Purchase" below\n'
                '5. Your plan will be activated within 1-24 hours',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                ),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildEWalletInstructions() {
    return FutureBuilder<List<PaymentAccount>>(
      future: PaymentAccountService.getEWalletAccounts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Text('Error loading e-wallet details.');
        } else {
          final eWalletAccounts = snapshot.data ?? [];
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.green.withValues(alpha: 0.2) 
                      : Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'E-Wallet Payment',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (eWalletAccounts.isNotEmpty) ...[
                      Text(
                        'Available E-Wallet Accounts:',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (var account in eWalletAccounts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GestureDetector(
                            onTap: () => _copyToClipboard(PaymentAccountService.formatAccountNumber(account)),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark 
                                    ? Colors.white.withValues(alpha: 0.05) 
                                    : Colors.white.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Theme.of(context).brightness == Brightness.dark 
                                      ? Colors.grey.withValues(alpha: 0.3) 
                                      : Colors.grey.withValues(alpha: 0.2)
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    PaymentAccountService.getProviderIcon(account.provider),
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${PaymentAccountService.getProviderDisplayName(account.provider)}: ${PaymentAccountService.formatAccountNumber(account)}',
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          'a.n. ${account.accountName}',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.copy,
                                    size: 16,
                                    color: Colors.green.shade600,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      'For manual transfer, contact our support team:',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _launchDiscord(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Color(0xFF5865F2), // Discord blue color
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat, color: Colors.white, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Discord Support',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildQRISInstructions() {
    return FutureBuilder<PaymentAccount?>(
      future: PaymentAccountService.getQRISAccount(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: CircularProgressIndicator(color: Colors.purple),
            ),
          );
        } else if (snapshot.hasError) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.red.withValues(alpha: 0.2) 
                  : Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.red.withValues(alpha: 0.5) 
                    : Colors.red.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 32),
                const SizedBox(height: 8),
                Text(
                  'Error loading QRIS details',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        } else {
          final qrisAccount = snapshot.data;
          
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.purple.withValues(alpha: 0.15) 
                  : Colors.purple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.purple.withValues(alpha: 0.4) 
                    : Colors.purple.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.qr_code_scanner,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'QRIS Payment',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // QR Code Container
                Container(
                  width: 220,
                  height: 220,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.grey.withValues(alpha: 0.4) 
                          : Colors.grey.withValues(alpha: 0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: qrisAccount?.qrCodePath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            qrisAccount!.qrCodePath!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildQRPlaceholder('QR Code Not Available');
                            },
                          ),
                        )
                      : _buildQRPlaceholder('QR Code Here'),
                ),
                const SizedBox(height: 20),
                
                // Instructions
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? Colors.purple.withValues(alpha: 0.1) 
                        : Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.purple.withValues(alpha: 0.3) 
                          : Colors.purple.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.purple,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'How to Pay',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildInstructionStep('1', 'Open your mobile banking or e-wallet app'),
                      _buildInstructionStep('2', 'Select QRIS scan feature'),
                      _buildInstructionStep('3', 'Scan the QR code above'),
                      _buildInstructionStep('4', 'Verify payment amount and confirm'),
                      _buildInstructionStep('5', 'Upload payment proof below'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Supported Apps
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? Colors.grey[800]?.withValues(alpha: 0.5) 
                        : Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Supported Apps',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? Colors.grey[300] 
                              : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'GoPay • OVO • DANA • ShopeePay • LinkAja • All Banks',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
          );
        }
      },
    );
  }
  
  Widget _buildQRPlaceholder(String text) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey[300]!,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.qr_code,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildInstructionStep(String number, String instruction) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.purple,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              instruction,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.grey[300] 
                    : Colors.grey[700],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _copyToClipboard(value),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Theme.of(context).cardColor 
                      : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? Colors.grey.withValues(alpha: 0.5) 
                        : Colors.grey.withValues(alpha: 0.3)
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.copy,
                      size: 16,
                      color: Theme.of(context).primaryColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProceedButton(LanguageProvider languageProvider) {
    bool isFree = widget.plan.name.toLowerCase().contains('free');
    bool hasPaymentMethod = _selectedPaymentMethod.isNotEmpty;
    bool hasPaymentProof = _uploadedImageUrl != null;
    bool canProceed = isFree ? true : (hasPaymentMethod && hasPaymentProof); // Free plan doesn't need payment method or proof
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (canProceed && !_isProcessing) ? () => _processPurchase(languageProvider) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isFree ? Colors.green : Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 8,
        ),
        child: _isProcessing
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isFree ? languageProvider.getLocalizedText('claim_free_plan') : languageProvider.getLocalizedText('complete_purchase'),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (!isFree && (!hasPaymentMethod || !hasPaymentProof)) ...[
                    const SizedBox(height: 4),
                    Text(
                      !hasPaymentMethod ? languageProvider.getLocalizedText('select_payment_method_first') :
                      !hasPaymentProof ? languageProvider.getLocalizedText('upload_payment_proof_first') : '',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Future<void> _processPurchase(LanguageProvider languageProvider) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await PricingService.purchasePlan(
        planId: widget.plan.planId,
        paymentMethod: _selectedPaymentMethod,
        transactionId: _transactionIdController.text.trim().isEmpty 
            ? null 
            : _transactionIdController.text.trim(),
        notes: _notesController.text.trim().isEmpty 
            ? null 
            : _notesController.text.trim(),
        proofImageUrl: _uploadedImageUrl,
      );

      if (mounted) {
        if (result['success'] == true) {
          if(mounted) {
            setState(() {
              _hasUnsavedChanges = false; // Clear unsaved changes flag
            });
            showCustomNotification(
              context,
              'Purchase successful! Your plan will be activated soon.',
              backgroundColor: Colors.green,
            );
            // Go back to plan screen
            Navigator.of(context).pop(true); // Return true to indicate success
          }
        } else if(mounted) {
          showCustomNotification(
            context,
            (result['message'] as String?) ?? 'Purchase failed. Please try again.',
            backgroundColor: Colors.red,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showCustomNotification(
          context,
          'Purchase failed: $e',
          backgroundColor: Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    showCustomNotification(
      context,
      'Copied to clipboard: $text',
      backgroundColor: Colors.green,
    );
  }

  void _launchDiscord() async {
    const discordInvite = 'https://discord.gg/X3JCuRBgvf';
    final uri = Uri.parse(discordInvite);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        showCustomNotification(
          context,
          'Could not launch Discord. Please visit: $discordInvite',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  String _formatPrice(double price) {
    return price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  // Payment Proof Upload Methods
  Widget _buildPaymentProofSection(LanguageProvider languageProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          languageProvider.getLocalizedText('payment_proof'),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          languageProvider.getLocalizedText('upload_proof_required'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.red,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        
        if (_selectedImage != null || _uploadedImageUrl != null) ...
          _buildUploadedImagePreview(languageProvider)
        else ...
          _buildUploadButton(languageProvider),
      ],
    );
  }

  List<Widget> _buildUploadedImagePreview(LanguageProvider languageProvider) {
    return [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green, width: 1),
        ),
        child: Column(
          children: [
            if (_selectedImage != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  _selectedImage!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ] else if (_uploadedImageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  _uploadedImageUrl!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 150,
                      width: double.infinity,
                      color: Colors.grey.withValues(alpha: 0.1),
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 150,
                      width: double.infinity,
                      color: Colors.grey.withValues(alpha: 0.3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error, color: Colors.red, size: 32),
                          const SizedBox(height: 8),
                          Text(
                            'Failed to load image',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.red,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          TextButton(
                            onPressed: () {
                              // Force rebuild to retry loading
                              setState(() {});
                            },
                            child: Text(
                              'Retry',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    languageProvider.getLocalizedText('image_uploaded'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _uploadedImageUrl != null
                        ? () => _viewImage(_uploadedImageUrl!)
                        : null,
                    icon: const Icon(Icons.visibility, size: 16),
                    label: Text(
                      languageProvider.getLocalizedText('view_image'),
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: BorderSide(color: Colors.blue),
                      foregroundColor: Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _removeImage,
                    icon: const Icon(Icons.delete, size: 16),
                    label: Text(
                      languageProvider.getLocalizedText('remove_image'),
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: BorderSide(color: Colors.red),
                      foregroundColor: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildUploadButton(LanguageProvider languageProvider) {
    return [
      InkWell(
        onTap: _isUploading ? null : () => _showImageSourceDialog(languageProvider),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.grey.withValues(alpha: 0.3),
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            children: [
              if (_isUploading) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 80,
                        width: 80,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              height: 80,
                              width: 80,
                              child: AnimatedBuilder(
                                animation: Tween<double>(
                                  begin: 0,
                                  end: _uploadProgress,
                                ).animate(CurvedAnimation(
                                  parent: ModalRoute.of(context)!.animation!,
                                  curve: Curves.easeInOut,
                                )),
                                builder: (context, child) {
                                  return CircularProgressIndicator(
                                    value: _uploadProgress / 100,
                                    strokeWidth: 6,
                                    backgroundColor: Colors.grey.withValues(alpha: 0.3),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _uploadProgress < 100 ? Colors.blue : Colors.green,
                                    ),
                                  );
                                },
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _uploadProgress < 100 ? Icons.cloud_upload : Icons.check,
                                color: _uploadProgress < 100 ? Colors.blue : Colors.green,
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _uploadProgress < 100
                            ? '${languageProvider.getLocalizedText('uploading')} ${_uploadProgress.toInt()}%'
                            : languageProvider.getLocalizedText('upload_success'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _uploadProgress < 100 ? Colors.blue : Colors.green,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          width: (MediaQuery.of(context).size.width - 64) * (_uploadProgress / 100),
                          height: 4,
                          decoration: BoxDecoration(
                            color: _uploadProgress < 100 ? Colors.blue : Colors.green,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Icon(
                  Icons.cloud_upload,
                  size: 32,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 8),
                Text(
                  languageProvider.getLocalizedText('upload_payment_proof'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  languageProvider.getLocalizedText('select_image'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ];
  }

  void _showImageSourceDialog(LanguageProvider languageProvider) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      languageProvider.getLocalizedText('upload_from'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.camera_alt),
                      title: Text(languageProvider.getLocalizedText('camera')),
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.camera, languageProvider);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.photo_library),
                      title: Text(languageProvider.getLocalizedText('gallery')),
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.gallery, languageProvider);
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  Future<void> _pickImage(ImageSource source, LanguageProvider languageProvider) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final File imageFile = File(pickedFile.path);
        
        // Validate image file
        if (!ImageUploadService.isValidImageFile(imageFile)) {
          if (mounted) {
            showCustomNotification(
              context,
              languageProvider.getLocalizedText('invalid_image_file'),
              backgroundColor: Colors.red,
            );
          }
          return;
        }

        // Check file size
        if (!ImageUploadService.isFileSizeValid(imageFile)) {
          if (mounted) {
            showCustomNotification(
              context,
              languageProvider.getLocalizedText('file_too_large'),
              backgroundColor: Colors.red,
            );
          }
          return;
        }

        setState(() {
          _selectedImage = imageFile;
          _isUploading = true;
          _uploadProgress = 0.0;
          _hasUnsavedChanges = true;
        });

        // Simulate smooth upload progress
        _simulateUploadProgress();

        // Upload image to imgbb
        final result = await ImageUploadService.uploadImage(imageFile);
        
        // Wait for upload progress to complete before processing result
        await _waitForUploadProgress();
        
        if (mounted) {
          if (result['success'] == true) {
            setState(() {
              _uploadedImageUrl = result['url'];
              _uploadProgress = 100.0;
            });
            
            // Store proof URL for later use in purchase notification
            
            // Show success animation for a moment
            await Future.delayed(const Duration(milliseconds: 800));
            
            if (mounted) {
              setState(() {
                _isUploading = false;
              });
              showCustomNotification(
                context,
                languageProvider.getLocalizedText('upload_success'),
                backgroundColor: Colors.green,
              );
            }
          } else {
            setState(() {
              _selectedImage = null;
              _isUploading = false;
              _uploadProgress = 0.0;
            });
            if (mounted) {
              showCustomNotification(
                context,
                '${languageProvider.getLocalizedText('upload_failed')}: ${result['error']}',
                backgroundColor: Colors.red,
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _selectedImage = null;
          _uploadProgress = 0.0;
        });
        
        showCustomNotification(
          context,
          '${languageProvider.getLocalizedText('upload_failed')}: $e',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _uploadedImageUrl = null;
      _uploadProgress = 0.0;
      _hasUnsavedChanges = true;
    });
  }

  void _viewImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Consumer<LanguageProvider>(
                builder: (context, languageProvider, child) => Text(
                  languageProvider.getLocalizedText('payment_proof'),
                ),
              ),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Flexible(
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 200,
                      width: double.infinity,
                      color: Colors.grey.withValues(alpha: 0.1),
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      width: double.infinity,
                      color: Colors.grey.withValues(alpha: 0.3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error, color: Colors.red, size: 64),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load image',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.red,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Network timeout or connection error',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

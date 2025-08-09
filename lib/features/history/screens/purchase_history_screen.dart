import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dispost_autopost/core/providers/language_provider.dart';
import 'package:dispost_autopost/core/models/purchase_history.dart';
import 'package:dispost_autopost/core/services/purchase_history_service.dart';
import 'package:dispost_autopost/core/widgets/custom_notification.dart';
import 'package:dispost_autopost/core/utils/timezone_utils.dart';
import 'package:timezone/timezone.dart' as tz;

class PurchaseHistoryScreen extends StatefulWidget {
  const PurchaseHistoryScreen({super.key});

  @override
  State<PurchaseHistoryScreen> createState() => _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends State<PurchaseHistoryScreen> {
  List<PurchaseHistory> _purchases = [];
  Map<String, dynamic> _statistics = {};
  bool _isLoading = true;
  String _selectedFilter = 'all'; // all, completed, pending, failed

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final purchases = await PurchaseHistoryService.getUserPurchaseHistory();
      final stats = await PurchaseHistoryService.getPurchaseStatistics();
      
      if (mounted) {
        setState(() {
          _purchases = purchases;
          _statistics = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        showCustomNotification(
          context,
          'Failed to load purchase history: $e',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  List<PurchaseHistory> get _filteredPurchases {
    switch (_selectedFilter) {
      case 'completed':
        return _purchases.where((p) => p.isCompleted).toList();
      case 'pending':
        return _purchases.where((p) => p.isPending).toList();
      case 'failed':
        return _purchases.where((p) => p.isFailed).toList();
      default:
        return _purchases;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(languageProvider.getLocalizedText('purchase_history')),
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
            elevation: 0,
            iconTheme: Theme.of(context).appBarTheme.iconTheme,
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
                        // Statistics Cards
                        _buildStatisticsSection(),
                        const SizedBox(height: 24),
                        
                        // Filter Section
                        _buildFilterSection(),
                        const SizedBox(height: 16),
                        
                        // Purchase History List
                        _buildHistoryList(),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildStatisticsSection() {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              languageProvider.getLocalizedText('statistics'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
        const SizedBox(height: 12),
        
        // Statistics Grid
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 3.5, // Much higher ratio for very compact cards
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          children: [
            _buildStatCard(
              languageProvider.getLocalizedText('total_purchases'),
              _statistics['total_purchases']?.toString() ?? '0',
              Icons.shopping_cart,
              Colors.blue,
            ),
            _buildStatCard(
              languageProvider.getLocalizedText('total_spent'),
              'Rp ${_formatPrice(_statistics["total_spent"] ?? 0)}',
              Icons.payments,
              Colors.green,
            ),
            _buildStatCard(
              languageProvider.getLocalizedText('completed'),
              _statistics['completed_purchases']?.toString() ?? '0',
              Icons.check_circle,
              Colors.teal,
            ),
            _buildStatCard(
              languageProvider.getLocalizedText('pending'),
              _statistics['pending_purchases']?.toString() ?? '0',
              Icons.pending,
              Colors.orange,
            ),
          ],
        ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), // Much smaller padding
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(6), // Smaller border radius
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14), // Much smaller icon
          const SizedBox(width: 3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 8, // Much smaller font
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12, // Much smaller value font
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Row(
          children: [
            Text(
              '${languageProvider.getLocalizedText('filter')}:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedFilter,
              isDense: true,
              items: [
                DropdownMenuItem(
                  value: 'all',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.list, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(languageProvider.getLocalizedText('all'), style: TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'completed',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, size: 16, color: Colors.green),
                      const SizedBox(width: 6),
                      Text(languageProvider.getLocalizedText('completed'), style: TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'pending',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.pending, size: 16, color: Colors.orange),
                      const SizedBox(width: 6),
                      Text(languageProvider.getLocalizedText('pending'), style: TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'failed',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error, size: 16, color: Colors.red),
                      const SizedBox(width: 6),
                      Text(languageProvider.getLocalizedText('failed'), style: TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              ],
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedFilter = newValue;
                  });
                }
              },
            ),
          ),
        ),
          ],
        );
      },
    );
  }


  Widget _buildHistoryList() {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final filteredPurchases = _filteredPurchases;
        
        if (filteredPurchases.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 64,
                  color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  languageProvider.getLocalizedText('no_purchase_history'),
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  languageProvider.getLocalizedText('purchase_history_will_appear'),
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Purchase History (${filteredPurchases.length})',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 12),
            
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredPurchases.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final purchase = filteredPurchases[index];
                return _buildPurchaseCard(purchase);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildPurchaseCard(PurchaseHistory purchase) {
    Color statusColor;
    IconData statusIcon;
    
    switch (purchase.status) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case 'failed':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      case 'refunded':
        statusColor = Colors.purple;
        statusIcon = Icons.undo;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Text(
                  purchase.planName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      purchase.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Details
          _buildDetailRow('Amount', 'Rp ${_formatPrice(purchase.finalPrice)}'),
          if (purchase.originalPrice != purchase.finalPrice)
            _buildDetailRowWithStrikethrough('Original Price', 'Rp ${_formatPrice(purchase.originalPrice)}'),
          if (purchase.discountPrice != null && purchase.discountPrice! > 0)
            _buildDetailRow('Discount', 'Rp ${_formatPrice(purchase.discountPrice!)}'),
          _buildDetailRow('Purchase Date', _formatDate(purchase.purchasedAt)),
          _buildDetailRow('Max Config', purchase.maxConfigPurchased.toString()),
          _buildDetailRow('Duration', '${purchase.daysPurchased} days'),
          if (purchase.paymentMethod != null)
            _buildDetailRow('Payment Method', purchase.paymentMethod!),
          if (purchase.transactionId != null)
            _buildDetailRow('Transaction ID', purchase.transactionId!),
          if (purchase.notes != null && purchase.notes!.isNotEmpty)
            _buildDetailRow('Notes', purchase.notes!),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRowWithStrikethrough(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                decoration: TextDecoration.lineThrough,
                decorationColor: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                decorationThickness: 2.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(double price) {
    return price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  String _formatDate(DateTime date) {
    final jakartaDate = tz.TZDateTime.from(date, TimezoneUtils.jakartaLocation);
    
    if (TimezoneUtils.isToday(jakartaDate)) {
      return 'Today, ${TimezoneUtils.formatJakartaDate(jakartaDate, format: 'HH:mm')}';
    } else if (TimezoneUtils.isTomorrow(jakartaDate)) {
      return 'Tomorrow, ${TimezoneUtils.formatJakartaDate(jakartaDate, format: 'HH:mm')}';
    } else {
      final daysDiff = TimezoneUtils.daysDifferenceFromNow(jakartaDate);
      if (daysDiff < 0) {
        return '${(-daysDiff)} days ago';
      } else {
        return TimezoneUtils.formatJakartaDate(jakartaDate, format: 'dd/MM/yyyy HH:mm');
      }
    }
  }
}

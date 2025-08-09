import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dispost_autopost/core/providers/language_provider.dart';
import 'package:dispost_autopost/core/services/pricing_service.dart';
import 'package:dispost_autopost/core/widgets/custom_notification.dart';
import 'package:dispost_autopost/features/payment/screens/payment_method_screen.dart';
import 'package:dispost_autopost/core/routing/app_routes.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  List<PricingPlan> _plans = [];
  bool _isLoading = true;
  int _selectedPlanIndex = -1;
  // ignore: prefer_final_fields
  bool _isPurchasing = false;
  bool _canClaimFreePlan = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final plans = await PricingService.getActivePlans();
      final canClaimFree = await PricingService.canClaimFreePlan();
      
      if (mounted) {
        setState(() {
          _plans = plans;
          _canClaimFreePlan = canClaimFree;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
        showCustomNotification(
          context,
          '${languageProvider.getLocalizedText('failed_to_load_plans')}: $e',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  Future<void> _purchasePlan(PricingPlan plan) async {
    if (_isPurchasing) return;
    
    // Navigate to payment method screen
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => PaymentMethodScreen(plan: plan),
      ),
    );
    
    // If payment was successful, refresh the plans
    if (result == true) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
          if (_isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section
                  _buildHeader(languageProvider),
                  const SizedBox(height: 30),
                  
                  // Plans Grid
                  _buildPlansGrid(),
                  const SizedBox(height: 20),
                  
                  // Features Comparison
                  _buildFeaturesComparison(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: _buildHistoryFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildHeader(LanguageProvider languageProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          languageProvider.getLocalizedText('choose_your_plan'),
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.headlineLarge?.color,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          languageProvider.getLocalizedText('unlock_powerful_automation'),
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }


  Widget _buildPlansGrid() {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Column(
          children: _plans.asMap().entries.map((entry) {
            int index = entry.key;
            PricingPlan plan = entry.value;
            bool isRecommended = plan.name == 'Basic Plan';
            bool isFree = plan.name == 'Free Plan';
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildPlanCard(plan, index, isRecommended, isFree, languageProvider),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildPlanCard(PricingPlan plan, int index, bool isRecommended, bool isFree, LanguageProvider languageProvider) {
    bool isSelected = _selectedPlanIndex == index;
    final primaryColor = Theme.of(context).primaryColor;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPlanIndex = isSelected ? -1 : index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : isRecommended
                    ? primaryColor.withValues(alpha: 0.5)
                    : Theme.of(context).dividerColor.withValues(alpha: 0.3),
            width: isSelected ? 2 : (isRecommended ? 1.5 : 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isSelected ? 0.08 : 0.05),
              blurRadius: isSelected ? 12 : 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Recommended Badge
            if (isRecommended)
              Positioned(
                top: 0,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Consumer<LanguageProvider>(
                    builder: (context, langProvider, child) => Text(
                      langProvider.getLocalizedText('recommended'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Plan Name
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        plan.name,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.headlineLarge?.color,
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          color: primaryColor,
                          size: 28,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Price
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isFree ? languageProvider.getLocalizedText('free') : 'Rp ${_formatPrice(plan.finalPrice)}',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: isFree
                              ? Colors.green
                              : Theme.of(context).textTheme.headlineLarge?.color,
                        ),
                      ),
                      if (plan.discountPrice != null && plan.discountPrice! > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Rp ${_formatPrice(plan.pricing)}',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Features
                  _buildFeatureItem(
                    Icons.settings,
                    '${plan.maxConfig} ${languageProvider.getLocalizedText('max_configurations')}',
                  ),
                  _buildFeatureItem(
                    Icons.access_time,
                    '${plan.expiredPlan} ${languageProvider.getLocalizedText('days_duration')}',
                  ),
                  _buildFeatureItem(
                    Icons.support_agent,
                    languageProvider.getLocalizedText('support_247'),
                  ),
                  if (!isFree) _buildFeatureItem(
                    Icons.cloud_sync,
                    languageProvider.getLocalizedText('auto_sync'),
                  ),
                  const SizedBox(height: 20),
                  
                  // Purchase Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isPurchasing 
                          ? null 
                          : (isFree && !_canClaimFreePlan)
                              ? () => _showFreePlanClaimedDialog(languageProvider)
                              : () => _purchasePlan(plan),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (isFree && !_canClaimFreePlan)
                            ? Colors.grey
                            : isFree
                                ? Colors.green
                                : primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: isSelected ? 6 : 3,
                      ),
                      child: _isPurchasing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              (isFree && !_canClaimFreePlan)
                                  ? languageProvider.getLocalizedText('already_claimed')
                                  : isFree 
                                      ? languageProvider.getLocalizedText('get_started') 
                                      : languageProvider.getLocalizedText('choose_plan'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
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
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 8),
          Expanded( // Added Expanded to prevent overflow
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              maxLines: 2, // Allow text to wrap to 2 lines if needed
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesComparison() {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Container(
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
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                languageProvider.getLocalizedText('why_choose_our_plans'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.headlineMedium?.color,
                ),
              ),
              const SizedBox(height: 16),
              _buildComparisonItem(
                Icons.rocket_launch,
                languageProvider.getLocalizedText('automation'),
                languageProvider.getLocalizedText('automation_desc'),
              ),
              _buildComparisonItem(
                Icons.analytics,
                languageProvider.getLocalizedText('analytics'),
                languageProvider.getLocalizedText('analytics_desc'),
              ),
              _buildComparisonItem(
                Icons.schedule,
                languageProvider.getLocalizedText('scheduling'),
                languageProvider.getLocalizedText('scheduling_desc'),
              ),
              _buildComparisonItem(
                Icons.security,
                languageProvider.getLocalizedText('security'),
                languageProvider.getLocalizedText('security_desc'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildComparisonItem(IconData icon, String title, String description) {
    final primaryColor = Theme.of(context).primaryColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryFAB() {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return FloatingActionButton(
          onPressed: () {
            Navigator.pushNamed(context, AppRoutes.purchaseHistoryRoute);
          },
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          tooltip: languageProvider.getLocalizedText('tooltip_purchase_history'),
          child: const Icon(
            Icons.history,
            size: 24,
          ),
        );
      },
    );
  }

  void _showFreePlanClaimedDialog(LanguageProvider languageProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(languageProvider.getLocalizedText('already_claimed')),
        content: Text(languageProvider.getLocalizedText('free_plan_claimed_once')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(languageProvider.getLocalizedText('close')),
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
}

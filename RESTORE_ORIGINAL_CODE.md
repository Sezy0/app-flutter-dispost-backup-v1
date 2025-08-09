# RESTORE ORIGINAL CODE AFTER TESTING

## Files yang dimodifikasi untuk testing:
1. `lib/core/services/pricing_service.dart`

## Perubahan yang dibuat:
1. **canClaimFreePlan()** - Diubah untuk selalu return `true` (testing only)
2. **purchasePlan()** - Diubah menggunakan `purchase_plan_with_auto_ban` function

## Cara restore ke original:

### 1. Restore canClaimFreePlan function:
```dart
// Replace this function in pricing_service.dart:
static Future<bool> canClaimFreePlan() async {
  try {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return false;
    }

    final response = await _supabase.rpc('check_user_free_plan_eligibility', params: {
      'p_user_id': user.id,
    });

    return response as bool? ?? false;
  } catch (e) {
    debugPrint('Error checking free plan eligibility: $e');
    return false;
  }
}
```

### 2. Restore purchasePlan function call:
```dart
// Replace this line in purchasePlan function:
final response = await _supabase.rpc('purchase_plan', params: {
  'p_user_id': user.id,
  'p_plan_id': planId,
  'p_payment_method': paymentMethod,
  'p_transaction_id': transactionId,
  'p_notes': notes,
});
```

### 3. Remove all testing comments:
- Remove "TEMPORARILY ENABLED FOR TESTING" comments
- Remove "TODO: Revert this after testing" comments
- Remove commented out original code

## Quick Restore Commands:
Run these edits to quickly restore:

1. Change `return true;` back to the original RPC call
2. Change `purchase_plan_with_auto_ban` back to `purchase_plan`
3. Clean up all testing comments

## Testing Status:
- [x] Auto-ban system implemented in database
- [x] Free tier button temporarily enabled
- [ ] Testing completed
- [ ] Original code restored
- [ ] Auto-ban system activated in production

## Notes:
Setelah testing selesai dan sistem auto-ban sudah terbukti bekerja:
1. Restore kode original
2. Deploy auto-ban system ke production
3. Sistem akan otomatis ban user yang claim free lebih dari 1x

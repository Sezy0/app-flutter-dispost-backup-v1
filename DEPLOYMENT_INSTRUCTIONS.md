# DEPLOYMENT INSTRUCTIONS - Auto-Ban System

## ❌ Error yang Terjadi:
```
Purchase failed: operator does not exist: uuid = text
```

## 🔧 Solusi:
Error ini terjadi karena type mismatch antara UUID dan TEXT di join operations. File yang sudah diperbaiki:

**File Fix Terbaru:** `auto_ban_multiple_free_claims_FINAL.sql`

## 📋 Langkah Deployment:

### 1. Deploy SQL Fix ke Supabase:
```sql
-- Copy isi file: auto_ban_multiple_free_claims_FINAL.sql
-- Paste ke: Supabase Dashboard > SQL Editor
-- Klik: Run
```

### 2. Verificasi Deployment:
```sql
-- Test function availability:
SELECT EXISTS (
  SELECT 1 FROM pg_proc 
  WHERE proname = 'purchase_plan_with_auto_ban'
);

-- Should return: true
```

### 3. Test Auto-Ban System:

#### A. Claim Free Plan Pertama Kali:
- Bukan aplikasi dan coba claim free plan
- Seharusnya berhasil

#### B. Claim Free Plan Kedua Kali:
- Logout dan login kembali 
- Coba claim free plan lagi
- Seharusnya dapat pesan ban dan account di-ban

#### C. Verify Ban Status:
```sql
-- Check banned users:
SELECT user_id, email, status 
FROM profiles 
WHERE status = 'banned';

-- Check ban logs:
SELECT * FROM purchase_history 
WHERE plan_name = 'AUTO BAN - Multiple Free Claims';
```

## 🔍 Troubleshooting:

### Error: "function does not exist"
```sql
-- Check if functions exist:
SELECT proname FROM pg_proc 
WHERE proname LIKE '%auto_ban%';
```

### Error: "table does not exist"
```sql
-- Check tables:
SELECT table_name FROM information_schema.tables 
WHERE table_name IN ('profiles', 'purchase_history', 'pricing');
```

### Error: Still getting UUID mismatch
```sql
-- Check column types:
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'purchase_history' 
AND column_name IN ('user_id', 'plan_id');

SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'pricing' 
AND column_name = 'plan_id';
```

## 🧪 Testing Scenarios:

### Scenario 1: Normal Free Claim
1. User baru register
2. Claim free plan
3. **Expected:** Berhasil, status tetap active

### Scenario 2: Multiple Free Claim (Auto-Ban)
1. User yang sudah pernah claim free
2. Coba claim free lagi
3. **Expected:** Gagal + auto-ban + pesan security violation

### Scenario 3: Banned User Access
1. User yang sudah di-ban
2. Coba akses features
3. **Expected:** Redirect ke banned screen

## 📊 Monitoring Queries:

```sql
-- Users with multiple free claims:
SELECT * FROM get_multiple_free_claim_users();

-- Total banned users:
SELECT COUNT(*) as banned_users 
FROM profiles WHERE status = 'banned';

-- Ban activity today:
SELECT COUNT(*) as bans_today 
FROM purchase_history 
WHERE plan_name = 'AUTO BAN - Multiple Free Claims'
AND purchased_at >= CURRENT_DATE;

-- Recent ban activities:
SELECT 
  ph.purchased_at,
  p.user_id,
  p.email,
  ph.notes
FROM purchase_history ph
JOIN profiles p ON ph.user_id = p.id
WHERE ph.plan_name = 'AUTO BAN - Multiple Free Claims'
ORDER BY ph.purchased_at DESC
LIMIT 10;
```

## 🚀 Production Readiness:

### Pre-Production Checklist:
- [ ] Deploy FINAL SQL script
- [ ] Test normal free claim
- [ ] Test multiple free claim (ban)
- [ ] Test banned user experience
- [ ] Verify monitoring queries
- [ ] Check performance impact

### Go-Live Checklist:
- [ ] Restore original pricing_service.dart
- [ ] Remove testing modifications
- [ ] Deploy to production
- [ ] Monitor ban rates
- [ ] Set up alerting

## 🔙 Rollback Plan:
If issues occur in production:

1. **Emergency Disable:**
```sql
-- Disable auto-ban temporarily:
UPDATE profiles SET status = 'active' WHERE status = 'banned';
```

2. **Revert to Original Function:**
```dart
// In pricing_service.dart, change back to:
final response = await _supabase.rpc('purchase_plan', params: {...});
```

3. **Re-enable Restrictions:**
```dart
// Restore original canClaimFreePlan():
return response as bool? ?? false;
```

## 📞 Support:
- Check logs in purchase_history table
- Use monitoring queries for analysis
- Document any edge cases found

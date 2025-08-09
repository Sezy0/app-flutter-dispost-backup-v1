# 🔐 Server Access System - DisPost AutoPost

## 📋 Overview

Sistem akses server DisPost AutoPost berdasarkan nilai `max_config` di profil user yang sesuai dengan plan yang dibeli.

## 🗄️ Database Structure

### Tabel `profiles`
```sql
- id (UUID) - Primary Key
- user_id (VARCHAR) - Unique User ID  
- email (VARCHAR) - User Email
- max_config (INTEGER) - Maximum configurations allowed
- expired_plan (DATE) - Plan expiration date
- status (VARCHAR) - User status (active/banned)
- created_at (TIMESTAMP)
```

### Tabel `pricing`
```sql
- plan_id (UUID) - Primary Key
- name (VARCHAR) - Plan name
- max_config (INTEGER) - Maximum configurations for this plan
- pricing (DECIMAL) - Plan price
- expired_plan (INTEGER) - Duration in days
```

## 🎯 Server Access Logic

### Server 1 (Free Plan Access)
- **Requirement**: `max_config >= 1` AND `plan is active`
- **Target Users**: Users with Free Plan
- **Features**: Basic autopost functionality

### Server 2 (Basic Plan Access) 
- **Requirement**: `max_config >= 30` AND `plan is active`
- **Target Users**: Users with Basic Plan or higher
- **Features**: Enhanced autopost with more options

### Server 3 (Pro Plan Access)
- **Requirement**: `max_config >= 50` AND `plan is active` 
- **Target Users**: Users with Pro Plan
- **Features**: Premium autopost with advanced capabilities

## 📊 Plan Configuration Matrix

*Based on actual database values*

| Plan Type | max_config | Server Access | Duration | Database ID |
|-----------|------------|---------------|----------|-------------|
| No Plan   | 0 or null  | None          | -        | -           |
| Free Plan | 1          | Server 1      | Variable | varies      |
| Basic Plan| 30         | Server 1, 2   | Variable | varies      |
| Pro Plan  | 50+        | Server 1, 2, 3| Variable | varies      |

## 🔧 Code Implementation

### Core Functions

#### Check Server Access
```dart
// Individual server checks
UserService.hasServer1Access() // Free Plan (max_config >= 1)
UserService.hasServer2Access() // Basic Plan (max_config >= 30)  
UserService.hasServer3Access() // Pro Plan (max_config >= 50)

// Legacy compatibility
UserService.hasFreeTrial()  // Alias for hasServer1Access()
UserService.hasBasicPlan()  // Alias for hasServer2Access()
UserService.hasProPlan()    // Alias for hasServer3Access()
```

#### Helper Functions
```dart
// Get user plan type based on max_config
UserService.getUserPlanType() // Returns: 'Free Plan', 'Basic Plan', 'Pro Plan', 'No Plan'

// Get available servers for user
UserService.getAvailableServers() // Returns: [1, 2, 3] based on access

// Get complete access summary
UserService.getUserAccessSummary() // Returns full access info map
```

### Usage in UI
```dart
// AutoPost Screen
class _AutopostScreenState extends State<AutopostScreen> {
  bool _hasServer1Access = false;
  bool _hasServer2Access = false; 
  bool _hasServer3Access = false;
  
  Future<void> _checkUserAccess() async {
    final server1 = await UserService.hasServer1Access();
    final server2 = await UserService.hasServer2Access(); 
    final server3 = await UserService.hasServer3Access();
    
    setState(() {
      _hasServer1Access = server1;
      _hasServer2Access = server2;
      _hasServer3Access = server3;
    });
  }
}
```

## 🔄 Data Flow

1. **User Login** → Load profile from `profiles` table
2. **Access Check** → Compare `max_config` with server requirements  
3. **Plan Validation** → Check if `expired_plan` > current date
4. **UI Update** → Enable/disable server cards based on access
5. **Real-time Sync** → WebSocket updates for plan changes

## 🚦 Access Control Rules

### Requirements for Server Access:
1. ✅ **User authenticated** 
2. ✅ **Profile exists** in database
3. ✅ **Status = 'active'** (not banned)
4. ✅ **max_config >= server requirement**
5. ✅ **expired_plan > current_date**

### Edge Cases Handled:
- ❌ **No profile** → No access to any server
- ❌ **Banned user** → Redirect to banned screen
- ❌ **Expired plan** → No server access
- ❌ **max_config = null/0** → No server access

## 📱 UI Behavior

### Server Cards Display:
- **Enabled**: Gradient background, colored icon, clickable
- **Disabled**: Grayed out, lock icon, shows access requirement message

### Access Messages:
- Server 1: "Access requires Free Trial Access"
- Server 2: "Access requires Basic Plan Access" 
- Server 3: "Access requires Pro Plan Access"

## 🔧 Database Queries

### Check Server 1 Access:
```sql
SELECT max_config, expired_plan FROM profiles 
WHERE id = current_user_id 
AND max_config >= 1 
AND expired_plan > CURRENT_DATE
```

### Check Server 2 Access:
```sql  
SELECT max_config, expired_plan FROM profiles
WHERE id = current_user_id
AND max_config >= 30
AND expired_plan > CURRENT_DATE  
```

### Check Server 3 Access:
```sql
SELECT max_config, expired_plan FROM profiles
WHERE id = current_user_id  
AND max_config >= 50
AND expired_plan > CURRENT_DATE
```

## 🎛️ Admin Controls

### Update User Access:
```sql
-- Give user Basic Plan access
UPDATE profiles SET max_config = 30, expired_plan = '2024-12-31' 
WHERE id = 'user_uuid';

-- Give user Pro Plan access  
UPDATE profiles SET max_config = 50, expired_plan = '2024-12-31'
WHERE id = 'user_uuid';

-- Revoke access
UPDATE profiles SET max_config = 0, expired_plan = CURRENT_DATE - 1
WHERE id = 'user_uuid';
```

## 🔍 Monitoring & Debugging

### Useful Queries:
```sql
-- Check user access summary
SELECT email, max_config, expired_plan, status, 
       CASE 
         WHEN max_config >= 5 THEN 'Pro Plan'
         WHEN max_config >= 3 THEN 'Basic Plan' 
         WHEN max_config >= 1 THEN 'Free Plan'
         ELSE 'No Plan'
       END as plan_type
FROM profiles WHERE email = 'user@example.com';

-- Get users by server access
SELECT COUNT(*) as users, 
       CASE
         WHEN max_config >= 5 THEN 'Server 1,2,3'
         WHEN max_config >= 3 THEN 'Server 1,2'
         WHEN max_config >= 1 THEN 'Server 1' 
         ELSE 'No Access'
       END as server_access
FROM profiles 
WHERE expired_plan > CURRENT_DATE AND status = 'active'
GROUP BY server_access;
```

---

## 🚀 Migration Notes

**Old System** (purchase_history based) → **New System** (max_config based)

- Legacy functions maintained for backward compatibility
- UI automatically adapts to new access logic
- Real-time updates work seamlessly  
- Database queries optimized for performance

**Benefits:**
- ✅ Faster access checks (single table query)
- ✅ More reliable (no complex purchase history logic)
- ✅ Easier admin management
- ✅ Real-time plan updates
- ✅ Cleaner code architecture

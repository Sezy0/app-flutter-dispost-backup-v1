# 🔐 Enable Leaked Password Protection in Supabase

## Overview
Supabase Auth can prevent users from using compromised passwords by checking against HaveIBeenPwned.org database. This feature is currently **disabled** and needs to be enabled manually.

## Steps to Enable

### 1. Via Supabase Dashboard (Recommended)
1. Go to your Supabase project dashboard
2. Navigate to **Authentication** → **Settings**
3. Scroll down to **Security Settings**
4. Find **Password Security** section
5. Toggle **Enable leaked password protection** to **ON**
6. Save changes

### 2. Via Supabase CLI (Alternative)
```bash
# Update auth config
supabase auth update --password-min-length=8 --enable-leaked-password-protection=true
```

### 3. Via REST API (Advanced)
```bash
# Using curl to enable via Management API
curl -X PATCH \
  'https://api.supabase.com/v1/projects/{project_id}/config/auth' \
  -H 'Authorization: Bearer {access_token}' \
  -H 'Content-Type: application/json' \
  -d '{
    "SECURITY_CAPTCHA_ENABLED": false,
    "PASSWORD_MIN_LENGTH": 8,
    "SECURITY_PASSWORD_STRENGTH_ENABLED": true,
    "SECURITY_LEAKED_PASSWORD_PROTECTION_ENABLED": true
  }'
```

## What This Does

### ✅ **Benefits**
- **Prevents compromised passwords**: Users cannot use passwords that have been leaked in data breaches
- **Enhanced security**: Protects against credential stuffing attacks
- **Real-time checking**: Validates against HaveIBeenPwned database during signup/password changes
- **User education**: Shows users why their password was rejected

### 📋 **How It Works**
1. When user tries to set a password (signup/password reset)
2. Supabase sends SHA-1 hash of password to HaveIBeenPwned API
3. If password found in breach database → **Rejected with `WeakPasswordError`**
4. If password not found → **Accepted**

### 🔄 **Impact on Existing Users**
- **Current passwords**: Existing users can still sign in with current passwords
- **Password changes**: Will be checked against breach database
- **Sign-in validation**: Shows `WeakPasswordError` if password is compromised (but still allows login)

## Error Handling in Flutter

Add this error handling to your Flutter app:

```dart
try {
  final AuthResponse res = await supabase.auth.signInWithPassword(
    email: email,
    password: password,
  );
} on AuthException catch (error) {
  if (error.message.contains('WeakPasswordError')) {
    // Handle weak/leaked password
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Password Security Warning'),
        content: Text('Your password has been found in a data breach. '
                     'Please consider changing it for better security.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to password change screen
            },
            child: Text('Change Password'),
          ),
        ],
      ),
    );
  } else {
    // Handle other auth errors
    showError(error.message);
  }
}
```

## Testing

### Test Weak Passwords
Try these known compromised passwords (they should be rejected):
- `password123`
- `123456789`
- `qwertyuiop`

### Test Strong Passwords
These should be accepted:
- `MySecur3P@ssw0rd!`
- `B3tt3r_P@ssw0rd_2024`

## Verification

After enabling, run the Supabase Database Linter again to verify the warning is resolved:

```bash
# The auth_leaked_password_protection warning should be gone
```

## Security Best Practices

### Additional Recommendations
1. **Set minimum password length**: Recommend 8+ characters
2. **Enable password strength checking**: Require mix of letters, numbers, symbols
3. **Implement rate limiting**: Prevent brute force attacks
4. **Use MFA**: Add two-factor authentication for critical accounts
5. **Regular security audits**: Monitor for suspicious login patterns

### Password Policy Configuration
```json
{
  "password_min_length": 8,
  "password_require_uppercase": true,
  "password_require_lowercase": true,
  "password_require_numbers": true,
  "password_require_symbols": true,
  "leaked_password_protection": true
}
```

## 🎯 Result

After enabling this feature:
- ✅ **Security Warning Resolved**: `auth_leaked_password_protection` warning will disappear
- 🛡️ **Enhanced Security**: Users protected from using compromised passwords
- 📱 **Better UX**: Clear feedback when passwords are rejected
- 🔒 **Compliance**: Meets modern security standards for password protection

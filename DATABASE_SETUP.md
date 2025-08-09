# Database Setup Instructions

## Problem
Getting "Database error saving new user" when trying to register new users.

## Root Cause
The Supabase database tables, triggers, and functions haven't been set up yet. When a user registers:
1. ✅ Supabase Auth creates the user successfully
2. ❌ The trigger to create a profile record fails because tables/triggers don't exist

## Solution

### Step 1: Access Supabase Dashboard
1. Go to https://supabase.com/dashboard
2. Select your project: `mdsjedgyfbvtacijuflw`

### Step 2: Run Database Setup
1. Click on **"SQL Editor"** in the left sidebar
2. Copy the entire content from `db.sql/supabase_triggers.sql`
3. Paste it into the SQL Editor
4. Click **"Run"** to execute

### Step 3: Verification
After running the SQL, verify the setup:

1. **Check Tables Created**:
   - Go to "Table Editor" in dashboard
   - You should see a `profiles` table

2. **Check Triggers**:
   - Go to "Database" > "Triggers"
   - You should see `on_auth_user_created` trigger

3. **Test Registration**:
   - Try registering a new user in your app
   - Should work without the database error

## What the SQL Does

1. **Creates Functions**:
   - `generate_unique_user_id()`: Generates unique 6-digit user IDs
   - `handle_new_user()`: Creates profile when user registers
   - `update_last_login_time()`: Updates login timestamps

2. **Creates Tables**:
   - `profiles`: Stores user profile data

3. **Sets Up Security**:
   - Row Level Security (RLS) policies
   - User permissions

4. **Creates Triggers**:
   - Auto-creates profile when user registers
   - Auto-updates timestamps

## Testing
After setup, test with a new email address (don't reuse the failed registration email).

## Troubleshooting
If you still get errors after setup:
1. Check Supabase logs in dashboard
2. Verify all SQL executed without errors
3. Check if user was created in auth.users but not in profiles table

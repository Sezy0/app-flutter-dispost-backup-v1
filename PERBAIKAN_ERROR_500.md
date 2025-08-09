# Perbaikan Error 500 pada User Registration

## Masalah
- Error 500 dengan kode `unexpected_failure` saat signup
- Request berhasil sampai server tapi trigger database gagal
- User tidak bisa register karena profile tidak terbuat

## Penyebab
1. Table `profiles` belum ada atau tidak sesuai struktur
2. Trigger function ada error atau permission issue
3. RLS policy tidak tepat
4. Function security path tidak aman

## Solusi

### Langkah 1: Akses Supabase Dashboard
1. Buka https://supabase.com/dashboard
2. Pilih project Anda: `mdsjedgyfbvtacijuflw`

### Langkah 2: Jalankan SQL Perbaikan
1. Klik **"SQL Editor"** di sidebar kiri
2. Copy seluruh isi file `fixed_supabase_setup.sql`
3. Paste ke SQL Editor
4. Klik **"Run"** untuk execute

### Langkah 3: Verifikasi Setup
Setelah SQL berhasil dijalankan, cek:

1. **Table Created**:
   - Go to "Table Editor"
   - Pastikan ada table `profiles` dengan kolom yang benar

2. **Functions Created**:
   - Go to "Database" > "Functions"
   - Pastikan ada 3 functions:
     - `generate_unique_user_id()`
     - `handle_new_user()`
     - `update_last_login_time()`

3. **Triggers Created**:
   - Go to "Database" > "Triggers"  
   - Pastikan ada trigger `on_auth_user_created`

### Langkah 4: Test Registration
1. **Gunakan email baru** (jangan pakai email yang error sebelumnya)
2. Test signup di app Anda
3. Cek apakah berhasil tanpa error 500

### Yang Diperbaiki dalam SQL Script

1. **Security Fixes**:
   - Added `SET search_path = public` ke semua functions
   - Fixed function security settings

2. **Error Handling**:
   - Added `EXCEPTION` handling di `handle_new_user()`
   - Function tidak akan block user creation meski ada error

3. **Permissions**:
   - Added policy untuk `service_role`
   - Fixed grants untuk semua roles

4. **Clean Setup**:
   - Drop existing objects first
   - Rebuild dari nol untuk hindari conflict

## Troubleshooting

### Jika Masih Error 500:
1. Cek Supabase logs:
   - Go to "Logs" > "Database"
   - Lihat error messages

2. Test manual:
   ```sql
   -- Test di SQL Editor
   SELECT generate_unique_user_id();
   ```

3. Cek table structure:
   ```sql
   -- Test di SQL Editor  
   \d profiles
   ```

### Jika User Sudah Terbuat Tapi Tidak Ada Profile:
```sql
-- Manual insert profile untuk user existing
INSERT INTO profiles (id, user_id, email, status)
VALUES (
    'USER_UUID_DARI_AUTH_USERS',
    '123456', -- ganti dengan user_id unik
    'user@email.com',
    'active'
);
```

## Catatan Penting
- Setelah perbaikan, **selalu test dengan email baru**
- Jangan pakai email yang sudah pernah error
- Monitor logs untuk memastikan tidak ada error lagi

## Contact
Jika masih ada masalah, kirim screenshot:
1. Error message dari app
2. Supabase database logs
3. Table structure dari `profiles`

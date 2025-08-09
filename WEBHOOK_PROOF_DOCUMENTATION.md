# Discord Webhook Proof Notification - Implementasi

## Overview

Implementasi ini menambahkan fitur notifikasi webhook ke Discord ketika user mengupload bukti pembayaran (payment proof) di aplikasi DispostV1. Fitur ini terintegrasi dengan alur pembayaran yang sudah ada.

## Arsitektur & Alur

### 1. Alur Aplikasi
```
User Upload Proof → ImageUploadService (ImgBB) → Discord Webhook → Admin Notification
```

### 2. Komponen yang Dimodifikasi

#### A. DiscordWebhookService (lib/core/services/discord_webhook_service.dart)
- **Method Baru**: `sendProofNotification()`
- **Fitur**:
  - Mengirim embed dengan gambar proof
  - Menampilkan detail customer, plan, purchase ID
  - Format notifikasi dengan warna orange untuk membedakan dari purchase notification
  - Menyertakan method pembayaran dan notes jika ada

#### B. PaymentMethodScreen (lib/features/payment/screens/payment_method_screen.dart)
- **Method Baru**: `_sendProofNotification()`
- **Integrasi**: 
  - Otomatis mengirim webhook setelah upload image berhasil
  - Menggunakan data user yang sudah login
  - Menangani error dengan graceful fallback

### 3. Format Notifikasi Discord

```json
{
  "username": "DispostV1 Bot",
  "avatar_url": "https://cdn.discordapp.com/embed/avatars/0.png",
  "content": "🔔 **New payment proof received!** Please review and verify.",
  "embeds": [
    {
      "title": "📸 Payment Proof Submitted!",
      "color": 0xffa500,
      "fields": [
        {"name": "👤 Customer", "value": "user@example.com", "inline": true},
        {"name": "📦 Plan", "value": "Premium Plan", "inline": true},
        {"name": "🆔 Purchase ID", "value": "PURCHASE_123", "inline": true},
        {"name": "⏰ Submitted Time", "value": "2024-01-15 10:30:00", "inline": true},
        {"name": "💳 Payment Method", "value": "🏦 Bank Transfer", "inline": true},
        {"name": "📝 Notes", "value": "Paid via BCA", "inline": false}
      ],
      "image": {
        "url": "https://i.ibb.co/xxx/proof.jpg"
      },
      "footer": {
        "text": "DispostV1 Payment Proof System"
      },
      "timestamp": "2024-01-15T10:30:00.000Z"
    }
  ]
}
```

## Keamanan & Error Handling

### 1. Validasi User
- Memverifikasi user terautentikasi sebelum mengirim webhook
- Menggunakan email dari Supabase auth session

### 2. Graceful Error Handling
- Webhook failure tidak mengganggu proses upload
- Error ditampilkan sebagai notification ke user
- Fallback dengan pesan user-friendly

### 3. Rate Limiting
- Menggunakan existing Discord webhook yang sama
- Discord rate limit: 30 requests per minute per webhook

## Penggunaan

### Cara Kerja Otomatis
1. User pilih metode pembayaran
2. User upload bukti pembayaran
3. Image diupload ke ImgBB
4. **Otomatis**: Webhook dikirim ke Discord dengan gambar proof
5. Admin menerima notifikasi real-time

### Testing
```dart
// Test webhook proof notification
await DiscordWebhookService.sendProofNotification(
  userEmail: "test@example.com",
  planName: "Test Plan",
  purchaseId: "TEST_123",
  proofImageUrl: "https://i.ibb.co/test/image.jpg",
  paymentMethod: "bank",
  notes: "Test payment proof",
);
```

## Konfigurasi

### Discord Webhook URL
Sudah dikonfigurasi menggunakan webhook yang sama dengan purchase notification:
```dart
static const String _webhookUrl = 'https://discord.com/api/webhooks/1390292571862990908/F1uVZh_J20ZrqP4JJboJ-slrKDjF1PlFuwknvMZppn8356JupFKrpSRL5e-tEETjW51p';
```

### ImgBB Integration
Menggunakan existing ImageUploadService yang sudah terintegrasi dengan ImgBB API.

## Keuntungan Implementasi

1. **Real-time Notification**: Admin langsung dapat notifikasi ketika ada proof baru
2. **Visual Verification**: Gambar proof langsung tampil di Discord embed
3. **Konteks Lengkap**: Semua informasi penting tersedia dalam satu notifikasi
4. **Non-intrusive**: Tidak mengganggu flow user jika webhook gagal
5. **Konsisten**: Menggunakan format dan styling yang sama dengan notifikasi lain

## Maintenance

### Monitoring
- Check Discord webhook logs untuk delivery status
- Monitor ImgBB upload success rate
- Track user feedback untuk UX improvements

### Future Enhancements
- Add purchase ID tracking dari database
- Implement webhook retry mechanism
- Add admin dashboard untuk management
- Support multiple webhook destinations

## Troubleshooting

### Common Issues
1. **Webhook gagal**: Cek koneksi internet dan webhook URL validity
2. **Image tidak muncul**: Pastikan ImgBB API key valid dan image accessible
3. **User tidak terautentikasi**: Refresh login session
4. **Rate limiting**: Implementasi queue system jika diperlukan

### Debug Steps
1. Check console logs untuk error messages
2. Verify user authentication status
3. Test webhook URL manually
4. Validate image upload to ImgBB

---

**Implementasi ini sepenuhnya backward-compatible dan tidak mengubah existing functionality.** User experience tetap sama, dengan tambahan benefit real-time admin notification.

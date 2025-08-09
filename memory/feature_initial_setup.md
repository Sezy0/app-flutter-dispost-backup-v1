# Initial App Setup and Feature Structure

**Tanggal**: 2025-07-31

**Deskripsi**:
Inisialisasi proyek Flutter untuk aplikasi Android dan Windows dengan struktur folder yang rapi dan berorientasi fitur. Struktur ini memisahkan fungsionalitas utama (seperti otentikasi dan welcome screen) ke dalam modul-modul yang terpisah untuk memudahkan pengelolaan dan skalabilitas.

**File Terkait**:
- `lib/main.dart`: Titik masuk utama aplikasi.
- `lib/app.dart`: Widget root aplikasi yang menginisialisasi `MaterialApp` dan konfigurasi rute.
- `lib/core/routing/app_routes.dart`: Mendefinisikan semua rute navigasi dalam aplikasi.
- `lib/features/welcome/screens/welcome_screen.dart`: Halaman selamat datang dengan navigasi ke Login dan Register.
- `lib/features/auth/screens/login_screen.dart`: Halaman login.
- `lib/features/auth/screens/register_screen.dart`: Halaman registrasi.

**Struktur Folder**:
```
lib/
├── core/
│   ├── constants/          # Konstanta aplikasi (teks, warna, dll.)
│   ├── theme/              # Tema dan styling aplikasi
│   └── routing/            # Konfigurasi rute/navigasi
│       └── app_routes.dart
│
├── features/
│   ├── auth/               # Fitur Otentikasi (Login, Register)
│   │   ├── screens/        # Halaman/UI untuk fitur ini
│   │   │   ├── login_screen.dart
│   │   │   └── register_screen.dart
│   │   │
│   │   ├── widgets/        # Widget spesifik untuk fitur otentikasi
│   │   │
│   │   └── controllers/    # (Opsional) Logika bisnis/state management
│   │
│   └── welcome/            # Fitur Welcome
│       ├── screens/        # Halaman/UI untuk fitur ini
│       │   └── welcome_screen.dart
│       │
│       ├── widgets/        # Widget spesifik untuk fitur welcome
│       │
│       └── controllers/    # (Opsional) Logika bisnis/state management
│
├── main.dart               # Titik masuk utama aplikasi
└── app.dart                # Widget root aplikasi (MaterialApp)
```

**Tujuan**:
- Membangun fondasi proyek Flutter yang terstruktur dengan baik.
- Memisahkan logika dan UI berdasarkan fitur untuk kemudahan pengembangan dan pemeliharaan.
- Menyediakan halaman dasar untuk welcome, login, dan register dengan navigasi yang berfungsi.

**Catatan**:
- Folder `constants`, `theme`, `widgets`, dan `controllers` saat ini kosong dan akan diisi seiring pengembangan fitur.
- `pubspec.yaml` tidak dimodifikasi secara manual, `flutter create` sudah menanganinya.

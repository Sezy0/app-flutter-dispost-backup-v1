import 'package:flutter/material.dart';
import 'package:dispost_autopost/core/routing/app_routes.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dispost_autopost/features/home/screens/home_screen.dart';
import 'package:dispost_autopost/features/welcome/presentation/welcome_screen.dart';
import 'package:provider/provider.dart';
import 'package:dispost_autopost/core/providers/language_provider.dart';
import 'package:dispost_autopost/core/providers/theme_provider.dart';
import 'package:dispost_autopost/core/widgets/banned_check_wrapper.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => LanguageProvider()),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'DisPost AutoPost',
            theme: themeProvider.currentThemeData,
            home: const AuthWrapper(),
            routes: AppRoutes.routes,
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {

    try {
      // Coba akses Supabase stream
      return StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            // Jika ada error, langsung ke welcome screen
            return const WelcomeScreen();
          }
          
          if (snapshot.hasData) {
            final session = snapshot.data!.session;
            if (session != null) {
              // User is logged in, wrap with banned check and go to home
              return const BannedCheckWrapper(
                child: HomeScreen(),
              );
            } else {
              // User is not logged in, go to welcome
              return const WelcomeScreen();
            }
          }
          
          // Loading state
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Memuat aplikasi...'),
                  SizedBox(height: 8),
                  Text(
                    'Jika loading terlalu lama, akan otomatis pindah ke welcome screen',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      // Jika Supabase tidak terinisialisasi atau error, langsung ke welcome screen
      return const WelcomeScreen();
    }
  }
}

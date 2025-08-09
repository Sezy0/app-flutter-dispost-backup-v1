import 'package:dispost_autopost/features/home/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:dispost_autopost/features/auth/screens/login_screen.dart';
import 'package:dispost_autopost/features/auth/screens/register_screen.dart';
import 'package:dispost_autopost/features/auth/screens/otp_verification_screen.dart';
import 'package:dispost_autopost/features/auth/screens/forgot_password_screen.dart';
import 'package:dispost_autopost/features/auth/screens/reset_password_screen.dart';
import 'package:dispost_autopost/features/auth/screens/forgot_password_otp_screen.dart';
import 'package:dispost_autopost/features/more/screens/language_screen.dart';
import 'package:dispost_autopost/features/more/screens/theme_screen.dart';
import 'package:dispost_autopost/features/banned/screens/banned_screen.dart';
import 'package:dispost_autopost/features/history/screens/purchase_history_screen.dart';
import 'package:dispost_autopost/features/autopost/screens/server_1_screen.dart';
import 'package:dispost_autopost/features/autopost/screens/server_2_screen.dart';
import 'package:dispost_autopost/features/autopost/screens/server_3_screen.dart';
import 'package:dispost_autopost/features/autopost/screens/manage_token_screen.dart';

class AppRoutes {
  static const String welcomeRoute = '/';
  static const String loginRoute = '/login';
  static const String registerRoute = '/register';
  static const String homeRoute = '/home';
  static const String otpVerificationRoute = '/otp-verification';
  static const String forgotPasswordRoute = '/forgot-password';
  static const String resetPasswordRoute = '/reset-password';
  static const String forgotPasswordOtpRoute = '/forgot-password-otp';
  static const String languageRoute = '/language';
  static const String themeRoute = '/theme';
  static const String bannedRoute = '/banned';
  static const String purchaseHistoryRoute = '/purchase-history';
  static const String server1Route = '/server1';
  static const String server2Route = '/server2';
  static const String server3Route = '/server3';
  static const String manageTokenRoute = '/manage-token';

  static Map<String, WidgetBuilder> routes = {
    loginRoute: (context) => const LoginScreen(),
    registerRoute: (context) => const RegisterScreen(),
    otpVerificationRoute: (context) => OtpVerificationScreen(email: ModalRoute.of(context)!.settings.arguments as String), // Pass email argument
    homeRoute: (context) => const HomeScreen(),
    forgotPasswordRoute: (context) => const ForgotPasswordScreen(),
    resetPasswordRoute: (context) => ResetPasswordScreen(email: ModalRoute.of(context)!.settings.arguments as String),
    forgotPasswordOtpRoute: (context) => ForgotPasswordOtpScreen(email: ModalRoute.of(context)!.settings.arguments as String),
    languageRoute: (context) => const LanguageScreen(),
    themeRoute: (context) => const ThemeScreen(),
    bannedRoute: (context) => const BannedScreen(),
    purchaseHistoryRoute: (context) => const PurchaseHistoryScreen(),
    server1Route: (context) => const Server1Screen(),
    server2Route: (context) => const Server2Screen(),
    server3Route: (context) => const Server3Screen(),
    manageTokenRoute: (context) => const ManageTokenScreen(),
  };
}
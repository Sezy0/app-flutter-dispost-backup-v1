import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:dispost_autopost/core/routing/app_routes.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dispost_autopost/core/widgets/custom_notification.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final AuthResponse response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (response.user != null) {
        if (mounted) {
          showCustomNotification(
            context,
            'Registration successful! Please verify your email.',
            backgroundColor: Colors.green,
          );
          Navigator.of(context).pushNamed(AppRoutes.otpVerificationRoute, arguments: _emailController.text);
        }
      } else if (response.session == null && response.user == null) {
        // User needs to confirm email, but no session is created yet (email verification flow)
        if (mounted) {
          showCustomNotification(
            context,
            'Registration successful! Please verify your email using the link sent to your email address.',
            backgroundColor: Colors.green,
          );
          Navigator.of(context).pushNamed(AppRoutes.otpVerificationRoute, arguments: _emailController.text);
        }
      } else {
        // Handle other potential success cases or unexpected responses
        if (mounted) {
          showCustomNotification(
            context,
            'Registration successful, but something unexpected happened. Please check your email.',
            backgroundColor: Colors.orange,
          );
          Navigator.of(context).pushNamed(AppRoutes.otpVerificationRoute, arguments: _emailController.text);
        }
      }
    } on AuthException catch (e) {
      debugPrint('AuthException during registration: ${e.message}');
      debugPrint('AuthException code: ${e.statusCode}');
      if (mounted) {
        String errorMessage = e.message;
        // Handle specific error cases
        if (e.message.toLowerCase().contains('database error') || 
            e.message.toLowerCase().contains('trigger')) {
          errorMessage = 'Database error saving new user. Please contact support.';
        }
        showCustomNotification(
          context,
          errorMessage,
          backgroundColor: Colors.red,
        );
      }
    } catch (e) {
      debugPrint('Unexpected error during registration: ${e.toString()}');
      debugPrint('Error type: ${e.runtimeType}');
      if (mounted) {
        showCustomNotification(
          context,
          'Database error saving new user. Please try again or contact support.',
          backgroundColor: Colors.red,
        );
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Sign Up'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Create your new account to start your journey.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 20),
                // Lottie.asset(
                //   'assets/animations/owl.json',
                //   height: 200,
                //   fit: BoxFit.contain,
                // ),
                // const SizedBox(height: 40), // Add some space below the animation
                TextFormField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _buildInputDecoration('Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty || !value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _passwordController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _buildInputDecoration('Password'),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty || value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _confirmPasswordController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _buildInputDecoration('Confirm Password'),
                  obscureText: true,
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 40),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.black,
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _register,
                        child: const Text(
                          'Sign Up',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
              ],
            ).animate().fadeIn(duration: 600.ms),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: Colors.white.withAlpha((255 * 0.1).round()),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8), // Changed from 30 to 8
        borderSide: const BorderSide(color: Colors.white30),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8), // Changed from 30 to 8
        borderSide: const BorderSide(color: Colors.white),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8), // Changed from 30 to 8
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8), // Changed from 30 to 8
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }
}

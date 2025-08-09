import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:dispost_autopost/core/routing/app_routes.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dispost_autopost/core/widgets/custom_notification.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;

  const OtpVerificationScreen({super.key, required this.email});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  final List<TextEditingController> _otpDigitControllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (index) => FocusNode());
  bool _isLoading = false;

  @override
  void dispose() {
    _otpController.dispose();
    for (var controller in _otpDigitControllers) {
      controller.dispose();
    }
    for (var focusNode in _otpFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final otp = _otpDigitControllers.map((controller) => controller.text).join();
    if (otp.isEmpty || otp.length < 6) {
      showCustomNotification(
        context,
        'Please enter the complete OTP.',
        backgroundColor: Colors.red,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final AuthResponse response = await Supabase.instance.client.auth.verifyOTP(
        email: widget.email,
        token: otp,
        type: OtpType.signup,
      );

      if (response.user != null) {
        if (mounted) {
          showCustomNotification(
            context,
            'Account verified successfully!',
            backgroundColor: Colors.green,
          );
          Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.homeRoute, (route) => false);
        }
      } else {
        if (mounted) {
          showCustomNotification(
            context,
            'OTP verification failed. Please try again.',
            backgroundColor: Colors.red,
          );
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        showCustomNotification(
          context,
          e.message,
          backgroundColor: Colors.red,
        );
      }
    } catch (e) {
      if (mounted) {
        showCustomNotification(
          context,
          'An unexpected error occurred: ${e.toString()}',
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
        title: const Text('Verify OTP'),
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'A verification code has been sent to ${widget.email}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) => _buildOtpInput(index)),
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
                      onPressed: _verifyOtp,
                      child: const Text(
                        'Verify',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  // Resend OTP logic here
                  showCustomNotification(
                    context,
                    'Resending OTP...',
                    backgroundColor: Colors.blueAccent,
                  );
                },
                child: const Text(
                  'Resend OTP',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ).animate().fadeIn(duration: 600.ms),
        ),
      ),
    );
  }

  Widget _buildOtpInput(int index) {
    return SizedBox(
      width: 40, // Kurangi lebar dari 50 ke 40
      child: TextFormField(
        controller: _otpDigitControllers[index],
        focusNode: _otpFocusNodes[index],
        style: const TextStyle(color: Colors.white, fontSize: 24),
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          counterText: "", // Hide the counter
          filled: true,
          fillColor: Colors.white.withAlpha((255 * 0.1).round()),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.white30),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.white),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
        ),
        onChanged: (value) {
          if (value.length > 1) {
            // Ini kemungkinan adalah operasi tempel
            String pastedValue = value.replaceAll(RegExp(r'[^0-9]'), ''); // Bersihkan non-digit
            for (int i = 0; i < pastedValue.length; i++) {
              if (index + i < _otpDigitControllers.length) {
                _otpDigitControllers[index + i].text = pastedValue[i];
              }
            }
            // Pindahkan fokus ke bidang yang tersedia berikutnya atau unfocus jika semua terisi
            int nextFocusIndex = index + pastedValue.length;
            if (nextFocusIndex < _otpDigitControllers.length) {
              _otpFocusNodes[nextFocusIndex].requestFocus();
            } else {
              // Semua bidang terisi atau kita berada di bidang terakhir, unfocus
              _otpFocusNodes[_otpDigitControllers.length - 1].unfocus();
            }
          } else if (value.length == 1) {
            // Masukan satu digit
            // Pastikan hanya satu karakter di bidang saat ini
            _otpDigitControllers[index].text = value;
            if (index < _otpDigitControllers.length - 1) {
              _otpFocusNodes[index + 1].requestFocus();
            } else {
              _otpFocusNodes[index].unfocus(); // Jika digit terakhir, unfocus
            }
          } else if (value.isEmpty) {
            // Backspace atau hapus
            if (index > 0) {
              _otpFocusNodes[index - 1].requestFocus();
            }
          }
        },
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:dispost_autopost/core/services/user_service.dart';
import 'dart:async';

class BannedCheckWrapper extends StatefulWidget {
  final Widget child;

  const BannedCheckWrapper({
    super.key,
    required this.child,
  });

  @override
  State<BannedCheckWrapper> createState() => _BannedCheckWrapperState();
}

class _BannedCheckWrapperState extends State<BannedCheckWrapper> {
  Timer? _checkTimer;

  @override
  void initState() {
    super.initState();
    _startPeriodicBannedCheck();
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }

  void _startPeriodicBannedCheck() {
    // Check banned status every 30 seconds
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (mounted) {
        await _checkBannedStatus();
      }
    });
    
    // Also check immediately
    _checkBannedStatus();
  }

  Future<void> _checkBannedStatus() async {
    try {
      final profile = await UserService.getCurrentUserProfile();
      if (!mounted) return;
      if (profile != null && profile.isBanned) {
        Navigator.of(context).pushReplacementNamed('/banned');
      }
    } catch (e) {
      debugPrint('Error checking banned status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

import 'package:flutter/material.dart';

class CustomNotification extends StatefulWidget {
  final String message;
  final Color backgroundColor;
  final Duration duration;

  const CustomNotification({
    super.key,
    required this.message,
    required this.backgroundColor,
    this.duration = const Duration(seconds: 4),
  });

  @override
  State<CustomNotification> createState() => _CustomNotificationState();
}

class _CustomNotificationState extends State<CustomNotification> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);

    _controller.forward();

    Future.delayed(widget.duration, () {
      if (mounted) {
        _controller.reverse().then((_) => _removeNotification());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _removeNotification() {
    // This method is called after the reverse animation completes
    // You might want to remove the overlay entry here if used in an Overlay
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offsetAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Material(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(8.0),
              elevation: 4.0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                constraints: const BoxConstraints(maxWidth: 300),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.message,
                      style: const TextStyle(color: Colors.white, fontSize: 14.0),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Helper function to show the custom notification
void showCustomNotification(BuildContext context, String message, {Color backgroundColor = Colors.green, Duration duration = const Duration(seconds: 4)}) {
  final overlay = Overlay.of(context);
  OverlayEntry? overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (context) => CustomNotification(
      message: message,
      backgroundColor: backgroundColor,
      duration: duration,
      key: UniqueKey(), // Use a unique key for each notification
    ),
  );

  overlay.insert(overlayEntry);

  Future.delayed(duration + const Duration(milliseconds: 300), () {
    // Add a small delay for the fade-out animation
    overlayEntry?.remove();
    overlayEntry = null;
  });
}

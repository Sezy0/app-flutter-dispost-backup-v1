import 'dart:math';
import 'package:flutter/material.dart';

class WarpSpeedBackground extends StatefulWidget {
  const WarpSpeedBackground({super.key});

  @override
  State<WarpSpeedBackground> createState() => _WarpSpeedBackgroundState();
}

class _WarpSpeedBackgroundState extends State<WarpSpeedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Star> _stars = [];
  final int _starCount = 400;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (int i = 0; i < _starCount; i++) {
        _stars.add(Star(screenSize: MediaQuery.of(context).size));
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        for (var star in _stars) {
          star.update(MediaQuery.of(context).size);
        }
        return CustomPaint(
          painter: WarpSpeedPainter(_stars),
          child: Container(),
        );
      },
    );
  }
}

class Star {
  double x, y, z;
  late double pz;
  final Size screenSize;

  Star({required this.screenSize})
    : x = (Random().nextDouble() * 2 - 1) * screenSize.width,
      y = (Random().nextDouble() * 2 - 1) * screenSize.height,
      z = Random().nextDouble() * screenSize.width {
    pz = z;
  }

  void update(Size newSize) {
    z -= 10; // Speed
    if (z < 1) {
      x = (Random().nextDouble() * 2 - 1) * newSize.width;
      y = (Random().nextDouble() * 2 - 1) * newSize.height;
      z = newSize.width;
      pz = z;
    }
  }
}

class WarpSpeedPainter extends CustomPainter {
  final List<Star> stars;

  WarpSpeedPainter(this.stars);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..color = Colors.white
      ..strokeCap = StrokeCap.round;

    for (var star in stars) {
      double sx = (star.x / star.z) * size.width / 2 + center.dx;
      double sy = (star.y / star.z) * size.height / 2 + center.dy;

      double px = (star.x / star.pz) * size.width / 2 + center.dx;
      double py = (star.y / star.pz) * size.height / 2 + center.dy;

      double radius = max(0.1, (1 - star.z / size.width) * 2);
      paint.strokeWidth = radius;

      final colorValue = (1 - star.z / size.width).clamp(0.0, 1.0);
      paint.color = Color.lerp(
        Colors.purple,
        Colors.blue,
        colorValue,
      )!.withAlpha((colorValue * 255).toInt());

      canvas.drawLine(Offset(px, py), Offset(sx, sy), paint);
      star.pz = star.z;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

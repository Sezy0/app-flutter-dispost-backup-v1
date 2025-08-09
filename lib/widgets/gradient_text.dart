import 'package:flutter/material.dart';

class GradientText extends StatefulWidget {
  const GradientText({super.key, required this.text});

  final String text;

  @override
  GradientTextState createState() => GradientTextState();
}

class GradientTextState extends State<GradientText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4), // Memperlambat dari 2 detik menjadi 4 detik
      vsync: this,
    )..repeat(); // Bergerak terus menerus tanpa reverse
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
        return ShaderMask(
          shaderCallback: (bounds) {
            // Membuat efek shimmer yang bergerak dari kiri ke kanan dengan sudut miring
            final double moveValue = _controller.value * 3 - 1;
            return LinearGradient(
              begin: Alignment(-1.0, -0.5), // Mulai miring
              end: Alignment(1.0, 0.5),     // Berakhir miring
              colors: const [
                Color(0xFF7d3dfe),    // Ungu
                Color(0xFFFFFFFF),    // Putih (highlight)
                Color(0xFF7d3dfe),    // Ungu lagi
              ],
              stops: [
                (moveValue - 0.3).clamp(0.0, 1.0),
                moveValue.clamp(0.0, 1.0),
                (moveValue + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: Text(
            widget.text,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white, // Warna dasar untuk ShaderMask
            ),
          ),
        );
      },
    );
  }
}


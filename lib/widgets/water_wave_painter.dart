import 'dart:math';
import 'package:flutter/material.dart';

class WaterWaveProgress extends StatefulWidget {
  final double progress; // 0.0 to 1.0
  final double size;

  const WaterWaveProgress({super.key, required this.progress, this.size = 200});

  @override
  State<WaterWaveProgress> createState() => _WaterWaveProgressState();
}

class _WaterWaveProgressState extends State<WaterWaveProgress> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
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
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: WavePainter(
            animationValue: _controller.value,
            progress: widget.progress,
          ),
        );
      },
    );
  }
}

class WavePainter extends CustomPainter {
  final double animationValue;
  final double progress;

  WavePainter({required this.animationValue, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.blue.shade400;
    final path = Path();

    final yOffset = size.height * (1 - progress);
    final waveHeight = 8.0;

    path.moveTo(0, yOffset);
    for (double x = 0; x <= size.width; x++) {
      final y = yOffset + sin((x / size.width * 2 * pi) + (animationValue * 2 * pi)) * waveHeight;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    // Clip to circle
    final circlePath = Path()
      ..addOval(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.clipPath(circlePath);

    canvas.drawPath(path, paint);

    // Draw border
    final borderPaint = Paint()
      ..color = Colors.blue.shade100
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

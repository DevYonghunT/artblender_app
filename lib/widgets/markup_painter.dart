import 'package:flutter/material.dart';

class MarkupPainter extends CustomPainter {
  final List<Offset?> points;

  MarkupPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red // 마크업 선 색상
      ..strokeWidth = 10.0 // 마크업 선 두께
      ..strokeCap = StrokeCap.round; // 선 끝 모양

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // 마크업은 실시간으로 그려져야 하므로 항상 다시 그립니다.
  }
}

import 'package:flutter/material.dart';
import '../providers/canvas_provider.dart';

class DrawingPainter extends CustomPainter {
  final ShapeType shapeType;
  final List<Offset?> points;
  final Offset? startPoint;
  final Offset? currentPoint;
  final bool isPathClosed;

  DrawingPainter({
    required this.shapeType,
    required this.points,
    this.startPoint,
    this.currentPoint,
    required this.isPathClosed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.grey.shade700
      ..strokeWidth = 4.0 // 선 두께를 조금 더 두껍게 조정
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = Colors.black.withAlpha(80)
      ..style = PaintingStyle.fill;

    switch (shapeType) {
      case ShapeType.rectangle:
        if (startPoint != null && currentPoint != null) {
          final rect = Rect.fromPoints(startPoint!, currentPoint!);
          canvas.drawRect(rect, linePaint);
          canvas.drawRect(rect, fillPaint);
        }
        break;

      case ShapeType.circle:
        if (startPoint != null && currentPoint != null) {
          final rect = Rect.fromPoints(startPoint!, currentPoint!);
          canvas.drawOval(rect, linePaint);
          canvas.drawOval(rect, fillPaint);
        }
        break;

      case ShapeType.freeform:
        // 실시간 피드백을 위해 Path를 사용하는 방식으로 다시 수정합니다.
        final path = Path();
        // null이 아닌 유효한 점들만으로 경로를 구성합니다.
        final validPoints = points.where((p) => p != null).cast<Offset>();
        if (validPoints.isNotEmpty) {
          path.moveTo(validPoints.first.dx, validPoints.first.dy);
          for (final point in validPoints.skip(1)) {
            path.lineTo(point.dx, point.dy);
          }
        }
        canvas.drawPath(path, linePaint);

        if (isPathClosed) {
          canvas.drawPath(path, fillPaint);
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    // provider의 상태가 변경될 때마다 항상 다시 그리도록 수정 (실시간 피드백 보장)
    return true;
  }
}

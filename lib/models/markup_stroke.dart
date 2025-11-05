import 'package:flutter/material.dart';

class MarkupStroke {
  MarkupStroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });

  final List<Offset> points;
  final Color color;
  final double strokeWidth;
}

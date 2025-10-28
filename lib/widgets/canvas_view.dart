import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class CanvasView extends StatelessWidget {
  final GlobalKey repaintBoundaryKey;
  final File? backgroundImage;
  final Uint8List? cutoutImage;

  const CanvasView({
    super.key,
    required this.repaintBoundaryKey,
    required this.backgroundImage,
    required this.cutoutImage,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: repaintBoundaryKey,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (backgroundImage != null)
            Image.file(
              backgroundImage!,
              fit: BoxFit.cover,
            )
          else
            Container(color: Colors.grey[300]),
          if (cutoutImage != null)
            InteractiveViewer(
              boundaryMargin: const EdgeInsets.all(double.infinity),
              minScale: 0.1,
              maxScale: 4.0,
              child: Image.memory(cutoutImage!),
            ),
        ],
      ),
    );
  }
}

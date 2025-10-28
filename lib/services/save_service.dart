import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';

class SaveService {
  Future<bool> saveCompositeImage(GlobalKey repaintBoundaryKey) async {
    final BuildContext? context = repaintBoundaryKey.currentContext;
    if (context == null) {
      return false;
    }

    final RenderRepaintBoundary? boundary =
        context.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      return false;
    }

    final double pixelRatio = ui.View.of(context).devicePixelRatio;
    final double effectivePixelRatio = pixelRatio.clamp(1.0, 3.0);
    final ui.Image image = await boundary.toImage(
      pixelRatio: effectivePixelRatio,
    );
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      return false;
    }

    final Uint8List imageBytes = byteData.buffer.asUint8List();

    final result = await ImageGallerySaver.saveImage(
      imageBytes,
      quality: 95,
      name: "ArtBlender_${DateTime.now().millisecondsSinceEpoch}",
    );

    return result['isSuccess'] ?? false;
  }
}

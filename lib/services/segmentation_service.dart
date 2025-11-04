import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../providers/canvas_provider.dart'; // ShapeType을 위해 임포트

class SegmentationService {
  Future<ui.Image> _decodeImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final originalCodec = await ui.instantiateImageCodec(bytes);
    final frameInfo = await originalCodec.getNextFrame();
    final originalImage = frameInfo.image;

    const int maxDimension = 1080;
    if (originalImage.width > maxDimension || originalImage.height > maxDimension) {
      final resizedCodec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: originalImage.width > originalImage.height ? maxDimension : null,
        targetHeight: originalImage.height >= originalImage.width ? maxDimension : null,
      );
      final newFrameInfo = await resizedCodec.getNextFrame();
      originalImage.dispose();
      return newFrameInfo.image;
    }
    return originalImage;
  }

  // getCutoutImageBytes 함수 시그니처 수정
  Future<Uint8List?> getCutoutImageBytes(
      File imageFile, List<Offset?> rawPoints, Size viewSize, ShapeType shapeType) async {
    try {
      final ui.Image originalImage = await _decodeImage(imageFile);
      final imageSize =
          Size(originalImage.width.toDouble(), originalImage.height.toDouble());

      final FittedSizes fittedSizes =
          applyBoxFit(BoxFit.cover, imageSize, viewSize);

      final Rect outputRect = Offset.zero & viewSize;
      final Rect inputRect = Rect.fromLTWH(
          (imageSize.width - fittedSizes.source.width) / 2.0,
          (imageSize.height - fittedSizes.source.height) / 2.0,
          fittedSizes.source.width,
          fittedSizes.source.height);

      final List<Offset> imagePoints = [];
      final validPoints = rawPoints.where((p) => p != null).cast<Offset>();

      for (final point in validPoints) {
        final double dx = point.dx - outputRect.left;
        final double dy = point.dy - outputRect.top;

        final double scaledX =
            (dx / outputRect.width) * inputRect.width + inputRect.left;
        final double scaledY =
            (dy / outputRect.height) * inputRect.height + inputRect.top;

        imagePoints.add(Offset(scaledX, scaledY));
      }

      if (imagePoints.isEmpty) return null;

      // --- 로직 수정: shapeType에 따라 다른 경로 생성 ---
      final Path userPath = Path();
      switch (shapeType) {
        case ShapeType.circle:
          // 전달받은 점들로 사각형을 만들고, 그 안에 내접하는 타원을 경로로 사용합니다.
          final rect = Rect.fromPoints(imagePoints[0], imagePoints[2]);
          userPath.addOval(rect);
          break;
        case ShapeType.rectangle:
          final rect = Rect.fromPoints(imagePoints[0], imagePoints[2]);
          userPath.addRect(rect);
          break;
        case ShapeType.freeform:
        default:
          userPath.addPolygon(imagePoints, true);
          break;
      }
      // --- 로직 수정 끝 ---

      final imageRectPath = Path()
        ..addRect(Rect.fromLTWH(0, 0, imageSize.width, imageSize.height));

      final invertedPath = Path.combine(
        PathOperation.difference,
        imageRectPath,
        userPath,
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
          recorder, Rect.fromLTWH(0, 0, imageSize.width, imageSize.height));

      canvas.clipPath(invertedPath);
      canvas.drawImage(originalImage, Offset.zero, Paint());

      final picture = recorder.endRecording();
      final img =
          await picture.toImage(originalImage.width, originalImage.height);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        debugPrint('Failed to convert image to byte data.');
        return null;
      }

      originalImage.dispose();
      return byteData.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error creating cutout from path: $e');
      return null;
    }
  }

  Future<void> dispose() async {}
}

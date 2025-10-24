import 'package:flutter/foundation.dart'; // Uint8List를 위해 필요
import 'package:screenshot/screenshot.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';

class SaveService {
  Future<bool> saveCompositeImage(ScreenshotController controller) async {
    final Uint8List? imageBytes = await controller.capture();

    if (imageBytes != null) {
      final result = await ImageGallerySaver.saveImage(
        imageBytes,
        quality: 95,
        name: "ArtBlender_${DateTime.now().millisecondsSinceEpoch}",
      );

      return result['isSuccess'] ?? false;
    }
    return false;
  }
}
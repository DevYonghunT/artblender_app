import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class ImageService {
  final ImagePicker _picker = ImagePicker();
  bool _isPicking = false;

  Future<File?> getImageFromCamera() async {
    if (_isPicking) {
      return null;
    }
    _isPicking = true;
    try {
      final XFile? imageFile = await _picker.pickImage(source: ImageSource.camera);

      if (imageFile != null) {
        return File(imageFile.path);
      }
      return null;
    } on PlatformException {
      return null;
    } finally {
      _isPicking = false;
    }
  }
}

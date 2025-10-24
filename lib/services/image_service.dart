import 'dart:io';
import 'package:image_picker/image_picker.dart';

class ImageService {
  final ImagePicker _picker = ImagePicker();

  Future<File?> getImageFromCamera() async {
    final XFile? imageFile = await _picker.pickImage(source: ImageSource.camera);

    if (imageFile != null) {
      return File(imageFile.path);
    }
    return null;
  }
}
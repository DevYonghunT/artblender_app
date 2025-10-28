import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/image_service.dart';
import '../services/save_service.dart';
import '../services/segmentation_service.dart';

class CanvasProvider extends ChangeNotifier {
  final ImageService _imageService = ImageService();
  final SegmentationService _segmentationService = SegmentationService();
  final SaveService _saveService = SaveService();

  File? _backgroundImage;
  Uint8List? _cutoutImageBytes;
  bool _isLoading = false;

  File? get backgroundImage => _backgroundImage;
  Uint8List? get cutoutImage => _cutoutImageBytes;
  bool get isLoading => _isLoading;

  Future<void> loadDrawing() async {
    _setLoading(true);
    final File? originalImage = await _imageService.getImageFromCamera();
    if (originalImage == null) {
      _setLoading(false);
      return;
    }

    _cutoutImageBytes =
        await _segmentationService.getCutoutImageBytes(originalImage);
    _setLoading(false);
  }

  Future<void> loadBackground() async {
    _setLoading(true);
    _backgroundImage = await _imageService.getImageFromCamera();
    _setLoading(false);
  }

  Future<void> saveResult(GlobalKey repaintBoundaryKey) async {
    _setLoading(true);
    await _saveService.saveCompositeImage(repaintBoundaryKey);
    _setLoading(false);
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}

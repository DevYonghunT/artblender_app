import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:camera/camera.dart';
import '../services/image_service.dart';
import '../services/segmentation_service.dart';
import '../services/save_service.dart';

enum ShapeType { freeform, circle, rectangle }

class CanvasProvider extends ChangeNotifier {
  final ImageService _imageService = ImageService();
  final SegmentationService _segmentationService = SegmentationService();
  final SaveService _saveService = SaveService();

  File? _drawableImage;
  File? _backgroundImage;
  Uint8List? _cutoutImageBytes;
  bool _isLoading = false;

  ShapeType _shapeType = ShapeType.freeform;
  final List<Offset?> _points = [];
  Offset? _startPoint;
  Offset? _currentPoint;
  bool _isDrawing = false;

  bool _isPickingBackground = false;
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;

  File? get drawableImage => _drawableImage;
  File? get backgroundImage => _backgroundImage;
  Uint8List? get cutoutImage => _cutoutImageBytes;
  bool get isLoading => _isLoading;

  ShapeType get shapeType => _shapeType;
  List<Offset?> get points => _points;
  Offset? get startPoint => _startPoint;
  Offset? get currentPoint => _currentPoint;
  bool get isDrawing => _isDrawing;

  bool get isPickingBackground => _isPickingBackground;
  CameraController? get cameraController => _cameraController;
  bool get isPathClosed => _shapeType != ShapeType.freeform || (_points.isNotEmpty && _points.last == null) ;

  CanvasProvider() { _initializeCameras(); }
  Future<void> _initializeCameras() async {
    try {
      _cameras = await availableCameras();
    } on CameraException catch (e) { debugPrint('Camera Error: $e'); }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> loadDrawing() async {
    _setLoading(true);
    _cutoutImageBytes = null;
    _backgroundImage = null;
    clearDrawing();
    _drawableImage = await _imageService.getImageFromCamera();
    _setLoading(false);
  }

  void setShapeType(ShapeType type) {
    _shapeType = type;
    clearDrawing();
    notifyListeners();
  }

  void startDrawing(Offset point) {
    _isDrawing = true;
    if (_shapeType == ShapeType.freeform) {
      _points.add(point);
    } else {
      _startPoint = point;
      _currentPoint = point;
    }
    notifyListeners();
  }

  void updateDrawing(Offset point) {
    if (!_isDrawing) return;
    if (_shapeType == ShapeType.freeform) {
      _points.add(point);
    } else {
      _currentPoint = point;
    }
    notifyListeners();
  }

  void endDrawing() {
    _isDrawing = false;
    if (_shapeType == ShapeType.freeform) {
      _points.add(null);
    }
    notifyListeners();
  }

  void undo() {
    if (_shapeType == ShapeType.freeform) {
      if (_points.isEmpty) return;
      final lastNullIndex = _points.lastIndexWhere((p) => p == null, _points.length - 2);
      if(lastNullIndex != -1) {
         _points.removeRange(lastNullIndex + 1, _points.length);
      } else {
         _points.clear();
      }
    } else {
      clearDrawing();
    }
    notifyListeners();
  }

  void clearDrawing() {
    _points.clear();
    _startPoint = null;
    _currentPoint = null;
    notifyListeners();
  }

  Future<void> confirmCutout(BuildContext context) async {
    if (_drawableImage == null || !context.mounted) return;
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    List<Offset?> finalPoints = [];
    if (shapeType == ShapeType.rectangle || shapeType == ShapeType.circle) {
      if (_startPoint != null && _currentPoint != null) {
        final rect = Rect.fromPoints(_startPoint!, _currentPoint!);
        finalPoints.addAll([ rect.topLeft, rect.topRight, rect.bottomRight, rect.bottomLeft ]);
      }
    } else {
      finalPoints = List.from(_points);
    }

    if (finalPoints.isEmpty) return;

    _setLoading(true);
    // shapeType을 함께 전달합니다.
    _cutoutImageBytes = await _segmentationService.getCutoutImageBytes(
      _drawableImage!, finalPoints, box.size, shapeType);
    _drawableImage = null;
    clearDrawing();
    _setLoading(false);
  }

  Future<void> startBackgroundPicking() async {
    if (_cameras == null || _cameras!.isEmpty) return;
    _setLoading(true);
    await _cameraController?.dispose();
    _cameraController = CameraController(_cameras![0], ResolutionPreset.high);
    try {
      await _cameraController!.initialize();
      _isPickingBackground = true;
    } catch (e) {
      _isPickingBackground = false;
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> captureBackground() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    _setLoading(true);
    try {
      final XFile imageFile = await _cameraController!.takePicture();
      _backgroundImage = File(imageFile.path);
      _isPickingBackground = false;
    } catch (e) { 
      debugPrint('Error taking picture: $e');
    } finally {
      await _cameraController?.dispose();
      _cameraController = null;
      _setLoading(false);
    }
  }

  void cancelBackgroundPicking() {
    _isPickingBackground = false;
    _cameraController?.dispose();
    _cameraController = null;
    notifyListeners();
  }

  Future<void> saveResult(ScreenshotController controller) async {
    _setLoading(true);
    await _saveService.saveCompositeImage(controller);
    _setLoading(false);
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}

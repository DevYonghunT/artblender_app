import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import '../services/image_service.dart';
import '../services/segmentation_service.dart';
import '../services/save_service.dart';

enum ShapeType { freeform, circle, rectangle }
enum MarkupTarget { none, drawable, background }

class CanvasProvider extends ChangeNotifier {
  final ImageService _imageService = ImageService();
  final SegmentationService _segmentationService = SegmentationService();
  final SaveService _saveService = SaveService();

  File? _drawableImage;
  File? _backgroundImage;
  Uint8List? _cutoutImageBytes;
  bool _isLoading = false;

  MarkupTarget _markupTarget = MarkupTarget.none;
  File? _imageForMarkup;
  final List<Offset?> _markupPoints = [];

  ShapeType _shapeType = ShapeType.freeform;
  final List<Offset?> _points = [];
  Offset? _startPoint, _currentPoint;
  bool _isDrawing = false;

  bool _isPickingBackground = false;
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;

  bool get isMarkingUp => _markupTarget != MarkupTarget.none;
  File? get imageForMarkup => _imageForMarkup;
  List<Offset?> get markupPoints => _markupPoints;
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
  bool get isPathClosed => _shapeType != ShapeType.freeform || (_points.isNotEmpty && _points.last == null);

  CanvasProvider() { _initializeCameras(); }
  Future<void> _initializeCameras() async {
    try {
      _cameras = await availableCameras();
      // _cameras 필드를 사용하기 위해 여기서 초기화합니다.
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(_cameras![0], ResolutionPreset.high);
        await _cameraController!.initialize();
      } else {
        debugPrint('No cameras available or initialization failed.');
      }
    } on CameraException catch (e) { debugPrint('Camera Error: $e'); }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> loadDrawing() async {
    _setLoading(true);
    final originalImage = await _imageService.getImageFromCamera();
    _setLoading(false);
    if (originalImage == null) return;

    _cutoutImageBytes = null;
    _backgroundImage = null;
    clearDrawing();
    _markupTarget = MarkupTarget.drawable;
    _imageForMarkup = originalImage;
    _markupPoints.clear();
    notifyListeners();
  }

  void startMarkup(Offset point) {
    _markupPoints.add(point);
    notifyListeners();
  }
  void updateMarkup(Offset point) {
    _markupPoints.add(point);
    notifyListeners();
  }
  void endMarkup() {
    _markupPoints.add(null);
    notifyListeners();
  }

  void cancelMarkup() {
    _markupTarget = MarkupTarget.none;
    _imageForMarkup = null;
    _markupPoints.clear();
    notifyListeners();
  }

  Future<void> confirmMarkup() async {
    if (_imageForMarkup == null) return;
    _setLoading(true);

    final markedUpImageBytes = await _createMarkedUpImage();
    if (markedUpImageBytes == null) {
      _setLoading(false);
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final path = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.png';
    final markedUpImageFile = await File(path).writeAsBytes(markedUpImageBytes);

    if (_markupTarget == MarkupTarget.drawable) {
      _drawableImage = markedUpImageFile;
    } else if (_markupTarget == MarkupTarget.background) {
      _backgroundImage = markedUpImageFile;
    }

    _markupTarget = MarkupTarget.none;
    _imageForMarkup = null;
    _markupPoints.clear();
    _setLoading(false);
  }
  
  // startBackgroundPicking 메소드가 정의되어 있습니다.
  Future<void> startBackgroundPicking() async {
    if (_cameras == null || _cameras!.isEmpty) {
      debugPrint('No cameras available.');
      return;
    }
    _setLoading(true);
    await _cameraController?.dispose(); // 이전 컨트롤러 해제
    _cameraController = CameraController(_cameras![0], ResolutionPreset.high);
    try {
      await _cameraController!.initialize();
      _isPickingBackground = true;
    } catch (e) {
      debugPrint('Error initializing camera controller: $e');
      _isPickingBackground = false;
    } finally {
      _setLoading(false);
      notifyListeners(); // UI 업데이트를 위해 호출
    }
  }

  Future<void> captureBackground() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    _setLoading(true);
    
    XFile? imageFile;
    try {
      imageFile = await _cameraController!.takePicture();
    } catch (e) {
      debugPrint('Error taking picture: $e');
      _setLoading(false);
      await _cameraController?.dispose();
      _cameraController = null;
      notifyListeners();
      return;
    }
    
    await _cameraController!.dispose();
    _cameraController = null;
    _isPickingBackground = false;

    _markupTarget = MarkupTarget.background;
    _imageForMarkup = File(imageFile.path); 
    _markupPoints.clear();
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
    _cutoutImageBytes = await _segmentationService.getCutoutImageBytes(
      _drawableImage!, finalPoints, box.size, shapeType);
    _drawableImage = null;
    clearDrawing();
    _setLoading(false);
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
  
  Future<Uint8List?> _createMarkedUpImage() async {
    if (_imageForMarkup == null) return null;

    final bytes = await _imageForMarkup!.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()));
    
    canvas.drawImage(image, Offset.zero, Paint());

    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 10.0
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < _markupPoints.length - 1; i++) {
      if (_markupPoints[i] != null && _markupPoints[i + 1] != null) {
        canvas.drawLine(_markupPoints[i]!, _markupPoints[i + 1]!, paint);
      }
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(image.width, image.height);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    
    image.dispose();
    return byteData?.buffer.asUint8List();
  }
}

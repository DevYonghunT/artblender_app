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
import '../models/markup_stroke.dart';

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

  File? _subjectImage;
  File? _imageForMarkup;

  Size? _subjectImageSize;
  Size? _backgroundImageSize;
  Size? _cutoutImageSize;

  MarkupTarget _markupTarget = MarkupTarget.none;
  final List<MarkupStroke> _markupStrokes = [];
  MarkupStroke? _currentMarkupStroke;
  Color _markupColor = Colors.red;
  double _markupStrokeWidth = 6.0;

  ShapeType _shapeType = ShapeType.freeform;
  final List<Offset?> _points = [];
  Offset? _startPoint, _currentPoint;
  bool _isDrawing = false;

  bool _isPickingBackground = false;
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;

  bool get isMarkingUp => _markupTarget != MarkupTarget.none;
  MarkupTarget get markupTarget => _markupTarget;
  File? get imageForMarkup => _imageForMarkup;
  File? get subjectImage => _subjectImage;
  List<MarkupStroke> get markupStrokes => _markupStrokes;
  Color get markupColor => _markupColor;
  double get markupStrokeWidth => _markupStrokeWidth;
  File? get drawableImage => _drawableImage;
  File? get backgroundImage => _backgroundImage;
  Uint8List? get cutoutImage => _cutoutImageBytes;
  Size? get subjectImageSize => _subjectImageSize;
  Size? get backgroundImageSize => _backgroundImageSize;
  Size? get cutoutImageSize => _cutoutImageSize;
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
    _backgroundImageSize = null;
    clearDrawing();
    _markupTarget = MarkupTarget.drawable;
    _imageForMarkup = originalImage;
    _drawableImage = null;
    _subjectImage = originalImage;
    _subjectImageSize = await _getImageSizeFromFile(originalImage);
    _cutoutImageSize = null;
    _markupStrokes.clear();
    _currentMarkupStroke = null;
    notifyListeners();
  }

  void startMarkup(Offset point) {
    final stroke = MarkupStroke(
      points: [point],
      color: _markupColor,
      strokeWidth: _markupStrokeWidth,
    );
    _currentMarkupStroke = stroke;
    _markupStrokes.add(stroke);
    notifyListeners();
  }
  void updateMarkup(Offset point) {
    final stroke = _currentMarkupStroke;
    if (stroke == null) return;
    stroke.points.add(point);
    notifyListeners();
  }
  void endMarkup() {
    _currentMarkupStroke = null;
    notifyListeners();
  }

  void cancelMarkup() {
    final previousTarget = _markupTarget;
    _markupTarget = MarkupTarget.none;
    _imageForMarkup = null;
    _markupStrokes.clear();
    _currentMarkupStroke = null;
    if (previousTarget == MarkupTarget.drawable && _cutoutImageBytes == null) {
      _subjectImage = null;
      _subjectImageSize = null;
    }
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
      _subjectImage = markedUpImageFile;
      _subjectImageSize = await _getImageSizeFromFile(markedUpImageFile);
    } else if (_markupTarget == MarkupTarget.background) {
      _backgroundImage = markedUpImageFile;
      _backgroundImageSize = await _getImageSizeFromFile(markedUpImageFile);
    }

    _markupTarget = MarkupTarget.none;
    _imageForMarkup = null;
    _markupStrokes.clear();
    _currentMarkupStroke = null;
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
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    _setLoading(true);
    try {
      final imageFile = await controller.takePicture();

      _markupTarget = MarkupTarget.background;
      final file = File(imageFile.path);
      _imageForMarkup = file;
      _backgroundImage = null;
      _backgroundImageSize = null;
      _backgroundImageSize = await _getImageSizeFromFile(file);
      _markupStrokes.clear();
      _currentMarkupStroke = null;
      _isPickingBackground = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error taking picture: $e');
      _isPickingBackground = false;
      notifyListeners();
    } finally {
      await _cameraController?.dispose();
      _cameraController = null;
      _setLoading(false);
    }
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
    if (_cutoutImageBytes != null) {
      _cutoutImageSize = await _getImageSizeFromBytes(_cutoutImageBytes!);
    } else {
      _cutoutImageSize = null;
    }
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
  
  void setMarkupColor(Color color) {
    if (_markupColor == color) return;
    _markupColor = color;
    notifyListeners();
  }

  void setMarkupStrokeWidth(double width) {
    final clamped = width.clamp(2.0, 16.0).toDouble();
    if (_markupStrokeWidth == clamped) return;
    _markupStrokeWidth = clamped;
    notifyListeners();
  }

  void undoMarkup() {
    if (_markupStrokes.isEmpty) return;
    _markupStrokes.removeLast();
    _currentMarkupStroke = null;
    notifyListeners();
  }

  void clearMarkup() {
    if (_markupStrokes.isEmpty) return;
    _markupStrokes.clear();
    _currentMarkupStroke = null;
    notifyListeners();
  }

  Future<void> retakeCurrentCapture() async {
    if (_markupTarget == MarkupTarget.drawable) {
      _markupTarget = MarkupTarget.none;
      _imageForMarkup = null;
      _markupStrokes.clear();
      _currentMarkupStroke = null;
      notifyListeners();
      await loadDrawing();
    } else if (_markupTarget == MarkupTarget.background) {
      _markupTarget = MarkupTarget.none;
      _imageForMarkup = null;
      _markupStrokes.clear();
      _currentMarkupStroke = null;
      notifyListeners();
      await startBackgroundPicking();
    }
  }

  Future<Size?> _getImageSizeFromFile(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return _getImageSizeFromBytes(bytes);
    } catch (e) {
      debugPrint('Failed to read image size: $e');
      return null;
    }
  }

  Future<Size?> _getImageSizeFromBytes(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final size = Size(image.width.toDouble(), image.height.toDouble());
      image.dispose();
      return size;
    } catch (e) {
      debugPrint('Failed to decode image size: $e');
      return null;
    }
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

    for (final stroke in _markupStrokes) {
      if (stroke.points.length < 2) continue;
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      for (int i = 0; i < stroke.points.length - 1; i++) {
        canvas.drawLine(stroke.points[i], stroke.points[i + 1], paint);
      }
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(image.width, image.height);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    
    image.dispose();
    return byteData?.buffer.asUint8List();
  }
}

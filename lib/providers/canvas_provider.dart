import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';

import '../models/markup_stroke.dart';
import '../models/markup_text.dart';
import '../services/save_service.dart';
import '../services/segmentation_service.dart';

enum ShapeType { freeform, circle, rectangle }
enum MarkupTarget { none, drawable, background }

class CanvasProvider extends ChangeNotifier {
  CanvasProvider() {
    _initializeCameras();
  }

  final SegmentationService _segmentationService = SegmentationService();
  final SaveService _saveService = SaveService();

  File? _drawableImage;
  File? _backgroundImage;
  File? _subjectImage;
  File? _imageForMarkup;

  Uint8List? _cutoutImageBytes;

  Size? _subjectImageSize;
  Size? _backgroundImageSize;
  Size? _cutoutImageSize;

  bool _isLoading = false;

  final List<MarkupStroke> _markupStrokes = [];
  MarkupStroke? _currentMarkupStroke;

  final List<MarkupTextItem> _markupTexts = [];
  String? _activeMarkupTextId;
  int _nextMarkupTextId = 0;

  Offset? _markupMenuOffset;
  Size? _markupCanvasSize;
  bool _isTextEditing = false;

  Color _markupColor = Colors.red;
  double _markupStrokeWidth = 6.0;

  ShapeType _shapeType = ShapeType.freeform;
  final List<Offset?> _points = [];
  Offset? _startPoint;
  Offset? _currentPoint;
  bool _isDrawing = false;

  bool _isPickingSubject = false;
  bool _isPickingBackground = false;
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;

  MarkupTarget _markupTarget = MarkupTarget.none;

  bool get isLoading => _isLoading;
  bool get isMarkingUp => _markupTarget != MarkupTarget.none;
  MarkupTarget get markupTarget => _markupTarget;

  File? get drawableImage => _drawableImage;
  File? get backgroundImage => _backgroundImage;
  File? get subjectImage => _subjectImage;
  File? get imageForMarkup => _imageForMarkup;

  Uint8List? get cutoutImage => _cutoutImageBytes;

  Size? get subjectImageSize => _subjectImageSize;
  Size? get backgroundImageSize => _backgroundImageSize;
  Size? get cutoutImageSize => _cutoutImageSize;

  List<MarkupStroke> get markupStrokes => List.unmodifiable(_markupStrokes);
  double get markupStrokeWidth => _markupStrokeWidth;
  Color get markupColor => _markupColor;

  List<MarkupTextItem> get markupTexts => List.unmodifiable(_markupTexts);
  String? get activeMarkupTextId => _activeMarkupTextId;
  MarkupTextItem? get activeMarkupText {
    final id = _activeMarkupTextId;
    if (id == null) return null;
    for (final item in _markupTexts) {
      if (item.id == id) return item;
    }
    return null;
  }

  bool get isTextEditing => _isTextEditing;
  Offset get markupMenuOffset => _markupMenuOffset ?? const Offset(16, 16);
  Size? get markupCanvasSize => _markupCanvasSize;

  ShapeType get shapeType => _shapeType;
  List<Offset?> get points => List.unmodifiable(_points);
  Offset? get startPoint => _startPoint;
  Offset? get currentPoint => _currentPoint;
  bool get isDrawing => _isDrawing;

  bool get isPickingSubject => _isPickingSubject;
  bool get isPickingBackground => _isPickingBackground;
  CameraController? get cameraController => _cameraController;

  bool get isPathClosed =>
      _shapeType != ShapeType.freeform || (_points.isNotEmpty && _points.last == null);

  Future<void> _initializeCameras() async {
    if (_cameras != null) return;
    try {
      _cameras = await availableCameras();
    } on CameraException catch (e) {
      debugPrint('Camera Error: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  void updateMarkupCanvasSize(Size size) {
    if (_markupCanvasSize == size) return;
    _markupCanvasSize = size;
  }

  void ensureMarkupMenuOffset(Offset offset) {
    if (_markupMenuOffset != null) return;
    _markupMenuOffset = offset;
  }

  void setMarkupMenuOffset(Offset offset) {
    if (_markupMenuOffset == offset) return;
    _markupMenuOffset = offset;
    notifyListeners();
  }

  void selectMarkupText(String? id, {bool editing = false}) {
    final shouldEdit = editing && id != null;
    if (_activeMarkupTextId == id && _isTextEditing == shouldEdit) return;
    _activeMarkupTextId = id;
    _isTextEditing = shouldEdit;
    notifyListeners();
  }

  void setMarkupTextEditing(bool editing) {
    final shouldEdit = editing && _activeMarkupTextId != null;
    if (_isTextEditing == shouldEdit) return;
    _isTextEditing = shouldEdit;
    notifyListeners();
  }

  Future<void> loadDrawing() async {
    await startDrawablePicking();
  }

  Future<void> startDrawablePicking() async {
    await _initializeCameras();
    if (_cameras == null || _cameras!.isEmpty) {
      debugPrint('No cameras available.');
      return;
    }
    _setLoading(true);
    await _cameraController?.dispose();
    final controller = CameraController(_cameras!.first, ResolutionPreset.high);
    try {
      await controller.initialize();
      _cameraController = controller;
      _isPickingSubject = true;
      _isPickingBackground = false;
      _markupTarget = MarkupTarget.none;
      _imageForMarkup = null;
      _drawableImage = null;
      _subjectImage = null;
      _subjectImageSize = null;
      _cutoutImageBytes = null;
      _cutoutImageSize = null;
      _points.clear();
      _startPoint = null;
      _currentPoint = null;
      _isDrawing = false;
      _markupStrokes.clear();
      _markupTexts.clear();
      _currentMarkupStroke = null;
      _activeMarkupTextId = null;
      _markupMenuOffset = null;
      _isTextEditing = false;
    } catch (e) {
      debugPrint('Error initializing camera controller: $e');
      await controller.dispose();
      _cameraController = null;
      _isPickingSubject = false;
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  void startMarkup(Offset point) {
    if (_isTextEditing) return;
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

  void undoMarkup() {
    if (_currentMarkupStroke != null) {
      _currentMarkupStroke = null;
    }
    if (_markupStrokes.isNotEmpty) {
      _markupStrokes.removeLast();
      notifyListeners();
      return;
    }
    if (_markupTexts.isNotEmpty) {
      final removed = _markupTexts.removeLast();
      if (_activeMarkupTextId == removed.id) {
        _activeMarkupTextId = null;
        _isTextEditing = false;
      }
      notifyListeners();
    }
  }

  void clearMarkup() {
    _markupStrokes.clear();
    _markupTexts.clear();
    _currentMarkupStroke = null;
    _activeMarkupTextId = null;
    _markupMenuOffset = null;
    _isTextEditing = false;
    notifyListeners();
  }

  void cancelMarkup() {
    final previousTarget = _markupTarget;
    _markupTarget = MarkupTarget.none;
    _imageForMarkup = null;
    clearMarkup();
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
    clearMarkup();
    _setLoading(false);
  }

  void setMarkupColor(Color color) {
    if (_markupColor == color) return;
    _markupColor = color;
    if (_activeMarkupTextId != null) {
      final text = _findTextItem(_activeMarkupTextId!);
      if (text != null) {
        _replaceTextItem(text.copyWith(color: color));
      }
    }
    notifyListeners();
  }

  void setMarkupStrokeWidth(double width) {
    final clamped = width.clamp(2.0, 16.0).toDouble();
    if (_markupStrokeWidth == clamped) return;
    _markupStrokeWidth = clamped;
    notifyListeners();
  }

  void addMarkupText(Offset position) {
    final initialSize = const Size(220, 120);
    final item = MarkupTextItem(
      id: 'text_${_nextMarkupTextId++}',
      text: '텍스트',
      position: position,
      boxSize: initialSize,
      fontSize: 28.0,
      fontFamily: MarkupFontFamily.sansSerif,
      isBold: false,
      isItalic: false,
      isUnderline: false,
      boxStyle: MarkupTextBoxStyle.transparent,
      color: _markupColor,
    );
    _markupTexts.add(item);
    _activeMarkupTextId = item.id;
    _isTextEditing = true;
    notifyListeners();
  }

  void updateMarkupTextPosition(String id, Offset position) {
    final text = _findTextItem(id);
    if (text == null) return;
    _replaceTextItem(text.copyWith(position: position));
    notifyListeners();
  }

  void updateMarkupTextSize(String id, Size size) {
    final text = _findTextItem(id);
    if (text == null) return;
    final clampedWidth = size.width.clamp(120.0, 1200.0);
    final clampedHeight = size.height.clamp(80.0, 800.0);
    _replaceTextItem(
      text.copyWith(
        boxSize: Size(clampedWidth, clampedHeight),
      ),
    );
    notifyListeners();
  }

  void updateMarkupTextContent(String id, String textContent) {
    final text = _findTextItem(id);
    if (text == null) return;
    _replaceTextItem(text.copyWith(text: textContent));
    notifyListeners();
  }

  void setMarkupTextFont(String id, MarkupFontFamily fontFamily) {
    final text = _findTextItem(id);
    if (text == null || text.fontFamily == fontFamily) return;
    _replaceTextItem(text.copyWith(fontFamily: fontFamily));
    notifyListeners();
  }

  void toggleMarkupTextBold(String id) {
    final text = _findTextItem(id);
    if (text == null) return;
    _replaceTextItem(text.copyWith(isBold: !text.isBold));
    notifyListeners();
  }

  void toggleMarkupTextItalic(String id) {
    final text = _findTextItem(id);
    if (text == null) return;
    _replaceTextItem(text.copyWith(isItalic: !text.isItalic));
    notifyListeners();
  }

  void toggleMarkupTextUnderline(String id) {
    final text = _findTextItem(id);
    if (text == null) return;
    _replaceTextItem(text.copyWith(isUnderline: !text.isUnderline));
    notifyListeners();
  }

  void setMarkupTextBoxStyle(String id, MarkupTextBoxStyle style) {
    final text = _findTextItem(id);
    if (text == null || text.boxStyle == style) return;
    _replaceTextItem(text.copyWith(boxStyle: style));
    notifyListeners();
  }

  void removeMarkupText(String id) {
    final index = _markupTexts.indexWhere((item) => item.id == id);
    if (index == -1) return;
    final removed = _markupTexts.removeAt(index);
    if (_activeMarkupTextId == removed.id) {
      _activeMarkupTextId = null;
      _isTextEditing = false;
    }
    notifyListeners();
  }

  void setShapeType(ShapeType type) {
    if (_shapeType == type) return;
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
      final lastNullIndex =
          _points.lastIndexWhere((p) => p == null, _points.length - 2);
      if (lastNullIndex != -1) {
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
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    List<Offset?> finalPoints = [];
    if (_shapeType == ShapeType.rectangle || _shapeType == ShapeType.circle) {
      if (_startPoint != null && _currentPoint != null) {
        final rect = Rect.fromPoints(_startPoint!, _currentPoint!);
        finalPoints.addAll([
          rect.topLeft,
          rect.topRight,
          rect.bottomRight,
          rect.bottomLeft,
        ]);
      }
    } else {
      finalPoints = List.from(_points);
    }

    if (finalPoints.isEmpty) return;

    _setLoading(true);
    _cutoutImageBytes = await _segmentationService.getCutoutImageBytes(
      _drawableImage!,
      finalPoints,
      renderBox.size,
      _shapeType,
    );
    if (_cutoutImageBytes != null) {
      _cutoutImageSize = await _getImageSizeFromBytes(_cutoutImageBytes!);
    } else {
      _cutoutImageSize = null;
    }
    _drawableImage = null;
    clearDrawing();
    _setLoading(false);
  }

  Future<void> startBackgroundPicking() async {
    await _initializeCameras();
    if (_cameras == null || _cameras!.isEmpty) {
      debugPrint('No cameras available.');
      return;
    }
    _setLoading(true);
    await _cameraController?.dispose();
    final controller = CameraController(_cameras!.first, ResolutionPreset.high);
    try {
      await controller.initialize();
      _cameraController = controller;
      _isPickingSubject = false;
      _isPickingBackground = true;
    } catch (e) {
      debugPrint('Error initializing camera controller: $e');
      await controller.dispose();
      _cameraController = null;
      _isPickingSubject = false;
      _isPickingBackground = false;
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> captureBackground() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    _setLoading(true);
    try {
      final imageFile = await controller.takePicture();
      final file = File(imageFile.path);
      _markupTarget = MarkupTarget.background;
      _imageForMarkup = file;
      _backgroundImage = null;
      _backgroundImageSize = null;
      _markupStrokes.clear();
      _markupTexts.clear();
      _currentMarkupStroke = null;
      _activeMarkupTextId = null;
      _markupMenuOffset = null;
      _isTextEditing = false;
      _isPickingSubject = false;
      _isPickingBackground = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error taking picture: $e');
      _isPickingSubject = false;
      _isPickingBackground = false;
      notifyListeners();
    } finally {
      await _cameraController?.dispose();
      _cameraController = null;
      _setLoading(false);
    }
  }

  Future<void> captureDrawable() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    _setLoading(true);
    try {
      final imageFile = await controller.takePicture();
      final file = File(imageFile.path);
      _markupTarget = MarkupTarget.drawable;
      _imageForMarkup = file;
      _drawableImage = null;
      _subjectImage = file;
      _subjectImageSize = await _getImageSizeFromFile(file);
      _cutoutImageBytes = null;
      _cutoutImageSize = null;
      _points.clear();
      _startPoint = null;
      _currentPoint = null;
      _isDrawing = false;
      _markupStrokes.clear();
      _markupTexts.clear();
      _currentMarkupStroke = null;
      _activeMarkupTextId = null;
      _markupMenuOffset = null;
      _isTextEditing = false;
      _isPickingSubject = false;
      _isPickingBackground = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error taking picture: $e');
      _isPickingSubject = false;
      notifyListeners();
    } finally {
      await _cameraController?.dispose();
      _cameraController = null;
      _setLoading(false);
    }
  }

  void cancelDrawablePicking() {
    _isPickingSubject = false;
    _cameraController?.dispose();
    _cameraController = null;
    notifyListeners();
  }

  void cancelBackgroundPicking() {
    _isPickingSubject = false;
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

  Future<void> retakeCurrentCapture() async {
    if (_markupTarget == MarkupTarget.drawable) {
      _markupTarget = MarkupTarget.none;
      _imageForMarkup = null;
      _markupStrokes.clear();
      _markupTexts.clear();
      _currentMarkupStroke = null;
      _activeMarkupTextId = null;
      _markupMenuOffset = null;
      _isTextEditing = false;
      notifyListeners();
      await loadDrawing();
    } else if (_markupTarget == MarkupTarget.background) {
      _markupTarget = MarkupTarget.none;
      _imageForMarkup = null;
      _markupStrokes.clear();
      _markupTexts.clear();
      _currentMarkupStroke = null;
      _activeMarkupTextId = null;
      _markupMenuOffset = null;
      _isTextEditing = false;
      notifyListeners();
      await startBackgroundPicking();
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  MarkupTextItem? _findTextItem(String id) {
    for (final item in _markupTexts) {
      if (item.id == id) return item;
    }
    return null;
  }

  void _replaceTextItem(MarkupTextItem updated) {
    final index = _markupTexts.indexWhere((item) => item.id == updated.id);
    if (index == -1) return;
    _markupTexts[index] = updated;
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
    final file = _imageForMarkup;
    if (file == null) return null;

    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final viewSize = _markupCanvasSize ?? imageSize;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      );

      canvas.drawImage(image, Offset.zero, Paint());

      final fitted = applyBoxFit(BoxFit.cover, imageSize, viewSize);
      final destinationRect = Rect.fromLTWH(
        (viewSize.width - fitted.destination.width) / 2,
        (viewSize.height - fitted.destination.height) / 2,
        fitted.destination.width,
        fitted.destination.height,
      );
      final sourceRect = Rect.fromLTWH(
        (imageSize.width - fitted.source.width) / 2,
        (imageSize.height - fitted.source.height) / 2,
        fitted.source.width,
        fitted.source.height,
      );
      final scale = fitted.destination.width == 0
          ? 1.0
          : fitted.destination.width / fitted.source.width;

      Offset mapPoint(Offset point) {
        final dx = ((point.dx - destinationRect.left) / scale) + sourceRect.left;
        final dy = ((point.dy - destinationRect.top) / scale) + sourceRect.top;
        return Offset(dx, dy);
      }

      for (final stroke in _markupStrokes) {
        if (stroke.points.length < 2) continue;
        final paint = Paint()
          ..color = stroke.color
          ..strokeWidth = stroke.strokeWidth / scale
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

        for (int i = 0; i < stroke.points.length - 1; i++) {
          final from = mapPoint(stroke.points[i]);
          final to = mapPoint(stroke.points[i + 1]);
          canvas.drawLine(from, to, paint);
        }
      }

      for (final textItem in _markupTexts) {
        final origin = mapPoint(textItem.position);
        final mappedSize = Size(
          math.max(1.0, textItem.boxSize.width / scale),
          math.max(1.0, textItem.boxSize.height / scale),
        );
        final textStyle = textItem
            .buildTextStyle()
            .copyWith(fontSize: textItem.fontSize / scale);
        final textPainter = TextPainter(
          text: TextSpan(text: textItem.text, style: textStyle),
          textDirection: TextDirection.ltr,
          maxLines: null,
        )..layout(maxWidth: mappedSize.width);

        final rect = Rect.fromLTWH(
          origin.dx,
          origin.dy,
          mappedSize.width,
          mappedSize.height,
        );

        switch (textItem.boxStyle) {
          case MarkupTextBoxStyle.transparent:
            break;
          case MarkupTextBoxStyle.thinBorder:
          case MarkupTextBoxStyle.thickBorder:
            final strokeWidth =
                textItem.boxStyle == MarkupTextBoxStyle.thinBorder ? 2.0 : 4.0;
            final borderPaint = Paint()
              ..color = textItem.color
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth / scale;
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                rect.inflate(4.0 / scale),
                Radius.circular(8.0 / scale),
              ),
              borderPaint,
            );
            break;
        }

        canvas.save();
        canvas.clipRect(rect);
        textPainter.paint(canvas, rect.topLeft);
        canvas.restore();
      }

      final picture = recorder.endRecording();
      final rendered =
          await picture.toImage(image.width, image.height);
      final byteData =
          await rendered.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      rendered.dispose();
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Failed to create marked up image: $e');
      return null;
    }
  }
}

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:camera/camera.dart';
import '../providers/canvas_provider.dart';
import 'drawing_painter.dart';
import 'markup_painter.dart'; // 새로 생성할 마크업 페인터
import 'shape_selection_panel.dart';

class CanvasView extends StatelessWidget {
  final ScreenshotController controller;

  const CanvasView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Consumer<CanvasProvider>(
      builder: (context, provider, child) {
        // 마크업 모드일 때 최우선적으로 마크업 화면을 표시합니다.
        if (provider.isMarkingUp) {
          return buildMarkupCanvas(context, provider);
        }
        if (provider.isPickingBackground) {
          return buildCameraPreview(context, provider);
        }
        if (provider.drawableImage != null) {
          return buildDrawingCanvas(context, provider);
        }
        return buildCompositeCanvas(context, provider);
      },
    );
  }

  // --- 새로운 마크업 UI ---
  Widget buildMarkupCanvas(BuildContext context, CanvasProvider provider) {
    if (provider.imageForMarkup == null) {
      return const Center(child: Text('마크업할 이미지가 없습니다.'));
    }

    final targetSize = provider.markupTarget == MarkupTarget.background
        ? provider.backgroundImageSize
        : provider.subjectImageSize;

    return Stack(
      fit: StackFit.expand,
      children: [
        _buildFullScreenFile(
          context,
          provider.imageForMarkup!,
          size: targetSize,
        ),
        GestureDetector(
          onPanStart: (details) => provider.startMarkup(details.localPosition),
          onPanUpdate: (details) => provider.updateMarkup(details.localPosition),
          onPanEnd: (_) => provider.endMarkup(),
          child: CustomPaint(
            painter: MarkupPainter(strokes: provider.markupStrokes),
            child: const SizedBox.expand(),
          ),
        ),
        _buildMarkupControls(context, provider),
      ],
    );
  }

  Widget _buildMarkupControls(BuildContext context, CanvasProvider provider) {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.yellow,
      Colors.white,
      Colors.black,
    ];

    final scheme = Theme.of(context).colorScheme;
    final surface = scheme.surface;
    final toolbarColor = surface.withValues(alpha: 0.82);
    final topShadow = [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
        blurRadius: 20,
        offset: const Offset(0, 12),
      ),
    ];
    final retakeTooltip =
        provider.markupTarget == MarkupTarget.drawable ? '그림 재촬영' : '배경 재촬영';

    return Positioned.fill(
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: toolbarColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: topShadow,
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '되돌리기',
                    onPressed:
                        provider.markupStrokes.isEmpty ? null : () => provider.undoMarkup(),
                    style: IconButton.styleFrom(
                      backgroundColor: provider.markupStrokes.isEmpty
                          ? scheme.primary.withValues(alpha: 0.05)
                          : scheme.primary.withValues(alpha: 0.15),
                      foregroundColor: scheme.primary,
                      disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.undo_rounded),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '펜 두께',
                          style: TextStyle(
                            color: scheme.onSurface.withValues(alpha: 0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Slider(
                          value: provider.markupStrokeWidth,
                          onChanged: (value) => provider.setMarkupStrokeWidth(value),
                          min: 2,
                          max: 16,
                          divisions: 7,
                          label: provider.markupStrokeWidth.toStringAsFixed(0),
                          activeColor: scheme.primary,
                          inactiveColor: scheme.primary.withValues(alpha: 0.2),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '모두 지우기',
                    onPressed:
                        provider.markupStrokes.isEmpty ? null : () => provider.clearMarkup(),
                    style: IconButton.styleFrom(
                      backgroundColor: provider.markupStrokes.isEmpty
                          ? scheme.error.withValues(alpha: 0.05)
                          : scheme.error.withValues(alpha: 0.12),
                      foregroundColor: scheme.error,
                      disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.delete_sweep_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: toolbarColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: topShadow,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final color in colors)
                    GestureDetector(
                      onTap: () => provider.setMarkupColor(color),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: color == Colors.white ? 28 : 26,
                        height: color == Colors.white ? 28 : 26,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: provider.markupColor == color
                                ? scheme.primary
                                : scheme.outlineVariant.withValues(alpha: 0.4),
                            width: provider.markupColor == color ? 3 : 1.2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Tooltip(
                message: retakeTooltip,
                child: FilledButton.icon(
                  key: const ValueKey('retake_markup'),
                  onPressed: () => provider.retakeCurrentCapture(),
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.secondaryContainer,
                    foregroundColor: scheme.onSecondaryContainer,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('재촬영'),
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                key: const ValueKey('cancel_markup'),
                onPressed: () => provider.cancelMarkup(),
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.errorContainer,
                  foregroundColor: scheme.onErrorContainer,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                icon: const Icon(Icons.close_rounded),
                label: const Text('취소'),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                key: const ValueKey('confirm_markup'),
                onPressed: () => provider.confirmMarkup(),
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
                icon: const Icon(Icons.check_rounded),
                label: const Text('편집 완료'),
              ),
            ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 기존 카메라 미리보기 UI ---
  Widget buildCameraPreview(BuildContext context, CanvasProvider provider) {
    final cameraController = provider.cameraController;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    final scheme = Theme.of(context).colorScheme;
    final aspectRatio = cameraController.value.aspectRatio;

    final layers = <Widget>[
      if (provider.subjectImage != null)
        Positioned.fill(
          child: _buildFullScreenFile(
            context,
            provider.subjectImage!,
            size: provider.subjectImageSize,
            blur: true,
            opacity: 0.35,
          ),
        ),
      Positioned.fill(
        child: _buildFullScreenChild(
          context,
          CameraPreview(cameraController),
          aspectRatio,
        ),
      ),
    ];

    if (provider.cutoutImage != null) {
      layers.add(
        Positioned.fill(
          child: IgnorePointer(
            child: _buildFullScreenBytes(
              context,
              provider.cutoutImage!,
              size: provider.cutoutImageSize ?? provider.subjectImageSize,
              opacity: 0.85,
            ),
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        ...layers,
        Positioned(
          bottom: 80,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: () => provider.cancelBackgroundPicking(),
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.errorContainer,
                  foregroundColor: scheme.onErrorContainer,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                icon: const Icon(Icons.close_rounded),
                label: const Text('취소'),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: () => provider.captureBackground(),
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('촬영'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- 기존 그리기 UI ---
  Widget buildDrawingCanvas(BuildContext context, CanvasProvider provider) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildFullScreenFile(
          context,
          provider.drawableImage!,
          size: provider.subjectImageSize,
        ),
        GestureDetector(
          onPanStart: (details) => provider.startDrawing(details.localPosition),
          onPanUpdate: (details) => provider.updateDrawing(details.localPosition),
          onPanEnd: (details) => provider.endDrawing(),
          child: CustomPaint(
            painter: DrawingPainter(
              shapeType: provider.shapeType,
              points: provider.points,
              startPoint: provider.startPoint,
              currentPoint: provider.currentPoint,
              isPathClosed: provider.isPathClosed,
            ),
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          bottom: 80,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (provider.points.isNotEmpty || provider.startPoint != null) ...[
                FilledButton.icon(
                  onPressed: () => provider.undo(),
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.surfaceContainerHighest,
                    foregroundColor: scheme.onSurfaceVariant,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  icon: const Icon(Icons.undo_rounded),
                  label: const Text('되돌리기'),
                ),
                const SizedBox(width: 14),
                FilledButton.icon(
                  onPressed: () => provider.clearDrawing(),
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.errorContainer,
                    foregroundColor: scheme.onErrorContainer,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('지우기'),
                ),
              ],
              if ((provider.shapeType != ShapeType.freeform && provider.startPoint != null) ||
                  (provider.shapeType == ShapeType.freeform && provider.isPathClosed)) ...[
                if (provider.points.isNotEmpty || provider.startPoint != null)
                  const SizedBox(width: 14),
                FilledButton.icon(
                  onPressed: () => provider.confirmCutout(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('없애기'),
                ),
              ],
            ],
          ),
        ),
        const ShapeSelectionPanel(),
      ],
    );
  }

  // --- 합성 UI (backgroundImage 표시 오류 수정) ---
  Widget buildCompositeCanvas(BuildContext context, CanvasProvider provider) {
    final cutoutImage = provider.cutoutImage;
    final backgroundImage = provider.backgroundImage;

    return Screenshot(
      controller: controller,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          if (backgroundImage != null)
            Positioned.fill(
              child: _buildFullScreenFile(
                context,
                backgroundImage,
                size: provider.backgroundImageSize,
              ),
            )
          else if (provider.subjectImage != null)
            Positioned.fill(
              child: _buildFullScreenFile(
                context,
                provider.subjectImage!,
                size: provider.subjectImageSize,
              ),
            )
          else
            Positioned.fill(
              child: Container(color: Colors.grey[300]),
            ),
          if (cutoutImage != null)
            Positioned.fill(
              child: InteractiveViewer(
                boundaryMargin: const EdgeInsets.all(double.infinity),
                minScale: 0.1,
                maxScale: 4.0,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _ratioFromSize(
                          provider.cutoutImageSize ?? provider.subjectImageSize,
                        ) ??
                        _screenAspectRatio(context),
                    child: Image.memory(
                      cutoutImage,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFullScreenFile(
    BuildContext context,
    File file, {
    Size? size,
    bool blur = false,
    double opacity = 1.0,
  }) {
    Widget image = Image.file(file, fit: BoxFit.cover);
    if (blur) {
      image = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: image,
      );
    }
    return _buildFullScreenChild(
      context,
      image,
      _ratioFromSize(size) ?? _screenAspectRatio(context),
      opacity: opacity,
    );
  }

  Widget _buildFullScreenBytes(
    BuildContext context,
    Uint8List bytes, {
    Size? size,
    double opacity = 1.0,
  }) {
    final image = Image.memory(bytes, fit: BoxFit.cover);
    return _buildFullScreenChild(
      context,
      image,
      _ratioFromSize(size) ?? _screenAspectRatio(context),
      opacity: opacity,
    );
  }

  Widget _buildFullScreenChild(
    BuildContext context,
    Widget child,
    double aspectRatio, {
    double opacity = 1.0,
  }) {
    final ratio = aspectRatio <= 0 ? _screenAspectRatio(context) : aspectRatio;
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: ratio,
          height: 1,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: child,
          ),
        ),
      ),
    );
  }

  double? _ratioFromSize(Size? size) {
    if (size == null || size.height == 0) return null;
    return size.width / size.height;
  }

  double _screenAspectRatio(BuildContext context) {
    final size = MediaQuery.of(context).size;
    if (size.height == 0) return 1.0;
    return size.width / size.height;
  }
}

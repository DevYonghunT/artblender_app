import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';

import '../models/markup_text.dart';
import '../providers/canvas_provider.dart';
import 'drawing_painter.dart';
import 'markup_painter.dart';
import 'shape_selection_panel.dart';

class CanvasView extends StatefulWidget {
  const CanvasView({super.key, required this.controller});

  final ScreenshotController controller;

  @override
  State<CanvasView> createState() => _CanvasViewState();
}

class _CanvasViewState extends State<CanvasView> {
  final GlobalKey _markupMenuKey = GlobalKey();
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, FocusNode> _textFocusNodes = {};

  Size _markupMenuSize = Size.zero;
  Offset _menuDragStart = Offset.zero;
  bool _isMarkupMenuVisible = false;

  @override
  void dispose() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    for (final node in _textFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CanvasProvider>(
      builder: (context, provider, child) {
        if (!provider.isMarkingUp && _isMarkupMenuVisible) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _isMarkupMenuVisible = false);
          });
        }
        if (provider.isMarkingUp) {
          return buildMarkupCanvas(context, provider);
        }
        if (provider.isPickingSubject || provider.isPickingBackground) {
          return buildCameraPreview(context, provider);
        }
        if (provider.drawableImage != null) {
          return buildDrawingCanvas(context, provider);
        }
        return buildCompositeCanvas(context, provider);
      },
    );
  }

  Widget buildMarkupCanvas(BuildContext context, CanvasProvider provider) {
    final image = provider.imageForMarkup;
    if (image == null) {
      return const Center(child: Text('마크업할 이미지가 없습니다.'));
    }

    final targetSize = provider.markupTarget == MarkupTarget.background
        ? provider.backgroundImageSize
        : provider.subjectImageSize;

    return LayoutBuilder(
      builder: (context, constraints) {
        provider.updateMarkupCanvasSize(constraints.biggest);
        _cleanupTextResources(provider);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _updateMarkupMenuSize();
          provider.ensureMarkupMenuOffset(_defaultMenuOffset(context));
        });

        return Stack(
          fit: StackFit.expand,
          children: [
            _buildFullScreenFile(
              context,
              image,
              size: targetSize,
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (details) => provider.startMarkup(details.localPosition),
              onPanUpdate: (details) => provider.updateMarkup(details.localPosition),
              onPanEnd: (_) => provider.endMarkup(),
            child: CustomPaint(
              painter: MarkupPainter(strokes: provider.markupStrokes),
              child: const SizedBox.expand(),
            ),
          ),
          _buildMarkupTexts(context, provider, constraints.biggest),
          if (_isMarkupMenuVisible)
            _buildMarkupMenu(context, provider, constraints),
          _buildMarkupMenuToggle(context),
          _buildMarkupActions(context, provider),
        ],
      );
      },
    );
  }

  Widget _buildMarkupMenu(
    BuildContext context,
    CanvasProvider provider,
    BoxConstraints constraints,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final colors = <Color>[
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.yellow,
      Colors.white,
      Colors.black,
      Colors.purple,
      Colors.cyan,
    ];
    final isTextSelected = provider.activeMarkupTextId != null;
    final activeText = provider.activeMarkupText;
    final menuWidth = constraints.maxWidth.clamp(280.0, 360.0);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateMarkupMenuSize();
    });

    return Positioned(
      left: provider.markupMenuOffset.dx,
      top: provider.markupMenuOffset.dy,
      child: GestureDetector(
        onPanStart: (_) => _menuDragStart = provider.markupMenuOffset,
        onPanUpdate: (details) =>
            _handleMenuDrag(details.delta, provider, constraints),
        child: Material(
          color: Colors.transparent,
          child: Container(
            key: _markupMenuKey,
            width: menuWidth,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: '되돌리기',
                      onPressed: provider.markupStrokes.isEmpty &&
                              provider.markupTexts.isEmpty
                          ? null
                          : provider.undoMarkup,
                      icon: const Icon(Icons.undo_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: scheme.surfaceContainerHighest
                            .withValues(alpha: 0.45),
                        foregroundColor: scheme.primary,
                        disabledForegroundColor:
                            scheme.onSurface.withValues(alpha: 0.2),
                        disabledBackgroundColor:
                            scheme.surfaceContainerHighest.withValues(alpha: 0.12),
                      ),
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
                            onChanged: provider.setMarkupStrokeWidth,
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
                      onPressed: provider.markupStrokes.isEmpty &&
                              provider.markupTexts.isEmpty
                          ? null
                          : provider.clearMarkup,
                      icon: const Icon(Icons.delete_sweep_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor:
                            scheme.errorContainer.withValues(alpha: 0.4),
                        foregroundColor: scheme.error,
                        disabledForegroundColor:
                            scheme.onSurface.withValues(alpha: 0.2),
                        disabledBackgroundColor:
                            scheme.surfaceContainerHighest.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildColorPalette(colors, scheme, provider),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _handleAddText(provider),
                        icon: const Icon(Icons.text_fields_rounded),
                        label: const Text('텍스트 추가'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      tooltip: '선택한 텍스트 삭제',
                      onPressed: isTextSelected
                          ? () {
                              final id = provider.activeMarkupTextId;
                              if (id != null) {
                                provider.removeMarkupText(id);
                              }
                            }
                          : null,
                      icon: const Icon(Icons.delete_outline_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor:
                            scheme.errorContainer.withValues(alpha: 0.4),
                        foregroundColor: scheme.error,
                        disabledForegroundColor:
                            scheme.onSurfaceVariant.withValues(alpha: 0.2),
                        disabledBackgroundColor:
                            scheme.surfaceContainerHighest.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<MarkupFontFamily>(
                        key: ValueKey(provider.activeMarkupTextId),
                        initialValue:
                            activeText?.fontFamily ?? MarkupFontFamily.sansSerif,
                        onChanged: isTextSelected
                            ? (value) {
                                final id = provider.activeMarkupTextId;
                                if (value != null && id != null) {
                                  provider.setMarkupTextFont(id, value);
                                }
                              }
                            : null,
                        decoration: const InputDecoration(
                          labelText: '서체',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: MarkupFontFamily.values
                            .map(
                              (family) => DropdownMenuItem(
                                value: family,
                                child: Text(_fontLabel(family)),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildTextStyleToggle(
                      context: context,
                      tooltip: '굵게',
                      icon: Icons.format_bold_rounded,
                      selected: activeText?.isBold ?? false,
                      enabled: isTextSelected,
                      onPressed: () {
                        final id = provider.activeMarkupTextId;
                        if (id != null) provider.toggleMarkupTextBold(id);
                      },
                    ),
                    _buildTextStyleToggle(
                      context: context,
                      tooltip: '기울이기',
                      icon: Icons.format_italic_rounded,
                      selected: activeText?.isItalic ?? false,
                      enabled: isTextSelected,
                      onPressed: () {
                        final id = provider.activeMarkupTextId;
                        if (id != null) provider.toggleMarkupTextItalic(id);
                      },
                    ),
                    _buildTextStyleToggle(
                      context: context,
                      tooltip: '밑줄',
                      icon: Icons.format_underlined_rounded,
                      selected: activeText?.isUnderline ?? false,
                      enabled: isTextSelected,
                      onPressed: () {
                        final id = provider.activeMarkupTextId;
                        if (id != null) {
                          provider.toggleMarkupTextUnderline(id);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: MarkupTextBoxStyle.values.map((style) {
                      final selected = activeText?.boxStyle == style;
                      return ChoiceChip(
                        label: Text(_boxStyleLabel(style)),
                        selected: selected,
                        onSelected: isTextSelected
                            ? (_) {
                                final id = provider.activeMarkupTextId;
                                if (id != null) {
                                  provider.setMarkupTextBoxStyle(id, style);
                                }
                              }
                            : null,
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMarkupMenuToggle(BuildContext context) {
    return Positioned(
      bottom: 160,
      right: 24,
      child: FilledButton.tonalIcon(
        onPressed: () {
          setState(() => _isMarkupMenuVisible = !_isMarkupMenuVisible);
        },
        icon: Icon(_isMarkupMenuVisible ? Icons.close_fullscreen : Icons.tune),
        label: Text(_isMarkupMenuVisible ? '도구 닫기' : '도구 열기'),
      ),
    );
  }

  Widget _buildMarkupActions(BuildContext context, CanvasProvider provider) {
    final scheme = Theme.of(context).colorScheme;
    final greyStyle = FilledButton.styleFrom(
      backgroundColor: scheme.surfaceContainerHighest,
      foregroundColor: scheme.onSurface,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    );
    final whiteStyle = FilledButton.styleFrom(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    );
    final cancelStyle = OutlinedButton.styleFrom(
      foregroundColor: scheme.onSurfaceVariant,
      side: BorderSide(color: scheme.outline.withValues(alpha: 0.4)),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    );
    final retakeTooltip =
        provider.markupTarget == MarkupTarget.drawable ? '그림 재촬영' : '배경 재촬영';

    return Positioned(
      bottom: 80,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Tooltip(
            message: retakeTooltip,
            child: FilledButton.icon(
              key: const ValueKey('retake_markup'),
              onPressed: () => provider.retakeCurrentCapture(),
              style: greyStyle,
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('재촬영'),
            ),
          ),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            key: const ValueKey('cancel_markup'),
            onPressed: provider.cancelMarkup,
            style: cancelStyle,
            icon: const Icon(Icons.close_rounded),
            label: const Text('취소'),
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            key: const ValueKey('confirm_markup'),
            onPressed: provider.confirmMarkup,
            style: whiteStyle,
            icon: const Icon(Icons.check_rounded),
            label: const Text('편집 완료'),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkupTexts(
    BuildContext context,
    CanvasProvider provider,
    Size canvasSize,
  ) {
    return Stack(
      children: [
        for (final item in provider.markupTexts)
          _MarkupTextHandle(
            key: ValueKey(item.id),
            item: item,
            isActive: provider.activeMarkupTextId == item.id,
            isEditing:
                provider.isTextEditing && provider.activeMarkupTextId == item.id,
            controller: _controllerFor(item),
            focusNode: _focusNodeFor(item.id),
            canvasSize: canvasSize,
            onTap: () => provider.selectMarkupText(item.id, editing: false),
            onRequestEdit: () => provider.selectMarkupText(item.id, editing: true),
            onFocusLost: () => provider.setMarkupTextEditing(false),
            onChanged: (value) => provider.updateMarkupTextContent(item.id, value),
            onPositionChanged: (offset) => provider.updateMarkupTextPosition(
              item.id,
              _clampTextOffset(offset, item.boxSize, canvasSize),
            ),
            onSizeChanged: (size) => provider.updateMarkupTextSize(item.id, size),
            onRemove: () => provider.removeMarkupText(item.id),
          ),
      ],
    );
  }

  Widget _buildColorPalette(
    List<Color> colors,
    ColorScheme scheme,
    CanvasProvider provider,
  ) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        for (final color in colors)
          GestureDetector(
            onTap: () => provider.setMarkupColor(color),
            child: Container(
              width: color == Colors.white ? 30 : 28,
              height: color == Colors.white ? 30 : 28,
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
    );
  }

  IconButton _buildTextStyleToggle({
    required BuildContext context,
    required String tooltip,
    required IconData icon,
    required bool selected,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon),
      color: selected ? scheme.primary : scheme.onSurfaceVariant,
      style: IconButton.styleFrom(
        backgroundColor: selected
            ? scheme.primary.withValues(alpha: 0.15)
            : scheme.surfaceContainerHighest.withValues(
                alpha: enabled ? 0.4 : 0.2,
              ),
        disabledBackgroundColor:
            scheme.surfaceContainerHighest.withValues(alpha: 0.12),
      ),
    );
  }

  void _cleanupTextResources(CanvasProvider provider) {
    final ids = provider.markupTexts.map((e) => e.id).toSet();
    final controllerIds =
        _textControllers.keys.where((id) => !ids.contains(id)).toList();
    for (final id in controllerIds) {
      _textControllers.remove(id)?.dispose();
    }
    final focusIds =
        _textFocusNodes.keys.where((id) => !ids.contains(id)).toList();
    for (final id in focusIds) {
      _textFocusNodes.remove(id)?.dispose();
    }
  }

  void _updateMarkupMenuSize() {
    final context = _markupMenuKey.currentContext;
    if (context == null) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;
    if (_markupMenuSize == size) return;
    setState(() {
      _markupMenuSize = size;
    });
  }

  Offset _defaultMenuOffset(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    return Offset(16, padding.top + _verticalPadding(context) + 12);
  }

  double _verticalPadding(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    if (screenHeight <= 0) return 0;
    return (screenHeight * 0.1).clamp(0.0, screenHeight / 2);
  }

  void _handleMenuDrag(
    Offset delta,
    CanvasProvider provider,
    BoxConstraints constraints,
  ) {
    final proposed = _menuDragStart + delta;
    final clamped = _clampMenuOffset(proposed, constraints);
    provider.setMarkupMenuOffset(clamped);
  }

  Offset _clampMenuOffset(Offset offset, BoxConstraints constraints) {
    final minX = 16.0;
    final minY = 16.0;
    final maxX = math.max(
      minX,
      constraints.maxWidth - _markupMenuSize.width - 16,
    );
    final maxY = math.max(
      minY,
      constraints.maxHeight - _markupMenuSize.height - 16,
    );
    final dx = offset.dx.clamp(minX, maxX);
    final dy = offset.dy.clamp(minY, maxY);
    return Offset(dx, dy);
  }

  void _handleAddText(CanvasProvider provider) {
    final canvasSize = provider.markupCanvasSize;
    const initialSize = Size(220, 120);
    Offset defaultOffset;
    if (canvasSize == null) {
      defaultOffset = const Offset(24, 24);
    } else {
      final centered = Offset(
        (canvasSize.width - initialSize.width) / 2,
        _verticalPadding(context) + 24,
      );
      defaultOffset = _clampTextOffset(centered, initialSize, canvasSize);
    }
    provider.addMarkupText(defaultOffset);
    setState(() => _isMarkupMenuVisible = true);
  }

  TextEditingController _controllerFor(MarkupTextItem item) {
    final controller = _textControllers.putIfAbsent(
      item.id,
      () => TextEditingController(text: item.text),
    );
    if (controller.text != item.text) {
      final selection = controller.selection;
      final base = selection.baseOffset.clamp(0, item.text.length);
      final extent = selection.extentOffset.clamp(0, item.text.length);
      controller
        ..text = item.text
        ..selection = TextSelection(baseOffset: base, extentOffset: extent);
    }
    return controller;
  }

  FocusNode _focusNodeFor(String id) {
    return _textFocusNodes.putIfAbsent(id, () => FocusNode());
  }

  Offset _clampTextOffset(Offset offset, Size boxSize, Size canvasSize) {
    final dx = offset.dx
        .clamp(0.0, math.max(0.0, canvasSize.width - boxSize.width))
        .toDouble();
    final dy = offset.dy
        .clamp(0.0, math.max(0.0, canvasSize.height - boxSize.height))
        .toDouble();
    return Offset(dx, dy);
  }

  Widget buildCameraPreview(BuildContext context, CanvasProvider provider) {
    final cameraController = provider.cameraController;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    final scheme = Theme.of(context).colorScheme;
    final isSubjectCapture = provider.isPickingSubject;
    final subjectRatio = _ratioFromSize(provider.subjectImageSize);
    final aspectRatio =
        subjectRatio ?? cameraController.value.aspectRatio;

    final layers = <Widget>[
      if (!isSubjectCapture && provider.subjectImage != null)
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
          fit: isSubjectCapture ? BoxFit.contain : BoxFit.cover,
        ),
      ),
    ];

    if (!isSubjectCapture && provider.cutoutImage != null) {
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
                onPressed: isSubjectCapture
                    ? provider.cancelDrawablePicking
                    : provider.cancelBackgroundPicking,
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.errorContainer,
                  foregroundColor: scheme.onErrorContainer,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: const Icon(Icons.close_rounded),
                label: const Text('취소'),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: isSubjectCapture
                    ? provider.captureDrawable
                    : provider.captureBackground,
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
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
          onPanEnd: (_) => provider.endDrawing(),
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
                  onPressed: provider.undo,
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.surfaceContainerHighest,
                    foregroundColor: scheme.onSurfaceVariant,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.undo_rounded),
                  label: const Text('되돌리기'),
                ),
                const SizedBox(width: 14),
                FilledButton.icon(
                  onPressed: provider.clearDrawing,
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.errorContainer,
                    foregroundColor: scheme.onErrorContainer,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('지우기'),
                ),
              ],
              if ((provider.shapeType != ShapeType.freeform &&
                      provider.startPoint != null) ||
                  (provider.shapeType == ShapeType.freeform &&
                      provider.isPathClosed)) ...[
                if (provider.points.isNotEmpty || provider.startPoint != null)
                  const SizedBox(width: 14),
                FilledButton.icon(
                  onPressed: () => provider.confirmCutout(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
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

  Widget buildCompositeCanvas(BuildContext context, CanvasProvider provider) {
    final cutoutImage = provider.cutoutImage;
    final backgroundImage = provider.backgroundImage;

    return Screenshot(
      controller: widget.controller,
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
    BoxFit fit = BoxFit.cover,
  }) {
    final ratio = aspectRatio <= 0 ? _screenAspectRatio(context) : aspectRatio;
    final screenSize = MediaQuery.of(context).size;
    final verticalPadding = screenSize.height <= 0
        ? 0.0
        : (screenSize.height * 0.1)
            .clamp(0.0, screenSize.height / 2)
            .toDouble();

    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      child: SizedBox.expand(
        child: FittedBox(
          fit: fit,
          child: SizedBox(
            width: ratio,
            height: 1,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: child,
            ),
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

class _MarkupTextHandle extends StatefulWidget {
  const _MarkupTextHandle({
    super.key,
    required this.item,
    required this.isActive,
    required this.isEditing,
    required this.controller,
    required this.focusNode,
    required this.canvasSize,
    required this.onTap,
    required this.onRequestEdit,
    required this.onFocusLost,
    required this.onChanged,
    required this.onPositionChanged,
    required this.onSizeChanged,
    required this.onRemove,
  });

  final MarkupTextItem item;
  final bool isActive;
  final bool isEditing;
  final TextEditingController controller;
  final FocusNode focusNode;
  final Size canvasSize;
  final VoidCallback onTap;
  final VoidCallback onRequestEdit;
  final VoidCallback onFocusLost;
  final ValueChanged<String> onChanged;
  final ValueChanged<Offset> onPositionChanged;
  final ValueChanged<Size> onSizeChanged;
  final VoidCallback onRemove;

  @override
  State<_MarkupTextHandle> createState() => _MarkupTextHandleState();
}

class _MarkupTextHandleState extends State<_MarkupTextHandle> {
  static const Size _minSize = Size(120, 80);

  late Offset _currentOffset;
  late Size _currentSize;
  Size? _resizeStartSize;

  @override
  void initState() {
    super.initState();
    _currentOffset = widget.item.position;
    _currentSize = widget.item.boxSize;
    widget.focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant _MarkupTextHandle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.position != _currentOffset) {
      _currentOffset = widget.item.position;
    }
    if (widget.item.boxSize != _currentSize) {
      _currentSize = widget.item.boxSize;
    }
    if (widget.controller.text != widget.item.text) {
      final selection = widget.controller.selection;
      final base = selection.baseOffset.clamp(0, widget.item.text.length);
      final extent = selection.extentOffset.clamp(0, widget.item.text.length);
      widget.controller
        ..text = widget.item.text
        ..selection = TextSelection(baseOffset: base, extentOffset: extent);
    }
    if (widget.isEditing && !widget.focusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        FocusScope.of(context).requestFocus(widget.focusNode);
      });
    } else if (!widget.isEditing && widget.focusNode.hasFocus) {
      widget.focusNode.unfocus();
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocusChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final padding = _paddingForStyle(widget.item.boxStyle);
    final textStyle = widget.item.buildTextStyle();
    final borderRadius = BorderRadius.circular(12);

    final Widget textContent = widget.isEditing
        ? TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            keyboardType: TextInputType.multiline,
            cursorColor: widget.item.color,
            style: textStyle,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: widget.onChanged,
            onTap: widget.onRequestEdit,
            minLines: null,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
          )
        : Align(
            alignment: Alignment.topLeft,
            child: Text(
              widget.item.text,
              style: textStyle,
              softWrap: true,
            ),
          );

    final Widget contentBox = SizedBox(
      width: _currentSize.width,
      height: _currentSize.height,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Padding(
          padding: padding,
          child: widget.isEditing
              ? textContent
              : SingleChildScrollView(
                  padding: EdgeInsets.zero,
                  child: textContent,
                ),
        ),
      ),
    );

    final Widget borderedBox = widget.item.boxStyle == MarkupTextBoxStyle.transparent
        ? Stack(
            fit: StackFit.expand,
            children: [
      contentBox,
      IgnorePointer(
        child: _DashedRect(
          color: widget.item.color
              .withValues(alpha: widget.isActive ? 0.9 : 0.55),
          strokeWidth: 2,
          dashLength: 6,
          gap: 4,
          borderRadius: borderRadius,
          child: const SizedBox.expand(),
        ),
      ),
            ],
          )
        : Container(
            width: _currentSize.width,
            height: _currentSize.height,
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              border: Border.all(
                color: widget.item.color,
                width:
                    widget.item.boxStyle == MarkupTextBoxStyle.thinBorder ? 2 : 4,
              ),
            ),
            child: contentBox,
          );

    final Widget removeButton = IconButton(
      onPressed: widget.onRemove,
      icon: const Icon(Icons.close, size: 16),
      style: IconButton.styleFrom(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        minimumSize: const Size(28, 28),
        padding: EdgeInsets.zero,
      ),
    );

    final Widget resizeHandle = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: _onResizeStart,
      onPanUpdate: _onResizeUpdate,
      onPanEnd: (_) => _resizeStartSize = null,
      child: _ResizeHandle(color: scheme.primary),
    );

    return Positioned(
      left: _currentOffset.dx,
      top: _currentOffset.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.onTap,
        onDoubleTap: widget.onRequestEdit,
        onPanStart: widget.isEditing ? null : _onDragStart,
        onPanUpdate: widget.isEditing ? null : _onDragUpdate,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            borderedBox,
            Positioned(
              top: -12,
              right: -12,
              child: removeButton,
            ),
            Positioned(
              bottom: -12,
              right: -12,
              child: resizeHandle,
            ),
          ],
        ),
      ),
    );
  }

  void _handleFocusChange() {
    if (!widget.focusNode.hasFocus) {
      widget.onFocusLost();
    }
  }

  void _onDragStart(DragStartDetails details) {
    widget.onTap();
    _currentOffset = widget.item.position;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final proposed = _currentOffset + details.delta;
    final clamped = _clampOffset(proposed, _currentSize, widget.canvasSize);
    if (clamped == _currentOffset) return;
    setState(() => _currentOffset = clamped);
    widget.onPositionChanged(clamped);
  }

  void _onResizeStart(DragStartDetails details) {
    _resizeStartSize = _currentSize;
  }

  void _onResizeUpdate(DragUpdateDetails details) {
    final startSize = _resizeStartSize ?? _currentSize;
    final maxWidth = widget.canvasSize.width - _currentOffset.dx;
    final maxHeight = widget.canvasSize.height - _currentOffset.dy;
    final newWidth =
        (startSize.width + details.delta.dx).clamp(_minSize.width, maxWidth);
    final newHeight =
        (startSize.height + details.delta.dy).clamp(_minSize.height, maxHeight);
    final newSize = Size(newWidth, newHeight);
    if (newSize == _currentSize) return;
    setState(() => _currentSize = newSize);
    widget.onSizeChanged(newSize);
    final clampedOffset = _clampOffset(_currentOffset, newSize, widget.canvasSize);
    if (clampedOffset != _currentOffset) {
      setState(() => _currentOffset = clampedOffset);
      widget.onPositionChanged(clampedOffset);
    }
  }

  EdgeInsets _paddingForStyle(MarkupTextBoxStyle style) {
    switch (style) {
      case MarkupTextBoxStyle.transparent:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 10);
      case MarkupTextBoxStyle.thinBorder:
      case MarkupTextBoxStyle.thickBorder:
        return const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
    }
  }

  Offset _clampOffset(Offset offset, Size boxSize, Size canvasSize) {
    final dx = offset.dx.clamp(
      0.0,
      math.max(0.0, canvasSize.width - boxSize.width),
    ).toDouble();
    final dy = offset.dy.clamp(
      0.0,
      math.max(0.0, canvasSize.height - boxSize.height),
    ).toDouble();
    return Offset(dx, dy);
  }
}

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(
        Icons.open_with_rounded,
        size: 16,
        color: Colors.white,
      ),
    );
  }
}

class _DashedRect extends StatelessWidget {
  const _DashedRect({
    required this.color,
    required this.child,
    required this.strokeWidth,
    required this.dashLength,
    required this.gap,
    required this.borderRadius,
  });

  final Color color;
  final Widget child;
  final double strokeWidth;
  final double dashLength;
  final double gap;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(
        color: color,
        strokeWidth: strokeWidth,
        dashLength: dashLength,
        gap: gap,
        borderRadius: borderRadius,
      ),
      child: child,
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  const _DashedRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashLength,
    required this.gap,
    required this.borderRadius,
  });

  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gap;
  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rectPath =
        Path()..addRRect(borderRadius.toRRect(Rect.fromLTWH(0, 0, size.width, size.height)));
    final dashedPath = Path();

    for (final metric in rectPath.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashLength;
        dashedPath.addPath(
          metric.extractPath(distance, math.min(next, metric.length)),
          Offset.zero,
        );
        distance = next + gap;
      }
    }

    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.gap != gap ||
        oldDelegate.borderRadius != borderRadius;
  }
}

String _fontLabel(MarkupFontFamily family) {
  switch (family) {
    case MarkupFontFamily.sansSerif:
      return '고딕';
    case MarkupFontFamily.serif:
      return '명조';
    case MarkupFontFamily.monospace:
      return '모노';
  }
}

String _boxStyleLabel(MarkupTextBoxStyle style) {
  switch (style) {
    case MarkupTextBoxStyle.transparent:
      return '투명';
    case MarkupTextBoxStyle.thinBorder:
      return '가는 줄';
    case MarkupTextBoxStyle.thickBorder:
      return '굵은 줄';
  }
}

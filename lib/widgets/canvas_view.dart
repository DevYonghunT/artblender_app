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

    return Stack(
      children: [
        // 1. 마크업할 원본 이미지
        Image.file(
          provider.imageForMarkup!,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
        ),
        // 2. 사용자가 그리는 마크업 선
        GestureDetector(
          onPanStart: (details) => provider.startMarkup(details.localPosition),
          onPanUpdate: (details) => provider.updateMarkup(details.localPosition),
          onPanEnd: (details) => provider.endMarkup(),
          child: CustomPaint(
            painter: MarkupPainter(points: provider.markupPoints),
            child: Container(),
          ),
        ),
        // 3. 마크업 관련 버튼
        Positioned(
          bottom: 80,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 취소 버튼 (마크업을 버리고 이전 화면으로 돌아갑니다)
              FloatingActionButton(
                heroTag: 'cancel_markup',
                onPressed: () => provider.cancelMarkup(),
                backgroundColor: Colors.red,
                child: const Icon(Icons.close, color: Colors.white),
              ),
              const SizedBox(width: 20),
              // 마크업 확정 버튼
              FloatingActionButton.extended(
                heroTag: 'confirm_markup',
                onPressed: () => provider.confirmMarkup(),
                backgroundColor: Colors.green,
                icon: const Icon(Icons.check, color: Colors.white),
                label: const Text('마크업 확정', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- 기존 카메라 미리보기 UI ---
  Widget buildCameraPreview(BuildContext context, CanvasProvider provider) {
    final cameraController = provider.cameraController;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(fit: StackFit.expand, children: [
      CameraPreview(cameraController),
      if (provider.cutoutImage != null)
        Opacity(opacity: 0.7, child: Image.memory(provider.cutoutImage!, fit: BoxFit.contain)),
      Positioned(bottom: 80, left: 0, right: 0, child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        FloatingActionButton(heroTag: 'cancel_capture', onPressed: () => provider.cancelBackgroundPicking(), backgroundColor: Colors.white, child: const Icon(Icons.close, color: Colors.black)),
        FloatingActionButton(heroTag: 'take_picture', onPressed: () => provider.captureBackground(), backgroundColor: Colors.white, child: const Icon(Icons.camera_alt, color: Colors.black)),
      ]))
    ]);
  }

  // --- 기존 그리기 UI ---
  Widget buildDrawingCanvas(BuildContext context, CanvasProvider provider) {
    return Stack(
      children: [
        Image.file(provider.drawableImage!, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
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
            child: Container(),
          ),
        ),
        Positioned(bottom: 80, left: 0, right: 0, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (provider.points.isNotEmpty || provider.startPoint != null)
            FloatingActionButton(heroTag: 'undo_button', onPressed: () => provider.undo(), backgroundColor: Colors.white, child: const Icon(Icons.undo, color: Colors.black)),
          const SizedBox(width: 20),
          if (provider.points.isNotEmpty || provider.startPoint != null)
            FloatingActionButton(heroTag: 'clear_button', onPressed: () => provider.clearDrawing(), backgroundColor: Colors.red, child: const Icon(Icons.delete, color: Colors.white)),
          const SizedBox(width: 20),
          if ((provider.shapeType != ShapeType.freeform && provider.startPoint != null) || (provider.shapeType == ShapeType.freeform && provider.isPathClosed))
            FloatingActionButton.extended(heroTag: 'confirm_button', onPressed: () => provider.confirmCutout(context), backgroundColor: Colors.green, icon: const Icon(Icons.check, color: Colors.white), label: const Text('없애기', style: TextStyle(color: Colors.white))),
        ])),
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
        alignment: Alignment.center,
        children: [
          // backgroundImage는 File 타입이므로 Image.file을 사용합니다.
          if (backgroundImage != null)
            Image.file(
              backgroundImage,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
            )
          else
            Container(color: Colors.grey[300]),

          if (cutoutImage != null)
            InteractiveViewer(
              boundaryMargin: const EdgeInsets.all(double.infinity),
              minScale: 0.1,
              maxScale: 4.0,
              child: Image.memory(
                cutoutImage,
                fit: BoxFit.contain,
              ),
            ),
        ],
      ),
    );
  }
}

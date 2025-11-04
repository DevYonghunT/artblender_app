import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:camera/camera.dart';
import '../providers/canvas_provider.dart';
import 'drawing_painter.dart';
import 'shape_selection_panel.dart';

class CanvasView extends StatelessWidget {
  final ScreenshotController controller;

  const CanvasView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Consumer<CanvasProvider>(
      builder: (context, provider, child) {
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

  // --- 오려낸 이미지와 배경을 합성해서 보여주는 캔버스 UI (수정됨) ---
  Widget buildCompositeCanvas(BuildContext context, CanvasProvider provider) {
    final cutoutImage = provider.cutoutImage;
    final backgroundImage = provider.backgroundImage;

    return Screenshot(
      controller: controller,
      child: Stack(
        // 자식 위젯들을 중앙에 정렬합니다.
        alignment: Alignment.center,
        children: [
          // 1. 배경 이미지: 이제 cutout과 동일하게 BoxFit.contain을 사용합니다.
          if (backgroundImage != null)
            Image.memory( // File -> memory로 변경
              backgroundImage,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
            )
          else
            // 배경이 없을 때는 회색 컨테이너를 전체에 표시
            Container(color: Colors.grey[300]),

          // 2. 오려낸 이미지: 배경 선택 후에도 InteractiveViewer를 유지합니다.
          if (cutoutImage != null)
            InteractiveViewer(
              boundaryMargin: const EdgeInsets.all(double.infinity),
              minScale: 0.1,
              maxScale: 4.0,
              child: Image.memory(
                cutoutImage,
                fit: BoxFit.contain, // 배경과 동일한 BoxFit
              ),
            ),
        ],
      ),
    );
  }
  
  // --- 기존 카메라 및 그리기 UI (변경 없음) ---
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
}

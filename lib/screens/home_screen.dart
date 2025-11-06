import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/canvas_provider.dart';
import '../widgets/canvas_view.dart';
import '../widgets/control_panel.dart';
import 'package:screenshot/screenshot.dart';

class HomeScreen extends StatelessWidget {
  final ScreenshotController screenshotController = ScreenshotController();

  HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Consumer를 사용하여 로딩 상태 변경 시에만 오버레이를 다시 그리도록 합니다.
      body: Consumer<CanvasProvider>(
        builder: (context, provider, child) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // 로딩 상태와 관계없는 기본 UI (child로 전달됨)
              child!,

              // 로딩 오버레이
              IgnorePointer(
                ignoring: !provider.isLoading,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: provider.isLoading ? 1.0 : 0.0,
                  child: Container(
                    color: Colors.black.withAlpha(128), // withOpacity 경고 해결
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 20),
                          Text(
                            '처리 중입니다...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        // 이 부분은 로딩 상태가 변경되어도 다시 빌드되지 않습니다.
        child: Stack(
          children: [
            CanvasView(controller: screenshotController),
            Consumer<CanvasProvider>(
              builder: (context, provider, _) {
                // if 문에 중괄호를 추가하여 경고를 해결합니다.
                if (!provider.isMarkingUp &&
                    provider.drawableImage == null &&
                    !provider.isPickingSubject &&
                    !provider.isPickingBackground) {
                  return ControlPanel(
                    onLoadDrawing: () => provider.loadDrawing(),
                    onLoadBackground: () => provider.startBackgroundPicking(),
                    onSave: () => provider.saveResult(screenshotController),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }
}

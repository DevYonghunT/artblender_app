import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/canvas_provider.dart';
import '../widgets/canvas_view.dart';
import '../widgets/control_panel.dart';
import 'package:screenshot/screenshot.dart';


class HomeScreen extends StatelessWidget {
  final ScreenshotController screenshotController = ScreenshotController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<CanvasProvider>( // '두뇌'를 구독
        builder: (context, provider, child) {
          return Stack(
            children: [
              // 5. 캔버스 영역 (합성된 이미지 표시)
              CanvasView(
                controller: screenshotController,
                backgroundImage: provider.backgroundImage,
                cutoutImage: provider.cutoutImage,
              ),

              // 5. 버튼 영역
              ControlPanel(
                onLoadDrawing: () => provider.loadDrawing(),
                onLoadBackground: () => provider.loadBackground(),
                onSave: () => provider.saveResult(screenshotController),
              ),

              // 로딩 중일 때 로딩 스피너 표시
              if (provider.isLoading)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          );
        },
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'dart:io';
// import 'dart:ui' as ui; // (필요 없음)
import 'package:flutter/services.dart'; // Uint8List를 위해 추가

class CanvasView extends StatelessWidget {
  final ScreenshotController controller;
  final File? backgroundImage;
  // ▼▼▼ [수정 1] 받는 이미지 타입을 Uint8List? 로 변경 ▼▼▼
  final Uint8List? cutoutImage;

  const CanvasView({
    super.key,
    required this.controller,
    required this.backgroundImage,
    required this.cutoutImage,
  });

  @override
  Widget build(BuildContext context) {
    return Screenshot(
      controller: controller,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 배경 이미지
          if (backgroundImage != null)
            Image.file(
              backgroundImage!,
              fit: BoxFit.cover,
            )
          else
          // 배경이 없을 때 기본 화면 (예: 회색)
            Container(color: Colors.grey[300]),

          // ▼▼▼ [수정 2] cutoutImage가 있을 때 Icon이 아닌 Image.memory()로 표시 ▼▼▼
          if (cutoutImage != null)
            InteractiveViewer(
              boundaryMargin: EdgeInsets.all(double.infinity),
              minScale: 0.1,
              maxScale: 4.0,
              child: Image.memory(
                cutoutImage!, // Uint8List 데이터를 바로 이미지로 표시
              ),
            ),
          // ▲▲▲ 여기까지 ▲▲▲
        ],
      ),
    );
  }
}
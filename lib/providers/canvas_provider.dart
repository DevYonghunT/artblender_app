import 'package:flutter/material.dart';
// import 'package:screenshot/screenshot.dart'; // 1. 불필요한 import 삭제
import 'dart:io';
// import 'dart:ui' as ui; // 2. Uint8List를 사용할 것이므로 삭제
import 'package:flutter/services.dart'; // 3. Uint8List를 위해 추가

// 4. 서비스 클래스들 임포트 (중복 제거)
import '../services/image_service.dart';
import '../services/segmentation_service.dart';
import '../services/save_service.dart';
// (중복된 import 3줄 삭제)

import 'package:screenshot/screenshot.dart'; // saveResult 타입을 위해 추가

class CanvasProvider extends ChangeNotifier {
  // 1. 서비스 도구들 준비
  final ImageService _imageService = ImageService();
  final SegmentationService _segmentationService = SegmentationService();
  final SaveService _saveService = SaveService();

  // 2. 앱의 핵심 상태 (데이터)
  File? _backgroundImage; // 배경 사진
  // ▼▼▼ [수정 1] 이미지 타입을 ui.Image? -> Uint8List? 로 변경 ▼▼▼
  Uint8List? _cutoutImageBytes; // 오려낸 그림 (배경 투명)
  // ▲▲▲ 여기까지 ▲▲▲
  bool _isLoading = false; // 로딩 중인지 여부

  // 3. UI가 사용할 getter (읽기 전용)
  File? get backgroundImage => _backgroundImage;
  // ▼▼▼ [수정 2] getter 이름은 'cutoutImage'로 유지, 반환값만 변경 ▼▼▼
  Uint8List? get cutoutImage => _cutoutImageBytes;
  // ▲▲▲ 여기까지 ▲▲▲
  bool get isLoading => _isLoading;

  // 4. UI가 호출할 기능 (메소드)

  // 그림 가져오기 및 오려내기
  Future<void> loadDrawing() async {
    _setLoading(true);
    // 1. 카메라로 그림 촬영 (서비스 호출)
    final File? originalImage = await _imageService.getImageFromCamera();
    if (originalImage == null) {
      _setLoading(false);
      return;
    }

    // ▼▼▼ [수정 3] 함수 이름을 getCutoutImage -> getCutoutImageBytes 로 변경 ▼▼▼
    _cutoutImageBytes =
    await _segmentationService.getCutoutImageBytes(originalImage);
    // ▲▲▲ 여기까지 ▲▲▲
    _setLoading(false);
  }

  // 배경 가져오기
  Future<void> loadBackground() async {
    _setLoading(true);
    _backgroundImage = await _imageService.getImageFromCamera();
    _setLoading(false);
  }

  // 결과물 저장하기
  // ▼▼▼ [수정 4] controller의 타입을 명확하게 지정 ▼▼▼
  Future<void> saveResult(ScreenshotController controller) async {
    // ▲▲▲ 여기까지 ▲▲▲
    _setLoading(true);
    await _saveService.saveCompositeImage(controller);
    _setLoading(false);
    // (저장 완료 토스트 메시지 등 표시)
  }

  // 상태 변경 및 UI에 알림
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners(); // 이 함수가 호출되면 UI가 새로고침됩니다.
  }
}
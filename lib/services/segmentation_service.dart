import 'dart:io';
import 'dart:ui' as ui; // ui.Image를 사용하기 위해 필요
import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart';
import 'package:flutter/services.dart'; // Uint8List를 위해 필요

class SegmentationService {
  // ▼▼▼ [수정] v0.0.2에 맞는 생성자로 변경 ▼▼▼
  // mode, enableRawSizeMask 등 모든 파라미터를 제거합니다.
  final SubjectSegmenter _segmenter = SubjectSegmenter();
  // ▲▲▲ 여기까지 ▲▲▲

  Future<Uint8List?> getCutoutImageBytes(File imageFile) async {
    final InputImage inputImage = InputImage.fromFile(imageFile);

    // v0.0.2의 올바른 클래스 이름 (SubjectSegmentationMask)
    final SubjectSegmentationMask mask = await _segmenter.processImage(inputImage);

    final ui.Image cutoutImage = await mask.toUiImage(
      imageFile.readAsBytesSync(),
      backgroundColor: ui.Color(0x00000000), // 완전 투명
    );

    _segmenter.close(); // 자원 해제

    final ByteData? byteData = await cutoutImage.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }
}


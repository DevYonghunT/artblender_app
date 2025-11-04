import 'dart:io';
import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SegmentationService {
  SubjectSegmenter? _segmenter;

  // Segmenter 초기화 (lazy initialization)
  Future<void> _initializeSegmenter() async {
    if (_segmenter != null) return;

    _segmenter = SubjectSegmenter(
      options: SubjectSegmenterOptions(
        enableForegroundConfidenceMask: false,
        enableForegroundBitmap: true,
        enableMultipleSubjects: SubjectResultOptions(
          enableConfidenceMask: false,
          enableSubjectBitmap: false,
        ),
      ),
    );
  }

  Future<Uint8List?> getCutoutImageBytes(File imageFile) async {
    try {
      // Segmenter 초기화
      await _initializeSegmenter();

      if (_segmenter == null) {
        debugPrint('Segmenter initialization failed');
        return null;
      }

      final InputImage inputImage = InputImage.fromFile(imageFile);

      // processImage로 결과 받기
      final SubjectSegmentationResult result = await _segmenter!.processImage(inputImage);

      // foregroundBitmap은 이미 Uint8List? 타입
      final Uint8List? foregroundBytes = result.foregroundBitmap;

      if (foregroundBytes == null) {
        debugPrint('Foreground bitmap is null');
        return null;
      }

      return foregroundBytes;
    } on PlatformException catch (e) {
      debugPrint('PlatformException in segmentation: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Error in segmentation: $e');
      return null;
    }
  }

  // 서비스 종료 시 리소스 해제
  Future<void> dispose() async {
    if (_segmenter != null) {
      await _segmenter!.close();
      _segmenter = null;
    }
  }
}
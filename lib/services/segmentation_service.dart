import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart';

class SegmentationService {
  Future<Uint8List?> getCutoutImageBytes(File imageFile) async {
    final InputImage inputImage = InputImage.fromFile(imageFile);
    final subjectSegmenter = SubjectSegmenter(
      options: SubjectSegmenterOptions(
        enableForegroundBitmap: true,
        enableForegroundConfidenceMask: false,
        enableMultipleSubjects: SubjectResultOptions(
          enableConfidenceMask: false,
          enableSubjectBitmap: true,
        ),
      ),
    );

    try {
      final SubjectSegmentationResult result =
          await subjectSegmenter.processImage(inputImage);

      if (result.foregroundBitmap != null) {
        return result.foregroundBitmap;
      }

      if (result.subjects.isNotEmpty) {
        return result.subjects.first.bitmap;
      }

      return null;
    } finally {
      await subjectSegmenter.close();
    }
  }
}

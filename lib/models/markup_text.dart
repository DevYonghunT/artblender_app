import 'package:flutter/material.dart';

enum MarkupFontFamily { sansSerif, serif, monospace }
enum MarkupTextBoxStyle { transparent, thinBorder, thickBorder }

class MarkupTextItem {
  const MarkupTextItem({
    required this.id,
    required this.text,
    required this.position,
    required this.boxSize,
    required this.fontSize,
    required this.fontFamily,
    required this.isBold,
    required this.isItalic,
    required this.isUnderline,
    required this.boxStyle,
    required this.color,
  });

  final String id;
  final String text;
  final Offset position;
  final Size boxSize;
  final double fontSize;
  final MarkupFontFamily fontFamily;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final MarkupTextBoxStyle boxStyle;
  final Color color;

  MarkupTextItem copyWith({
    String? text,
    Offset? position,
    Size? boxSize,
    double? fontSize,
    MarkupFontFamily? fontFamily,
    bool? isBold,
    bool? isItalic,
    bool? isUnderline,
    MarkupTextBoxStyle? boxStyle,
    Color? color,
  }) {
    return MarkupTextItem(
      id: id,
      text: text ?? this.text,
      position: position ?? this.position,
      boxSize: boxSize ?? this.boxSize,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      isUnderline: isUnderline ?? this.isUnderline,
      boxStyle: boxStyle ?? this.boxStyle,
      color: color ?? this.color,
    );
  }

  TextStyle buildTextStyle() {
    final fontFamilyName = switch (fontFamily) {
      MarkupFontFamily.sansSerif => 'sans-serif',
      MarkupFontFamily.serif => 'serif',
      MarkupFontFamily.monospace => 'monospace',
    };

    FontWeight weight = FontWeight.normal;
    if (isBold) weight = FontWeight.w600;

    return TextStyle(
      fontFamily: fontFamilyName,
      fontSize: fontSize,
      fontWeight: weight,
      fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
      decoration: isUnderline ? TextDecoration.underline : TextDecoration.none,
      color: color,
      overflow: TextOverflow.visible,
    );
  }
}

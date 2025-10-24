import 'package:flutter/material.dart';

class ControlPanel extends StatelessWidget {
  final VoidCallback onLoadDrawing;
  final VoidCallback onLoadBackground;
  final VoidCallback onSave;

  // ▼▼▼ [수정 1] 'key' 생성자 경고 해결 (super parameter 사용) ▼▼▼
  const ControlPanel({
    super.key, // 'Key? key' 대신 'super.key'를 사용
    required this.onLoadDrawing,
    required this.onLoadBackground,
    required this.onSave,
  }); // ': super(key: key)' 부분이 여기서 합쳐졌습니다.
  // ▲▲▲ 여기까지 ▲▲▲

  @override
  Widget build(BuildContext context) {
    // 화면 하단에 버튼들을 배치합니다.
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          // ▼▼▼ [수정 2] 'withOpacity' 경고 해결 ▼▼▼
          color: Colors.black54, // Colors.black.withOpacity(0.5) 대신
          // ▲▲▲ 여기까지 ▲▲▲
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 1. 그림 불러오기 버튼
            IconButton(
              icon: Icon(Icons.draw, color: Colors.white, size: 30),
              onPressed: onLoadDrawing,
              tooltip: '그림 촬영', // 'Typo' 경고는 무시해도 됩니다.
            ),
            // 2. 배경 불러오기 버튼
            IconButton(
              icon: Icon(Icons.landscape, color: Colors.white, size: 30),
              onPressed: onLoadBackground,
              tooltip: '배경 촬영', // 'Typo' 경고는 무시해도 됩니다.
            ),
            // 3. 저장하기 버튼
            IconButton(
              icon: Icon(Icons.save_alt, color: Colors.white, size: 30),
              onPressed: onSave,
              tooltip: '저장하기', // 'Typo' 경고는 무시해도 됩니다.
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/canvas_provider.dart';

class ShapeSelectionPanel extends StatelessWidget {
  const ShapeSelectionPanel({super.key});

  @override
  Widget build(BuildContext context) {

    return Positioned(
      top: 60, // 화면 상단에 배치
      left: 0,
      right: 0,
      child: Center(
        // Consumer를 사용하여 shapeType이 변경될 때만 이 부분을 다시 그리도록 최적화
        child: Consumer<CanvasProvider>(
          builder: (context, provider, child) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildShapeButton(context, provider, ShapeType.freeform, Icons.edit),
                  const SizedBox(width: 10),
                  _buildShapeButton(context, provider, ShapeType.rectangle, Icons.crop_square),
                  const SizedBox(width: 10),
                  _buildShapeButton(context, provider, ShapeType.circle, Icons.circle_outlined),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // 각 도형 선택 버튼을 만드는 헬퍼 위젯
  Widget _buildShapeButton(BuildContext context, CanvasProvider provider, ShapeType type, IconData icon) {
    final bool isSelected = provider.shapeType == type;
    return IconButton(
      onPressed: () => provider.setShapeType(type),
      icon: Icon(
        icon,
        color: isSelected ? Colors.lightBlueAccent : Colors.white,
        size: 30,
      ),
    );
  }
}

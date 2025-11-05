import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/canvas_provider.dart';

class ShapeSelectionPanel extends StatelessWidget {
  const ShapeSelectionPanel({super.key});

  @override
  Widget build(BuildContext context) {
    // provider의 상태를 읽기만 하므로 listen: false
    // final provider = context.read<CanvasProvider>(); // 사용되지 않는 변수이므로 삭제

    return Positioned(
      top: 60, // 화면 상단에 배치
      left: 0,
      right: 0,
      child: Center(
        child: Consumer<CanvasProvider>(
          builder: (context, provider, child) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                // withOpacity -> withAlpha로 수정
                color: Colors.black.withAlpha(128), // 0.5 opacity = 128 alpha
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

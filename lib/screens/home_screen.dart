import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/canvas_provider.dart';
import '../widgets/canvas_view.dart';
import '../widgets/control_panel.dart';

class HomeScreen extends StatelessWidget {
  final GlobalKey _canvasKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<CanvasProvider>(
        builder: (context, provider, child) {
          return Stack(
            children: [
              CanvasView(
                repaintBoundaryKey: _canvasKey,
                backgroundImage: provider.backgroundImage,
                cutoutImage: provider.cutoutImage,
              ),
              ControlPanel(
                onLoadDrawing: () => provider.loadDrawing(),
                onLoadBackground: () => provider.loadBackground(),
                onSave: () => provider.saveResult(_canvasKey),
              ),
              if (provider.isLoading)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          );
        },
      ),
    );
  }
}

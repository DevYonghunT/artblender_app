import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/canvas_provider.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(
    // 1. 앱의 최상위에 '두뇌'를 등록합니다.
    ChangeNotifierProvider(
      create: (context) => CanvasProvider(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Art Creator',
      home: HomeScreen(), // 2. 실제 첫 화면을 보여줍니다.
    );
  }
}
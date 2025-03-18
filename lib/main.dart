import 'package:flutter/material.dart';
import 'home.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(

        ),
        body: Center(
          child: HomePage(
            title: 'My Custom Widget',
            description: 'This is a custom widget with tap interaction. Tap to expand/collapse!',
          ),
        ),
      ),
    );
  }
}
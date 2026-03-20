import 'package:flutter/material.dart';

class StepPlaceholderScreen extends StatelessWidget {
  const StepPlaceholderScreen({super.key, required this.title, this.message});

  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(message ?? '$title implementation starts next.', textAlign: TextAlign.center),
      ),
    );
  }
}

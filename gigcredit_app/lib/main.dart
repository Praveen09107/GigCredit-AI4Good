import 'package:flutter/material.dart';

void main() {
  runApp(const GigCreditApp());
}

class GigCreditApp extends StatelessWidget {
  const GigCreditApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GigCredit',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const _PlaceholderHome(),
    );
  }
}

class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('GigCredit app skeleton — wire routing & state next.'),
      ),
    );
  }
}


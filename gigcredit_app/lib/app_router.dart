import 'package:flutter/material.dart';

/// Minimal placeholder router; will be replaced with GoRouter or similar.
class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    // TODO: implement full routing according to planning docs.
    return MaterialPageRoute(
      builder: (_) => const Scaffold(
        body: Center(child: Text('GigCredit route placeholder')),
      ),
    );
  }
}


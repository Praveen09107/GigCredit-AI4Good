import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_router.dart';

void main() {
  runApp(const ProviderScope(child: GigCreditApp()));
}

class GigCreditApp extends StatelessWidget {
  const GigCreditApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GigCredit',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E88E5)),
        useMaterial3: true,
      ),
      initialRoute: AppRouter.initialRoute,
      onGenerateRoute: AppRouter.routeFactory,
    );
  }
}


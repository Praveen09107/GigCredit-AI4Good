import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app/theme.dart';
import 'app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }
  runApp(const ProviderScope(child: GigCreditApp()));
}

class GigCreditApp extends StatelessWidget {
  const GigCreditApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GigCredit',
      debugShowCheckedModeBanner: false,
      theme: GigTheme.themeData,
      initialRoute: AppRouter.initialRoute,
      onGenerateRoute: AppRouter.routeFactory,
    );
  }
}


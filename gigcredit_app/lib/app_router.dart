import 'package:flutter/material.dart';

import 'ui/scoring_workbench_screen.dart';
import 'ui/startup_self_check_gate.dart';

class AppRouter {
  static const String home = '/';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
      default:
        return MaterialPageRoute<void>(
          settings: const RouteSettings(name: home),
          builder: (_) => const StartupSelfCheckGate(
            child: ScoringWorkbenchScreen(),
          ),
        );
    }
  }

  static RouteFactory get routeFactory => onGenerateRoute;

  static String get initialRoute => home;
}


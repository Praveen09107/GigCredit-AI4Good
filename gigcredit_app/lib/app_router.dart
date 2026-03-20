import 'package:flutter/material.dart';

import 'ui/screens/final_report_screen.dart';
import 'ui/screens/guidelines_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/otp_verification_screen.dart';
import 'ui/screens/report_loading_screen.dart';
import 'ui/screens/steps/step1_profile_screen.dart';
import 'ui/screens/steps/step2_kyc_screen.dart';
import 'ui/screens/steps/step3_bank_screen.dart';
import 'ui/screens/steps/step4_utilities_screen.dart';
import 'ui/screens/steps/step5_work_proof_screen.dart';
import 'ui/screens/steps/step6_schemes_screen.dart';
import 'ui/screens/steps/step7_insurance_screen.dart';
import 'ui/screens/steps/step8_itr_gst_screen.dart';
import 'ui/screens/steps/step9_emi_loan_screen.dart';
import 'ui/startup_self_check_gate.dart';

class AppRouter {
  static const String home = '/';
  static const String login = '/login';
  static const String otp = '/otp';
  static const String reportLoading = '/reportLoading';
  static const String report = '/report';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case otp:
        final args = settings.arguments as OtpRouteArgs;
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => OtpVerificationScreen(args: args),
        );
      case reportLoading:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const ReportLoadingScreen(),
        );
      case report:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const FinalReportScreen(),
        );
      case home:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (ctx) => HomeScreen(
            onContinue: () {
              Navigator.push(
                ctx,
                MaterialPageRoute(
                  builder: (ctx) => Step1ProfileScreen(
                    onContinue: () {
                      Navigator.push(
                        ctx,
                        MaterialPageRoute(
                          builder: (ctx) => Step2KycScreen(
                            onContinue: () {
                              Navigator.push(
                                ctx,
                                MaterialPageRoute(
                                  builder: (ctx) => Step3BankScreen(
                                    onContinue: () {
                                      Navigator.push(
                                        ctx,
                                        MaterialPageRoute(
                                          builder: (ctx) => Step4UtilitiesScreen(
                                            onContinue: () {
                                              Navigator.push(
                                                ctx,
                                                MaterialPageRoute(
                                                  builder: (ctx) => Step5WorkProofScreen(
                                                    onContinue: () {
                                                      Navigator.push(
                                                        ctx,
                                                        MaterialPageRoute(
                                                          builder: (ctx) => Step6SchemesScreen(
                                                            onContinue: () {
                                                              Navigator.push(
                                                                ctx,
                                                                MaterialPageRoute(
                                                                  builder: (ctx) => Step7InsuranceScreen(
                                                                    onContinue: () {
                                                                      Navigator.push(
                                                                        ctx,
                                                                        MaterialPageRoute(
                                                                          builder: (ctx) => Step8ItrGstScreen(
                                                                            onContinue: () {
                                                                              Navigator.push(
                                                                                ctx,
                                                                                MaterialPageRoute(
                                                                                  builder: (ctx) => Step9EmiLoanScreen(
                                                                                    onFinish: () {
                                                                                      Navigator.pushNamed(ctx, AppRouter.reportLoading);
                                                                                    },
                                                                                  ),
                                                                                ),
                                                                              );
                                                                            },
                                                                          ),
                                                                        ),
                                                                      );
                                                                    },
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
            onGuidelines: () {
              Navigator.push(
                ctx,
                MaterialPageRoute(
                  builder: (_) => GuidelinesScreen(
                    onProceed: () => Navigator.pop(ctx),
                  ),
                ),
              );
            },
          ),
        );
      case login:
      default:
        return MaterialPageRoute<void>(
          settings: const RouteSettings(name: login),
          builder: (_) => const StartupSelfCheckGate(
            child: LoginScreen(),
          ),
        );
    }
  }

  static RouteFactory get routeFactory => onGenerateRoute;
  static String get initialRoute => login;
}

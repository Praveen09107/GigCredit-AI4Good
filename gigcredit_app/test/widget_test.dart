import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gigcredit_app/app/theme.dart';
import 'package:gigcredit_app/ui/screens/steps/step1_profile_screen.dart';

void main() {
  testWidgets('Step1ProfileScreen layout does not overflow on small screens', (WidgetTester tester) async {
    // Set a very small screen size (e.g. older Android / iPhone SE equivalent)
    tester.view.physicalSize = const Size(1080, 1920); // physical pixels
    tester.view.devicePixelRatio = 3.0; // logical resolution 360 x 640

    // Important: We listen to FlutterError to fail the test if a layout overflow happens.
    final List<FlutterErrorDetails> errors = [];
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exceptionAsString().contains('RenderFlex overflowed')) {
        errors.add(details);
      }
      originalOnError?.call(details);
    };

    // Pump the app into Step 1
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: GigTheme.themeData,
          home: Scaffold(
            body: Step1ProfileScreen(
              onContinue: () {},
            ),
          ),
        ),
      ),
    );

    // Give it a moment to layout and render
    await tester.pumpAndSettle();

    // Verify there are no RenderFlex overflow errors!
    expect(errors, isEmpty, reason: 'Found RenderFlex overflow errors in Step 1 Profile layout!');

    // Verify StepProgressHeader is visible 
    expect(find.text('Progress: Step 1 of 9'), findsOneWidget);

    // Verify the Dropdowns are present
    expect(find.text('State of Residence'), findsOneWidget);
    expect(find.text('Work Type'), findsOneWidget);

    // Restore the error handler
    FlutterError.onError = originalOnError;
    
    // Reset view bounds cleanly
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

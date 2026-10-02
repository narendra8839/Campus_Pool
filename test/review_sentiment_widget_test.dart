import 'package:campus_pool/components/buttons/app_secondary_button.dart';
import 'package:campus_pool/screens/reviews/post_ride_review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sentiment analysis is optional and enabled for a draft comment', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: PostRideReviewScreen(
          rideId: 'ride-1',
          revieweeId: 'user-1',
          revieweeName: 'Alex',
        ),
      ),
    );

    final analyzeButton = find.widgetWithText(
      AppSecondaryButton,
      'Analyze review',
    );
    expect(analyzeButton, findsOneWidget);
    expect(find.textContaining('Optional tone suggestion'), findsOneWidget);
    expect(find.text('Positive tone'), findsNothing);
    expect(
      tester.widget<AppSecondaryButton>(analyzeButton).onPressed,
      isNull,
    );

    await tester.enterText(
      find.byType(TextFormField),
      'The ride was comfortable and the driver was friendly.',
    );
    await tester.pump();

    expect(
      tester.widget<AppSecondaryButton>(analyzeButton).onPressed,
      isNotNull,
    );
    expect(find.text('Positive tone'), findsNothing);
  });
}

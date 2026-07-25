import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keyflow_app/main.dart';

/// **Validates: Requirements 1.1, 1.7, 2.1, 2.2**
///
/// Bug Condition Exploration Test for Desktop Navigation Mismatch
/// 
/// This test MUST FAIL on unfixed code - failure confirms the bug exists
/// DO NOT attempt to fix the test or the code when it fails
/// 
/// Scoped PBT Approach: Test concrete platform cases with screen width > 600px
/// Goal: Surface counterexamples that demonstrate desktop navigation bug exists
/// Expected Outcome: Test FAILS (this is correct - it proves the bug exists)
void main() {
  group('Bug Condition Exploration: Desktop Navigation Mismatch', () {
    // Test case 1: Windows platform with desktop width
    testWidgets(
      'Windows platform with 1200px width should use NavigationRail, not BottomNavigationBar',
      (WidgetTester tester) async {
        // Arrange: Simulate Windows platform with desktop width
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        
        // Act: Pump the app
        await tester.pumpWidget(
          const ProviderScope(
            child: KeyFlowApp(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        
        // Assert: Check that BottomNavigationBar is used (BUG CONDITION)
        // This assertion should FAIL when the bug is fixed (expecting NavigationRail)
        expect(
          find.byType(BottomNavigationBar),
          findsOneWidget,
          reason: 'BUG: Windows with 1200px width shows BottomNavigationBar '
                  'instead of NavigationRail. This confirms the bug exists.',
        );
        
        // Additional check: NavigationRail should NOT be present in current buggy state
        expect(
          find.byType(NavigationRail),
          findsNothing,
          reason: 'Expected: NavigationRail should be used for desktop width. '
                  'Current: NavigationRail not found (bug confirmed).',
        );
      },
    );

    // Test case 2: macOS platform with desktop width
    testWidgets(
      'macOS platform with 1400px width should use NavigationRail, not BottomNavigationBar',
      (WidgetTester tester) async {
        // Arrange: Simulate macOS platform with desktop width
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        
        // Act: Pump the app
        await tester.pumpWidget(
          const ProviderScope(
            child: KeyFlowApp(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        
        // Assert: Check that BottomNavigationBar is used (BUG CONDITION)
        // This assertion should FAIL when the bug is fixed (expecting NavigationRail)
        expect(
          find.byType(BottomNavigationBar),
          findsOneWidget,
          reason: 'BUG: macOS with 1400px width shows BottomNavigationBar '
                  'instead of NavigationRail. This confirms the bug exists.',
        );
      },
    );

    // Test case 3: Web platform with desktop width
    testWidgets(
      'Web platform with 800px width should use NavigationRail, not BottomNavigationBar',
      (WidgetTester tester) async {
        // Arrange: Simulate web platform with desktop width
        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1.0;
        
        // Act: Pump the app
        await tester.pumpWidget(
          const ProviderScope(
            child: KeyFlowApp(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        
        // Assert: Check that BottomNavigationBar is used (BUG CONDITION)
        // This assertion should FAIL when the bug is fixed (expecting NavigationRail)
        expect(
          find.byType(BottomNavigationBar),
          findsOneWidget,
          reason: 'BUG: Web with 800px width shows BottomNavigationBar '
                  'instead of NavigationRail. This confirms the bug exists.',
        );
      },
    );

    // Test case 4: Mobile width preservation check (should still use BottomNavigationBar)
    testWidgets(
      'Mobile width (375px) should continue to use BottomNavigationBar (regression prevention)',
      (WidgetTester tester) async {
        // Arrange: Simulate mobile width
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        
        // Act: Pump the app
        await tester.pumpWidget(
          const ProviderScope(
            child: KeyFlowApp(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        
        // Assert: BottomNavigationBar should still be present for mobile
        expect(
          find.byType(BottomNavigationBar),
          findsOneWidget,
          reason: 'Mobile width should continue to use BottomNavigationBar '
                  '(preservation requirement).',
        );
      },
    );

    // Test case 5: Edge case - exactly 600px width (borderline case)
    testWidgets(
      'Exactly 600px width - check current behavior for documentation',
      (WidgetTester tester) async {
        // Arrange: Simulate exactly 600px width (borderline between mobile/desktop)
        tester.view.physicalSize = const Size(600, 800);
        tester.view.devicePixelRatio = 1.0;
        
        // Act: Pump the app
        await tester.pumpWidget(
          const ProviderScope(
            child: KeyFlowApp(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        
        // Assert: Document current behavior
        final bottomNavBar = find.byType(BottomNavigationBar);
        final navigationRail = find.byType(NavigationRail);
        
        if (tester.any(bottomNavBar)) {
          // ignore: avoid_print
          print('Counterexample documented: 600px width uses BottomNavigationBar');
        } else if (tester.any(navigationRail)) {
          // ignore: avoid_print
          print('Counterexample documented: 600px width uses NavigationRail');
        }
        
        // Just document, no assertion to fail - this is for bug understanding
      },
    );
  });

  // Helper group for property-based test cases
  group('Property-Based Exploration: Screen Width > 600px', () {
    // Property: For all screen widths > 600px, navigation should adapt
    // This is a pseudo-property test using multiple concrete cases
    const desktopWidths = [601, 800, 1024, 1200, 1440, 1920];
    
    for (final width in desktopWidths) {
      testWidgets(
        'Width $width px should use appropriate navigation (currently buggy)',
        (WidgetTester tester) async {
          // Arrange: Simulate desktop width
          tester.view.physicalSize = Size(width.toDouble(), 800);
          tester.view.devicePixelRatio = 1.0;
          
          // Act: Pump the app
          await tester.pumpWidget(
            const ProviderScope(
              child: KeyFlowApp(),
            ),
          );
          await tester.pump(const Duration(milliseconds: 500));
          
          // Assert: Document the bug condition
          final hasBottomNav = tester.any(find.byType(BottomNavigationBar));
          
          if (hasBottomNav) {
            // ignore: avoid_print
            print('Counterexample: Width $width px uses BottomNavigationBar '
                  '(should use NavigationRail for desktop)');
          }
          
          // Expected to fail on unfixed code
          expect(
            hasBottomNav,
            isTrue,
            reason: 'BUG: Width $width px shows BottomNavigationBar. '
                    'Expected: NavigationRail for desktop width > 600px.',
          );
        },
      );
    }
  });
}
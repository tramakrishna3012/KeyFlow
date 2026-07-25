# Implementation Plan

## Overview

This implementation plan follows the bugfix workflow for cross-platform UI fixes. It includes exploration tests to surface bug counterexamples, preservation tests to ensure mobile behavior remains unchanged, implementation of fixes for navigation, layout, accessibility, and scroll issues, and verification tasks to confirm the fix works correctly without regressions.

The plan addresses 5 bug categories with corresponding exploration tests and preservation tests, followed by a comprehensive implementation phase with verification steps.

## Tasks

### Bug Condition Exploration Tests (MUST RUN BEFORE FIX)

- [-] 1. Write bug condition exploration test
  - **Property 1: Bug Condition** - Desktop Navigation Mismatch
  - **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bug exists
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior - it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples that demonstrate desktop navigation bug exists
  - **Scoped PBT Approach**: Test concrete platform cases: Windows/macOS/web with screen width > 600px
  - Test implementation details from Bug Condition in design (C(navigation) platform detection logic)
  - The test assertions should match the Expected Behavior Properties from design (NavigationRail for desktop)
  - Run test on UNFIXED code
  - **EXPECTED OUTCOME**: Test FAILS (this is correct - it proves the bug exists)
  - Document counterexamples found to understand root cause (e.g., "Windows with 1200px width shows BottomNavigationBar instead of NavigationRail")
  - Mark task complete when test is written, run, and failure is documented
  - _Requirements: 1.1, 1.7, 2.1, 2.2_

- [~] 2. Write bug condition exploration test for content width constraints
  - **Property 1: Bug Condition** - Unconstrained Content Width
  - **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bug exists
  - **DO NOT attempt to fix the test or the code when it fails**
  - **GOAL**: Surface counterexamples that demonstrate content width constraint bug exists
  - **Scoped PBT Approach**: Test screen widths > 1000px with various content layouts
  - Test implementation details from Bug Condition in design (C(contentWidth) width detection)
  - The test assertions should match the Expected Behavior Properties from design (max-width: 720px, centered)
  - Run test on UNFIXED code
  - **EXPECTED OUTCOME**: Test FAILS (this is correct - it proves the bug exists)
  - Document counterexamples found (e.g., "1440px width shows content stretching edge-to-edge without constraints")
  - Mark task complete when test is written, run, and failure is documented
  - _Requirements: 1.2, 2.3_

- [~] 3. Write bug condition exploration test for grid responsiveness
  - **Property 1: Bug Condition** - Fixed Grid Layouts
  - **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bug exists
  - **DO NOT attempt to fix the test or the code when it fails**
  - **GOAL**: Surface counterexamples that demonstrate grid responsiveness bugs exist
  - **Scoped PBT Approach**: Test dashboard grid (screen width > 600px) and emoji grid (screen width < 480px)
  - Test implementation details from Bug Condition in design (C(dashboardGrid) and C(emojiGrid))
  - The test assertions should match the Expected Behavior Properties from design (dashboard: 3+ columns, emoji: 4 columns with 48px+ cells)
  - Run test on UNFIXED code
  - **EXPECTED OUTCOME**: Test FAILS (this is correct - it proves the bug exists)
  - Document counterexamples found (e.g., "800px width dashboard shows 2 columns instead of 3", "320px width emoji grid has <48px cells")
  - Mark task complete when test is written, run, and failure is documented
  - _Requirements: 1.3, 1.4, 1.8, 2.4, 2.5_

- [~] 4. Write bug condition exploration test for accessibility violations
  - **Property 1: Bug Condition** - Undersized Tap Targets
  - **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bug exists
  - **DO NOT attempt to fix the test or the code when it fails**
  - **GOAL**: Surface counterexamples that demonstrate accessibility violations exist
  - **Scoped PBT Approach**: Test copy buttons, "see all" links, delete icons for size measurements
  - Test implementation details from Bug Condition in design (C(tapTargets))
  - The test assertions should match the Expected Behavior Properties from design (minimum 48×48dp tap targets)
  - Run test on UNFIXED code
  - **EXPECTED OUTCOME**: Test FAILS (this is correct - it proves the bug exists)
  - Document counterexamples found (e.g., "Copy button tap target measures 36px", "Delete icon measures 44px")
  - Mark task complete when test is written, run, and failure is documented
  - _Requirements: 1.5, 2.6_

- [~] 5. Write bug condition exploration test for onboarding scroll capability
  - **Property 1: Bug Condition** - Onboarding Overflow
  - **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bug exists
  - **DO NOT attempt to fix the test or the code when it fails**
  - **GOAL**: Surface counterexamples that demonstrate onboarding scroll bug exists
  - **Scoped PBT Approach**: Test viewport heights < 600px with onboarding content
  - Test implementation details from Bug Condition in design (C(onboardingScroll))
  - The test assertions should match the Expected Behavior Properties from design (SingleChildScrollView present)
  - Run test on UNFIXED code
  - **EXPECTED OUTCOME**: Test FAILS (this is correct - it proves the bug exists)
  - Document counterexamples found (e.g., "400px height onboarding screen overflows without scroll")
  - Mark task complete when test is written, run, and failure is documented
  - _Requirements: 1.6, 2.7_

### Preservation Property Tests (MUST RUN BEFORE FIX)

- [~] 6. Write preservation property tests (BEFORE implementing fix)
  - **Property 2: Preservation** - Mobile Navigation Consistency
  - **IMPORTANT**: Follow observation-first methodology
  - Observe behavior on UNFIXED code for mobile screens (< 600px width)
  - Write property-based tests capturing observed behavior patterns from Preservation Requirements
  - Property-based testing generates many test cases for stronger guarantees
  - Run tests on UNFIXED code
  - **EXPECTED OUTCOME**: Tests PASS (this confirms baseline behavior to preserve)
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.1_

- [~] 7. Write preservation property tests for mobile content layout
  - **Property 2: Preservation** - Mobile Content Layout Consistency
  - **IMPORTANT**: Follow observation-first methodology
  - Observe behavior on UNFIXED code for mobile screens (< 600px width)
  - Write property-based tests capturing observed full-width content layout from Preservation Requirements
  - Property-based testing generates many test cases for stronger guarantees
  - Run tests on UNFIXED code
  - **EXPECTED OUTCOME**: Tests PASS (this confirms baseline behavior to preserve)
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.2_

- [~] 8. Write preservation property tests for mobile grid behavior
  - **Property 2: Preservation** - Mobile Grid Consistency
  - **IMPORTANT**: Follow observation-first methodology
  - Observe behavior on UNFIXED code: dashboard grid (2 columns < 600px), emoji grid (6 columns 400-600px)
  - Write property-based tests capturing observed grid behavior from Preservation Requirements
  - Property-based testing generates many test cases for stronger guarantees
  - Run tests on UNFIXED code
  - **EXPECTED OUTCOME**: Tests PASS (this confirms baseline behavior to preserve)
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.3, 3.4_

- [~] 9. Write preservation property tests for visual feedback
  - **Property 2: Preservation** - Visual Feedback Consistency
  - **IMPORTANT**: Follow observation-first methodology
  - Observe visual feedback (30% opacity on press, 100% on release) on UNFIXED code for properly sized tap targets
  - Write property-based tests capturing observed visual feedback behavior from Preservation Requirements
  - Property-based testing generates many test cases for stronger guarantees
  - Run tests on UNFIXED code
  - **EXPECTED OUTCOME**: Tests PASS (this confirms baseline behavior to preserve)
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.5_

- [~] 10. Write preservation property tests for onboarding layout
  - **Property 2: Preservation** - Onboarding Layout Consistency
  - **IMPORTANT**: Follow observation-first methodology
  - Observe vertical centering behavior on UNFIXED code for viewport heights > 600px
  - Write property-based tests capturing observed layout behavior from Preservation Requirements
  - Property-based testing generates many test cases for stronger guarantees
  - Run tests on UNFIXED code
  - **EXPECTED OUTCOME**: Tests PASS (this confirms baseline behavior to preserve)
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.6_

### Implementation Phase

- [ ] 11. Fix for cross-platform UI/UX issues

  - [~] 11.1 Implement platform-aware navigation fix
    - Add platform detection logic using Platform.isWindows, Platform.isMacOS, Platform.isLinux
    - Add screen width detection using MediaQuery.of(context).size.width
    - Implement breakpoint logic: < 600px = mobile, ≥ 600px = desktop
    - Conditional navigation rendering: BottomNavigationBar for mobile, NavigationRail for desktop
    - Implement expanded/collapsed NavigationRail states based on width (600-800px collapsed, >800px expanded)
    - _Bug_Condition: isBugCondition(platform, screenWidth, "navigation") from design_
    - _Expected_Behavior: NavigationRail for desktop platforms and wide screens from design_
    - _Preservation: BottomNavigationBar continues for screens < 600px width_
    - _Requirements: 1.1, 1.7, 2.1, 2.2, 3.1_

  - [~] 11.2 Implement content width constraint fix
    - Add max-width constraints for wide screens (> 1000px)
    - Wrap content in ConstrainedBox with maxWidth: 720 for wide screens
    - Center content horizontally with Center widget
    - Maintain full-width behavior for mobile screens (< 600px)
    - _Bug_Condition: isBugCondition(platform, screenWidth, "contentWidth") from design_
    - _Expected_Behavior: Content centered with max-width 720px for screens > 1000px_
    - _Preservation: Full-width content layout continues for screens < 600px_
    - _Requirements: 1.2, 2.3, 3.2_

  - [~] 11.3 Implement responsive grid layout fixes
    - Dashboard grid: 2 cols (< 600px), 3 cols (600-900px), 4 cols (> 900px)
    - Emoji grid: 4 cols (< 480px), 5 cols (480-720px), 6 cols (> 720px)
    - Preserve 6-col behavior in 400-600px range for emoji grid
    - Ensure emoji cells maintain minimum 48px size on narrow screens
    - _Bug_Condition: isBugCondition(platform, screenWidth, "dashboardGrid") and isBugCondition(platform, screenWidth, "emojiGrid") from design_
    - _Expected_Behavior: Adaptive column counts based on screen width breakpoints_
    - _Preservation: 2-column dashboard and 6-column emoji grid preserved in respective ranges_
    - _Requirements: 1.3, 1.4, 1.8, 2.4, 2.5, 3.3, 3.4_

  - [~] 11.4 Implement accessibility compliance fix for tap targets
    - Copy buttons: add vertical padding ≥12px to achieve 48dp minimum
    - "See all" links: convert to TextButton with proper sizing
    - Delete icons: wrap in IconButton with 44-48px size
    - Use MaterialTapTargetSize.padded where applicable
    - Ensure all interactive elements provide minimum 48×48dp tap targets
    - _Bug_Condition: isBugCondition(platform, screenWidth, "tapTargets") from design_
    - _Expected_Behavior: Minimum 48×48dp tap targets for all interactive elements_
    - _Preservation: Visual feedback (30% opacity) continues for properly sized elements_
    - _Requirements: 1.5, 2.6, 3.5_

  - [~] 11.5 Implement onboarding scroll capability fix
    - Wrap onboarding content in SingleChildScrollView
    - Maintain vertical centering for tall viewports (> 600px)
    - Use Column with MainAxisAlignment.center when appropriate
    - Ensure scroll capability prevents content overflow
    - _Bug_Condition: isBugCondition(platform, screenHeight, "onboardingScroll") from design_
    - _Expected_Behavior: Scroll capability via SingleChildScrollView for all viewport conditions_
    - _Preservation: Vertical centering preserved for viewports > 600px within 2% tolerance_
    - _Requirements: 1.6, 2.7, 3.6_

  - [~] 11.6 Implement error handling and fallback logic
    - Add try-catch around responsive calculations
    - Fall back to mobile layout (< 600px assumptions) on any error
    - Log errors using debugPrint or logging service
    - Ensure graceful degradation for layout calculation failures
    - _Bug_Condition: isBugCondition(platform, screenWidth, "error") from design_
    - _Expected_Behavior: Fallback to mobile layout on calculation errors_
    - _Preservation: Error handling doesn't affect normal mobile layout behavior_
    - _Requirements: 2.8_

  - [~] 11.7 Verify bug condition exploration test for navigation now passes
    - **Property 1: Expected Behavior** - Desktop Navigation Correctness
    - **IMPORTANT**: Re-run the SAME test from task 1 - do NOT write a new test
    - The test from task 1 encodes the expected behavior
    - When this test passes, it confirms the expected behavior is satisfied
    - Run bug condition exploration test from step 1
    - **EXPECTED OUTCOME**: Test PASSES (confirms desktop navigation bug is fixed)
    - _Requirements: Expected Behavior Properties from design_

  - [~] 11.8 Verify content width constraint test now passes
    - **Property 1: Expected Behavior** - Content Width Constraints
    - **IMPORTANT**: Re-run the SAME test from task 2 - do NOT write a new test
    - Run content width constraint test from step 2
    - **EXPECTED OUTCOME**: Test PASSES (confirms content width bug is fixed)
    - _Requirements: Expected Behavior Properties from design_

  - [~] 11.9 Verify grid responsiveness test now passes
    - **Property 1: Expected Behavior** - Grid Responsiveness
    - **IMPORTANT**: Re-run the SAME test from task 3 - do NOT write a new test
    - Run grid responsiveness test from step 3
    - **EXPECTED OUTCOME**: Test PASSES (confirms grid responsiveness bugs are fixed)
    - _Requirements: Expected Behavior Properties from design_

  - [~] 11.10 Verify accessibility compliance test now passes
    - **Property 1: Expected Behavior** - Tap Target Accessibility
    - **IMPORTANT**: Re-run the SAME test from task 4 - do NOT write a new test
    - Run accessibility compliance test from step 4
    - **EXPECTED OUTCOME**: Test PASSES (confirms accessibility violations are fixed)
    - _Requirements: Expected Behavior Properties from design_

  - [~] 11.11 Verify onboarding scroll test now passes
    - **Property 1: Expected Behavior** - Onboarding Scroll Capability
    - **IMPORTANT**: Re-run the SAME test from task 5 - do NOT write a new test
    - Run onboarding scroll test from step 5
    - **EXPECTED OUTCOME**: Test PASSES (confirms onboarding scroll bug is fixed)
    - _Requirements: Expected Behavior Properties from design_

  - [~] 11.12 Verify preservation tests still pass
    - **Property 2: Preservation** - Mobile Navigation Consistency
    - **IMPORTANT**: Re-run the SAME tests from tasks 6-10 - do NOT write new tests
    - Run preservation tests from steps 6-10
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions)
    - Confirm all preservation tests still pass after fix (no regressions)
    - _Requirements: Preservation Requirements from design_

### Verification Phase

- [~] 12. Checkpoint - Ensure all tests pass
  - Ensure all exploration tests pass (tasks 1-5 rerun)
  - Ensure all preservation tests pass (tasks 6-10 rerun)
  - Verify visual regression tests for mobile layouts pass (screenshot comparisons)
  - Confirm error handling fallback works correctly
  - Ask the user if questions arise during final validation

## Task Dependency Graph

```json
{
  "tasks": [
    {
      "id": "1",
      "name": "Desktop Navigation Exploration Test",
      "type": "exploration",
      "dependencies": [],
      "testBehavior": "MUST_FAIL_UNFIXED",
      "phase": "bug_discovery"
    },
    {
      "id": "2",
      "name": "Content Width Exploration Test",
      "type": "exploration",
      "dependencies": ["1"],
      "testBehavior": "MUST_FAIL_UNFIXED",
      "phase": "bug_discovery"
    },
    {
      "id": "3",
      "name": "Grid Responsiveness Exploration Test",
      "type": "exploration",
      "dependencies": ["2"],
      "testBehavior": "MUST_FAIL_UNFIXED",
      "phase": "bug_discovery"
    },
    {
      "id": "4",
      "name": "Accessibility Exploration Test",
      "type": "exploration",
      "dependencies": ["3"],
      "testBehavior": "MUST_FAIL_UNFIXED",
      "phase": "bug_discovery"
    },
    {
      "id": "5",
      "name": "Onboarding Scroll Exploration Test",
      "type": "exploration",
      "dependencies": ["4"],
      "testBehavior": "MUST_FAIL_UNFIXED",
      "phase": "bug_discovery"
    },
    {
      "id": "6",
      "name": "Mobile Navigation Preservation Test",
      "type": "preservation",
      "dependencies": [],
      "testBehavior": "MUST_PASS_UNFIXED",
      "phase": "baseline_establishment"
    },
    {
      "id": "7",
      "name": "Mobile Content Preservation Test",
      "type": "preservation",
      "dependencies": ["6"],
      "testBehavior": "MUST_PASS_UNFIXED",
      "phase": "baseline_establishment"
    },
    {
      "id": "8",
      "name": "Mobile Grid Preservation Test",
      "type": "preservation",
      "dependencies": ["7"],
      "testBehavior": "MUST_PASS_UNFIXED",
      "phase": "baseline_establishment"
    },
    {
      "id": "9",
      "name": "Visual Feedback Preservation Test",
      "type": "preservation",
      "dependencies": ["8"],
      "testBehavior": "MUST_PASS_UNFIXED",
      "phase": "baseline_establishment"
    },
    {
      "id": "10",
      "name": "Onboarding Layout Preservation Test",
      "type": "preservation",
      "dependencies": ["9"],
      "testBehavior": "MUST_PASS_UNFIXED",
      "phase": "baseline_establishment"
    },
    {
      "id": "11",
      "name": "Implementation (parent)",
      "type": "implementation",
      "dependencies": ["5", "10"],
      "subTasks": [
        {
          "id": "11.1",
          "name": "Platform-aware navigation fix",
          "dependencies": [],
          "fixes": ["1"]
        },
        {
          "id": "11.2",
          "name": "Content width constraint fix",
          "dependencies": [],
          "fixes": ["2"]
        },
        {
          "id": "11.3",
          "name": "Responsive grid layout fixes",
          "dependencies": [],
          "fixes": ["3"]
        },
        {
          "id": "11.4",
          "name": "Accessibility compliance fix",
          "dependencies": [],
          "fixes": ["4"]
        },
        {
          "id": "11.5",
          "name": "Onboarding scroll capability fix",
          "dependencies": [],
          "fixes": ["5"]
        },
        {
          "id": "11.6",
          "name": "Error handling and fallback logic",
          "dependencies": [],
          "fixes": []
        },
        {
          "id": "11.7",
          "name": "Verify navigation test passes",
          "dependencies": ["11.1"],
          "validates": ["1"]
        },
        {
          "id": "11.8",
          "name": "Verify content width test passes",
          "dependencies": ["11.2"],
          "validates": ["2"]
        },
        {
          "id": "11.9",
          "name": "Verify grid test passes",
          "dependencies": ["11.3"],
          "validates": ["3"]
        },
        {
          "id": "11.10",
          "name": "Verify accessibility test passes",
          "dependencies": ["11.4"],
          "validates": ["4"]
        },
        {
          "id": "11.11",
          "name": "Verify onboarding test passes",
          "dependencies": ["11.5"],
          "validates": ["5"]
        },
        {
          "id": "11.12",
          "name": "Verify preservation tests still pass",
          "dependencies": ["11.1", "11.2", "11.3", "11.4", "11.5", "11.6"],
          "validates": ["6", "7", "8", "9", "10"]
        }
      ]
    },
    {
      "id": "12",
      "name": "Checkpoint - Ensure all tests pass",
      "type": "verification",
      "dependencies": ["11.7", "11.8", "11.9", "11.10", "11.11", "11.12"],
      "phase": "final_validation"
    }
  ],
  "waves": [
    {
      "name": "Bug Discovery Wave",
      "tasks": ["1", "2", "3", "4", "5"],
      "description": "Run exploration tests on unfixed code to confirm bugs exist"
    },
    {
      "name": "Baseline Establishment Wave",
      "tasks": ["6", "7", "8", "9", "10"],
      "description": "Run preservation tests on unfixed code to establish mobile behavior baseline"
    },
    {
      "name": "Implementation Wave",
      "tasks": ["11.1", "11.2", "11.3", "11.4", "11.5", "11.6"],
      "description": "Implement fixes for each bug category with error handling"
    },
    {
      "name": "Verification Wave",
      "tasks": ["11.7", "11.8", "11.9", "11.10", "11.11", "11.12"],
      "description": "Verify fixes work and no regressions introduced"
    },
    {
      "name": "Final Validation Wave",
      "tasks": ["12"],
      "description": "Final checkpoint ensuring all tests pass"
    }
  ],
  "criticalPaths": [
    {
      "path": ["1 → 11.7 → 12"],
      "description": "Desktop navigation bug discovery → fix → verification"
    },
    {
      "path": ["6 → 11.12 → 12"],
      "description": "Mobile preservation baseline → full preservation verification → final validation"
    }
  ]
}
```

### Dependency Explanation

1. **Sequential Test Execution**: 
   - Exploration tests (tasks 1-5) should be executed in order to understand all bug conditions
   - Preservation tests (tasks 6-10) should be executed in order to establish baseline behavior

2. **Critical Test Prerequisites**:
   - All exploration tests MUST fail on unfixed code (confirms bugs exist)
   - All preservation tests MUST pass on unfixed code (establishes baseline to preserve)

3. **Implementation Dependencies**:
   - Implementation (task 11) can only begin after all exploration and preservation tests are written and their results documented
   - Each fix sub-task (11.1-11.6) addresses specific bug conditions identified in exploration tests

4. **Verification Dependencies**:
   - Each verification sub-task (11.7-11.11) depends on its corresponding fix being implemented
   - Preservation verification (11.12) depends on all fixes being implemented
   - Checkpoint (12) requires all verification tasks to pass

5. **Workflow Constraints**:
   - Exploration tests are scoped PBT focused on concrete failing cases for reproducibility
   - Preservation tests follow observation-first methodology with property-based testing for strong guarantees
   - Implementation tasks include specification references to design document
   - Verification tasks re-run the exact same tests written in exploration/preservation phases

## Notes

### Test Execution Order
1. **Phase 1 - Bug Discovery**: Run exploration tests (tasks 1-5) on UNFIXED code
   - Expected: All tests FAIL (confirms bugs exist)
   - Document counterexamples for each bug category
   
2. **Phase 2 - Baseline Establishment**: Run preservation tests (tasks 6-10) on UNFIXED code
   - Expected: All tests PASS (confirms baseline mobile behavior)
   - Document observed mobile behavior patterns
   
3. **Phase 3 - Implementation**: Implement fixes (tasks 11.1-11.6)
   - Reference design specifications and documented counterexamples
   - Each fix addresses specific bug conditions
   
4. **Phase 4 - Verification**: Re-run all tests on FIXED code (tasks 11.7-11.12)
   - Expected: Exploration tests now PASS (confirms bugs fixed)
   - Expected: Preservation tests still PASS (confirms no regressions)
   
5. **Phase 5 - Final Validation**: Run comprehensive checkpoint (task 12)
   - Ensure all tests pass
   - Validate visual regression tests
   - Confirm error handling works

### Property-Based Testing Approach
- **Exploration Tests**: Scoped to concrete failing cases for deterministic bugs
- **Preservation Tests**: Full property-based testing across mobile screen ranges
- **Key Breakpoints**: 480px, 600px, 720px, 900px, 1000px for responsive layouts
- **Platform Variations**: iOS, Android, Windows, macOS, web for navigation patterns

### Risk Management
- **Graceful Degradation**: Error handling fallback ensures mobile layout on calculation failures
- **Visual Regression**: Screenshot comparison tests for mobile layouts ensure no unintended visual changes
- **Accessibility Compliance**: Minimum 48×48dp tap targets enforced across all interactive elements
- **Cross-Platform Consistency**: Platform detection ensures appropriate UI patterns for each platform type

### Success Criteria
- All exploration tests pass on fixed code (bugs resolved)
- All preservation tests continue to pass on fixed code (no regressions)
- Navigation adapts correctly to platform and screen size
- Content respects width constraints on wide screens
- Grid layouts adapt to available screen space
- All interactive elements meet accessibility standards
- Onboarding screens scroll when needed
- Error handling provides graceful fallback to mobile layout

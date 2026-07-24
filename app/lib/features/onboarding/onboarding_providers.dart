import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers.dart';
import '../../data/sqlite_history_repository.dart';

const String kKeyOnboardingCompleted = 'onboarding_completed';

/// Check whether the user has completed the 5-screen Onboarding & Consent Flow.
final isOnboardingCompletedProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(historyRepositoryProvider);
  if (repo is SqliteHistoryRepository) {
    final val = await repo.getSetting(kKeyOnboardingCompleted);
    return val == 'true';
  }
  return false;
});

class OnboardingController extends StateNotifier<int> {
  OnboardingController(this.ref) : super(0);

  final Ref ref;

  void setStep(int step) {
    state = step;
  }

  void nextStep() {
    if (state < 4) {
      state = state + 1;
    }
  }

  void previousStep() {
    if (state > 0) {
      state = state - 1;
    }
  }

  Future<void> completeOnboarding() async {
    final repo = ref.read(historyRepositoryProvider);
    if (repo is SqliteHistoryRepository) {
      await repo.setSetting(kKeyOnboardingCompleted, 'true');
    }
    ref.invalidate(isOnboardingCompletedProvider);
  }
}

final onboardingControllerProvider = StateNotifierProvider<OnboardingController, int>(
  (ref) => OnboardingController(ref),
);

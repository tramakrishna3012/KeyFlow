import 'history_repository.dart';

class RetentionService {
  RetentionService({required this._repository});

  final HistoryRepository _repository;

  Future<int> executePurge([int retentionDays = 30]) async =>
      _repository.purgeOlderThan(retentionDays);

  Future<int> runPurge([int? retentionDays]) async {
    if (retentionDays != null) {
      return executePurge(retentionDays);
    }
    final settingStr = await _repository.getSetting('retention_days');
    final days = (settingStr != null) ? (int.tryParse(settingStr) ?? 30) : 30;
    return executePurge(days);
  }
}


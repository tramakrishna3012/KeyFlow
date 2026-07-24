import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keyflow_app/data/history_repository.dart';
import 'package:keyflow_app/data/models/history_entry.dart';
import 'package:keyflow_app/features/capture/capture_service.dart';

class MockHistoryRepository implements HistoryRepository {
  final List<HistoryEntry> entries = [];
  List<String> exclusionList = ['1password.exe', 'bitwarden.exe'];

  @override
  Future<int> addEntry(HistoryEntry entry) async {
    entries.add(entry);
    return entries.length;
  }

  @override
  Future<List<HistoryEntry>> getAllEntries() async => entries;

  @override
  Future<List<HistoryEntry>> searchEntries(String query, {String? appName}) async {
    return entries.where((e) => e.text.contains(query)).toList();
  }

  @override
  Future<HistoryEntry?> getEntry(int id) async => null;

  @override
  Future<int> deleteEntry(int id) async => 0;

  @override
  Future<int> clearAll() async {
    entries.clear();
    return 0;
  }

  @override
  Future<int> purgeOlderThan(int days) async => 0;

  @override
  Future<List<HistoryEntry>> exportAll() async => entries;

  @override
  Future<List<String>> getExclusionList() async => exclusionList;

  @override
  Future<void> addExclusion(String appIdentifier) async {
    exclusionList.add(appIdentifier);
  }

  @override
  Future<void> removeExclusion(String appIdentifier) async {
    exclusionList.remove(appIdentifier);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHistoryRepository mockRepository;
  late CaptureService captureService;
  final List<MethodCall> log = [];

  setupMethodChannelMock() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('keyflow/capture'), (MethodCall methodCall) async {
      log.add(methodCall);
      switch (methodCall.method) {
        case 'startCapture':
          return true;
        case 'stopCapture':
          return true;
        case 'pauseCapture':
          return true;
        case 'resumeCapture':
          return true;
        case 'setExclusionList':
          return true;
        case 'setAutostart':
          return true;
        case 'isAutostartEnabled':
          return true;
        default:
          return null;
      }
    });
  }

  setUp(() {
    log.clear();
    mockRepository = MockHistoryRepository();
    captureService = CaptureService(mockRepository);
    setupMethodChannelMock();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('keyflow/capture'), null);
    captureService.dispose();
  });

  test('startCapture invokes native channel and sets capturing state', () async {
    final result = await captureService.startCapture();
    expect(result, isTrue);
    expect(captureService.isCapturing, isTrue);
    expect(log.any((call) => call.method == 'startCapture'), isTrue);
  });

  test('pauseCapture and resumeCapture toggle state', () async {
    await captureService.pauseCapture();
    expect(captureService.isPaused, isTrue);

    await captureService.resumeCapture();
    expect(captureService.isPaused, isFalse);
  });

  test('syncExclusionList sends list to native channel', () async {
    await captureService.syncExclusionList(['chrome.exe', 'notepad.exe']);
    final call = log.firstWhere((c) => c.method == 'setExclusionList');
    expect(call.arguments, equals(['chrome.exe', 'notepad.exe']));
  });

  test('initialize fetches exclusion list from repository and syncs to native', () async {
    await captureService.initialize();
    final call = log.firstWhere((c) => c.method == 'setExclusionList');
    expect(call.arguments, equals(['1password.exe', 'bitwarden.exe']));
    expect(captureService.isCapturing, isTrue);
  });

  test('setAutostart and isAutostartEnabled call native channel', () async {
    final autoResult = await captureService.setAutostart(true);
    expect(autoResult, isTrue);
    expect(log.any((c) => c.method == 'setAutostart' && c.arguments == true), isTrue);

    final isAuto = await captureService.isAutostartEnabled();
    expect(isAuto, isTrue);
  });
}

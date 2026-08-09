import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pending_sale.dart';

/// Persists the queue of not-yet-synced sales across app restarts using
/// shared_preferences — a handful of JSON-encoded entries at most, so a full
/// local database (sqflite/drift/hive) would be overkill for this.
class OfflineSaleQueueNotifier extends AsyncNotifier<List<PendingSale>> {
  static const _prefsKey = 'pending_sales';

  @override
  Future<List<PendingSale>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => PendingSale.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> _persist(List<PendingSale> sales) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(sales.map((s) => s.toJson()).toList()));
    state = AsyncData(sales);
  }

  Future<void> enqueue(PendingSale sale) async {
    final current = state.valueOrNull ?? await future;
    await _persist([...current, sale]);
  }

  Future<void> remove(String clientUuid) async {
    final current = state.valueOrNull ?? await future;
    await _persist(current.where((s) => s.clientUuid != clientUuid).toList());
  }

  Future<void> markError(String clientUuid, String error) async {
    final current = state.valueOrNull ?? await future;
    await _persist([for (final s in current) s.clientUuid == clientUuid ? s.withError(error) : s]);
  }
}

final offlineSaleQueueProvider = AsyncNotifierProvider<OfflineSaleQueueNotifier, List<PendingSale>>(
  OfflineSaleQueueNotifier.new,
);

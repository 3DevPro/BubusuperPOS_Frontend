import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../checkout_screen.dart' show salesRepositoryProvider;
import '../sales_repository.dart';
import 'network_error.dart';
import 'offline_sale_queue.dart';

/// Resends queued sales in order, stopping at the first network error so the
/// rest stay queued for the next attempt. A sale rejected by the server for
/// a real reason (not a network error — rare, since it was valid when it was
/// queued) is marked with the error instead of retried forever.
class OfflineSyncService {
  OfflineSyncService(this._ref);
  final Ref _ref;

  bool _flushing = false;

  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      final salesRepo = _ref.read(salesRepositoryProvider);
      final queue = _ref.read(offlineSaleQueueProvider.notifier);
      final pending = await _ref.read(offlineSaleQueueProvider.future);

      for (final sale in pending) {
        try {
          await salesRepo.checkout(
            clientUuid: sale.clientUuid,
            items: [
              for (final i in sale.items)
                CheckoutItem(productId: i.productId, qty: i.qty, discount: Decimal.parse(i.discount)),
            ],
            discount: Decimal.parse(sale.discount),
            paymentMethod: sale.paymentMethod,
            customerId: sale.customerId,
            redeemPoints: sale.redeemPoints,
          );
          await queue.remove(sale.clientUuid);
        } on DioException catch (e) {
          if (isNetworkError(e)) return;
          final data = e.response?.data;
          final detail = (data is Map && data['detail'] != null) ? data['detail'].toString() : 'ส่งไม่สำเร็จ';
          await queue.markError(sale.clientUuid, detail);
        }
      }
    } finally {
      _flushing = false;
    }
  }
}

final offlineSyncServiceProvider = Provider<OfflineSyncService>((ref) => OfflineSyncService(ref));

/// Watched once from app root to keep this alive for the whole session: does
/// an initial flush on startup and re-flushes whenever connectivity comes
/// back, so a queued sale from a previous offline period gets sent without
/// the cashier having to do anything.
final offlineSyncInitProvider = Provider<void>((ref) {
  final service = ref.watch(offlineSyncServiceProvider);
  // Best-effort: a failure here (e.g. the connectivity plugin being
  // unavailable, as in widget tests) shouldn't crash app startup — the
  // connectivity listener below and the manual retry button are the other
  // two paths that trigger a flush.
  service.flush().catchError((_) {});
  final subscription = Connectivity().onConnectivityChanged.listen((results) {
    if (results.any((r) => r != ConnectivityResult.none)) service.flush();
  }, onError: (_) {});
  ref.onDispose(subscription.cancel);
});

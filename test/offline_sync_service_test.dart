import 'package:app/features/pos/checkout_screen.dart' show salesRepositoryProvider;
import 'package:app/features/pos/offline/offline_sale_queue.dart';
import 'package:app/features/pos/offline/offline_sync_service.dart';
import 'package:app/features/pos/offline/pending_sale.dart';
import 'package:app/features/pos/sales_repository.dart';
import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSalesRepository implements SalesRepository {
  _FakeSalesRepository(this._checkout);
  final Future<SaleResultDto> Function(String clientUuid) _checkout;

  @override
  Future<SaleResultDto> checkout({
    required String clientUuid,
    required List<CheckoutItem> items,
    required Decimal discount,
    required String paymentMethod,
    String? customerId,
    int redeemPoints = 0,
  }) => _checkout(clientUuid);

  @override
  Future<List<SaleListItemDto>> list({DateTime? startDate, DateTime? endDate}) => throw UnimplementedError();

  @override
  Future<SaleResultDto> get(String id) => throw UnimplementedError();

  @override
  Future<RefundResultDto> refund({
    required String saleId,
    required String clientUuid,
    List<RefundItemRequest>? items,
    String? reason,
  }) => throw UnimplementedError();
}

SaleResultDto _dummyResult() => SaleResultDto(
  id: 's1',
  receiptNo: 'R1',
  customerId: null,
  subtotal: Decimal.zero,
  discount: Decimal.zero,
  tax: Decimal.zero,
  priceIncludesTax: true,
  total: Decimal.zero,
  pointsEarned: 0,
  pointsRedeemed: 0,
  pointsDiscount: Decimal.zero,
  paymentMethod: 'cash',
  status: 'completed',
  refundedTotal: Decimal.zero,
  createdAt: DateTime(2026, 1, 1),
  items: const [],
  refunds: const [],
  warnings: const [],
);

PendingSale _sale(String clientUuid) => PendingSale(
  clientUuid: clientUuid,
  items: const [PendingSaleItem(productId: 'p1', qty: 2)],
  discount: '0',
  paymentMethod: 'cash',
  createdAt: DateTime(2026, 1, 1),
);

ProviderContainer _buildContainer(Future<SaleResultDto> Function(String) checkout) {
  return ProviderContainer(overrides: [salesRepositoryProvider.overrideWithValue(_FakeSalesRepository(checkout))]);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('a network error leaves the sale queued for a later retry', () async {
    final container = _buildContainer((_) async {
      throw DioException(
        requestOptions: RequestOptions(path: '/api/v1/sales'),
        type: DioExceptionType.connectionError,
      );
    });
    addTearDown(container.dispose);
    await container.read(offlineSaleQueueProvider.notifier).enqueue(_sale('a'));

    await container.read(offlineSyncServiceProvider).flush();

    final result = await container.read(offlineSaleQueueProvider.future);
    expect(result, hasLength(1));
    expect(result.single.lastError, isNull);
  });

  test('a successful resend removes the sale from the queue', () async {
    final container = _buildContainer((_) async => _dummyResult());
    addTearDown(container.dispose);
    await container.read(offlineSaleQueueProvider.notifier).enqueue(_sale('a'));

    await container.read(offlineSyncServiceProvider).flush();

    final result = await container.read(offlineSaleQueueProvider.future);
    expect(result, isEmpty);
  });

  test('a real server rejection is recorded as an error, not silently dropped', () async {
    final container = _buildContainer((_) async {
      throw DioException(
        requestOptions: RequestOptions(path: '/api/v1/sales'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/api/v1/sales'),
          statusCode: 422,
          data: {'detail': 'สินค้าไม่พอ'},
        ),
      );
    });
    addTearDown(container.dispose);
    await container.read(offlineSaleQueueProvider.notifier).enqueue(_sale('a'));

    await container.read(offlineSyncServiceProvider).flush();

    final result = await container.read(offlineSaleQueueProvider.future);
    expect(result, hasLength(1));
    expect(result.single.lastError, 'สินค้าไม่พอ');
  });
}

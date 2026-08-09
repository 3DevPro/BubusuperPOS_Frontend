import 'package:app/features/pos/offline/offline_sale_queue.dart';
import 'package:app/features/pos/offline/pending_sale.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

PendingSale _sale(String clientUuid) => PendingSale(
  clientUuid: clientUuid,
  items: const [PendingSaleItem(productId: 'p1', qty: 2)],
  discount: '0',
  paymentMethod: 'cash',
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('enqueue then readAll round-trips through persistence', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(offlineSaleQueueProvider.notifier).enqueue(_sale('a'));
    final result = await container.read(offlineSaleQueueProvider.future);

    expect(result, hasLength(1));
    expect(result.single.clientUuid, 'a');
  });

  test('queue survives a fresh container (simulates an app restart)', () async {
    final container1 = ProviderContainer();
    await container1.read(offlineSaleQueueProvider.notifier).enqueue(_sale('a'));
    container1.dispose();

    final container2 = ProviderContainer();
    addTearDown(container2.dispose);
    final result = await container2.read(offlineSaleQueueProvider.future);

    expect(result, hasLength(1));
    expect(result.single.clientUuid, 'a');
  });

  test('remove drops only the matching entry', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(offlineSaleQueueProvider.notifier);
    await notifier.enqueue(_sale('a'));
    await notifier.enqueue(_sale('b'));

    await notifier.remove('a');
    final result = await container.read(offlineSaleQueueProvider.future);

    expect(result, hasLength(1));
    expect(result.single.clientUuid, 'b');
  });

  test('markError sets lastError without removing the entry', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(offlineSaleQueueProvider.notifier);
    await notifier.enqueue(_sale('a'));

    await notifier.markError('a', 'สินค้าไม่พอ');
    final result = await container.read(offlineSaleQueueProvider.future);

    expect(result, hasLength(1));
    expect(result.single.lastError, 'สินค้าไม่พอ');
  });
}

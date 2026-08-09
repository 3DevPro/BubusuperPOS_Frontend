import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/main.dart';

void main() {
  // flutter_secure_storage has no platform implementation in the widget-test
  // sandbox, so an unmocked call hangs forever rather than erroring — which
  // stalls AuthController's session restore and leaves the app parked on
  // whatever screen redirect left it on. Mock the channel so `read()`
  // resolves immediately (as if no session were stored).
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('app boots to the login screen when logged out', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: LoyverseCloneApp()));
    await tester.pumpAndSettle();

    expect(find.text('เข้าสู่ระบบร้านค้า'), findsOneWidget);
  });
}

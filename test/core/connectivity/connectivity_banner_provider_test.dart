import 'package:deen_companion/core/connectivity/domain/connectivity_state.dart';
import 'package:deen_companion/core/connectivity/presentation/providers/connectivity_banner_provider.dart';
import 'package:deen_companion/core/connectivity/presentation/providers/connectivity_providers.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '_connectivity_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void run(
    void Function(FakeAsync async, ProviderContainer c, FakeProbe probe) body, {
    bool interfaceUp = true,
  }) {
    fakeAsync((async) {
      final source = FakeConnectivitySource(up: interfaceUp);
      final probe = FakeProbe();
      final c = connectivityContainer(source, probe);
      c.listen(connectivityProvider, (_, _) {});
      c.listen(connectivityBannerProvider, (_, _) {});
      async.flushMicrotasks();
      body(async, c, probe);
      c.dispose();
      source.dispose();
    });
  }

  ConnectivityBannerState banner(ProviderContainer c) =>
      c.read(connectivityBannerProvider);

  /// Takes the app offline the way a failing backend does.
  void goOffline(FakeAsync async, ProviderContainer c, FakeProbe probe) {
    probe.reachable = false;
    final n = c.read(connectivityProvider.notifier);
    n.reportUnreachable();
    n.reportUnreachable();
    async.flushMicrotasks();
  }

  test('nothing shows while online', () {
    run((async, c, _) => expect(banner(c).kind, BannerKind.hidden));
  });

  test('offline shows the notice, with the reason', () {
    run((async, c, probe) {
      goOffline(async, c, probe);

      expect(banner(c).kind, BannerKind.offline);
      expect(banner(c).reason, OfflineReason.unreachable);
    });
  });

  test('a phone that starts offline shows the notice from the start', () {
    run((async, c, _) {
      async.elapse(ConnectivityNotifier.offlineDelay);
      expect(banner(c).kind, BannerKind.offline);
      expect(banner(c).reason, OfflineReason.noInterface);
    }, interfaceUp: false);
  });

  test('coming back shows "restored" briefly, then hides', () {
    run((async, c, probe) {
      goOffline(async, c, probe);
      c.read(connectivityProvider.notifier).reportReachable();

      expect(banner(c).kind, BannerKind.restored);

      async.elapse(
        ConnectivityBannerNotifier.restoredFor -
            const Duration(milliseconds: 1),
      );
      expect(banner(c).kind, BannerKind.restored);

      async.elapse(const Duration(milliseconds: 1));
      expect(banner(c).kind, BannerKind.hidden);
    });
  });

  test('going offline again cancels the pending hide', () {
    run((async, c, probe) {
      goOffline(async, c, probe);
      c.read(connectivityProvider.notifier).reportReachable();
      async.elapse(const Duration(seconds: 1));

      goOffline(async, c, probe);
      expect(banner(c).kind, BannerKind.offline);

      async.elapse(const Duration(seconds: 5));
      expect(
        banner(c).kind,
        BannerKind.offline,
        reason: 'not hidden by a stale timer',
      );
    });
  });

  test('a check in progress is shown', () {
    run((async, c, probe) {
      goOffline(async, c, probe);
      probe.hold = null;
      probe.reachable = false;
      c.read(connectivityProvider.notifier).recheck();

      expect(banner(c).isChecking, isTrue);
      async.flushMicrotasks();
      expect(banner(c).isChecking, isFalse);
    });
  });
}

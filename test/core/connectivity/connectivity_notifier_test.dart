import 'dart:async';

import 'package:deen_companion/core/connectivity/domain/connectivity_state.dart';
import 'package:deen_companion/core/connectivity/presentation/providers/connectivity_providers.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '_connectivity_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Runs [body] with the notifier alive and time under the test's control.
  void run(
    void Function(
      FakeAsync async,
      ProviderContainer container,
      FakeConnectivitySource source,
      FakeProbe probe,
    )
    body, {
    bool interfaceUp = true,
    bool backendReachable = true,
  }) {
    fakeAsync((async) {
      final source = FakeConnectivitySource(up: interfaceUp);
      final probe = FakeProbe(reachable: backendReachable);
      // `DateTime.now()` ignores fake time, so the notifier reads a clock
      // that follows it.
      final container = connectivityContainer(
        source,
        probe,
        now: () => async.getClock(DateTime(2026, 1, 1)).now(),
      );
      // Keep the notifier alive, as the app does.
      container.listen(connectivityProvider, (_, _) {});
      async.flushMicrotasks();
      body(async, container, source, probe);
      container.dispose();
      source.dispose();
    });
  }

  ConnectivityState stateOf(ProviderContainer c) =>
      c.read(connectivityProvider);
  int restored(ProviderContainer c) => c.read(connectionRestoredProvider);

  group('starting out', () {
    test('is online until there is a reason to say otherwise', () {
      run((async, c, _, _) => expect(stateOf(c).isOnline, isTrue));
    });

    test(
      'a phone that starts with no network goes offline after the delay',
      () {
        run((async, c, _, _) {
          expect(stateOf(c).isOnline, isTrue, reason: 'not at once');
          async.elapse(ConnectivityNotifier.offlineDelay);
          expect(stateOf(c).reason, OfflineReason.noInterface);
        }, interfaceUp: false);
      },
    );
  });

  group('the phone reports the network going away', () {
    test('a short drop (a Wi-Fi to mobile hand-over) is not an outage', () {
      run((async, c, source, _) {
        source.set(false);
        async.elapse(const Duration(milliseconds: 600));
        source.set(true);
        async.elapse(const Duration(seconds: 5));

        expect(stateOf(c).isOnline, isTrue);
        expect(restored(c), 0);
      });
    });

    test('a lasting drop is reported once it passes the delay', () {
      run((async, c, source, _) {
        source.set(false);
        async.elapse(
          ConnectivityNotifier.offlineDelay - const Duration(milliseconds: 1),
        );
        expect(stateOf(c).isOnline, isTrue);

        async.elapse(const Duration(milliseconds: 1));
        expect(stateOf(c).reason, OfflineReason.noInterface);
        expect(stateOf(c).isChecking, isFalse);
      });
    });

    test('repeated drop reports do not restart the delay', () {
      run((async, c, source, _) {
        source.set(false);
        async.elapse(const Duration(milliseconds: 1000));
        source.set(false);
        async.elapse(const Duration(milliseconds: 600));

        expect(stateOf(c).reason, OfflineReason.noInterface);
      });
    });
  });

  group('the connection returns', () {
    test('goes online only after the backend answers, and announces it', () {
      run((async, c, source, probe) {
        source.set(false);
        async.elapse(ConnectivityNotifier.offlineDelay);
        expect(stateOf(c).isOffline, isTrue);

        source.set(true);
        async.flushMicrotasks();

        expect(probe.calls, 1);
        expect(stateOf(c).isOnline, isTrue);
        expect(restored(c), 1);
      });
    });

    test('shows checking while it confirms', () {
      run((async, c, source, probe) {
        source.set(false);
        async.elapse(ConnectivityNotifier.offlineDelay);
        probe.hold = Completer<bool>();

        source.set(true);
        async.flushMicrotasks();

        expect(stateOf(c).isOffline, isTrue);
        expect(stateOf(c).isChecking, isTrue);

        probe.hold!.complete(true);
        async.flushMicrotasks();
        expect(stateOf(c).isOnline, isTrue);
      });
    });

    test(
      'a network with no internet behind it (a captive portal) stays offline',
      () {
        run((async, c, source, probe) {
          source.set(false);
          async.elapse(ConnectivityNotifier.offlineDelay);
          probe.reachable = false;

          source.set(true);
          async.flushMicrotasks();

          expect(stateOf(c).reason, OfflineReason.unreachable);
          expect(stateOf(c).isChecking, isFalse);
          expect(restored(c), 0);
        });
      },
    );
  });

  group('real requests as evidence', () {
    test('one failed request is noise', () {
      run((async, c, _, probe) {
        c.read(connectivityProvider.notifier).reportUnreachable();
        async.flushMicrotasks();

        expect(stateOf(c).isOnline, isTrue);
        expect(probe.calls, 0);
      });
    });

    test(
      'a second failure within the window earns one check, which can fail',
      () {
        run((async, c, _, probe) {
          probe.reachable = false;
          final n = c.read(connectivityProvider.notifier);
          n.reportUnreachable();
          async.elapse(const Duration(seconds: 5));
          n.reportUnreachable();
          async.flushMicrotasks();

          expect(probe.calls, 1);
          expect(stateOf(c).reason, OfflineReason.unreachable);
        });
      },
    );

    test('a check that finds the backend fine leaves the app online', () {
      run((async, c, _, probe) {
        final n = c.read(connectivityProvider.notifier);
        n.reportUnreachable();
        n.reportUnreachable();
        async.flushMicrotasks();

        expect(probe.calls, 1);
        expect(stateOf(c).isOnline, isTrue);
      });
    });

    test('failures spread over more than the window never add up', () {
      run((async, c, _, probe) {
        final n = c.read(connectivityProvider.notifier);
        n.reportUnreachable();
        async.elapse(
          ConnectivityNotifier.failureWindow + const Duration(seconds: 1),
        );
        n.reportUnreachable();
        async.flushMicrotasks();

        expect(probe.calls, 0);
      });
    });

    test('a success in between wipes the count', () {
      run((async, c, _, probe) {
        final n = c.read(connectivityProvider.notifier);
        n.reportUnreachable();
        n.reportReachable();
        n.reportUnreachable();
        async.flushMicrotasks();

        expect(probe.calls, 0);
      });
    });

    test('never probes while the phone itself says it has no network', () {
      run((async, c, source, probe) {
        source.set(false);
        async.flushMicrotasks(); // the phone's report arrives
        final n = c.read(connectivityProvider.notifier);
        n.reportUnreachable();
        n.reportUnreachable();
        async.flushMicrotasks();

        expect(probe.calls, 0);
      });
    });

    test('a burst of failures runs one check, not many', () {
      run((async, c, _, probe) {
        probe.hold = Completer<bool>();
        final n = c.read(connectivityProvider.notifier);
        for (var i = 0; i < 6; i++) {
          n.reportUnreachable();
        }
        async.flushMicrotasks();

        expect(probe.calls, 1);
        probe.hold!.complete(true);
        async.flushMicrotasks();
      });
    });

    test('any response ends an offline spell at once and announces it', () {
      run((async, c, source, probe) {
        probe.reachable = false;
        final n = c.read(connectivityProvider.notifier);
        n.reportUnreachable();
        n.reportUnreachable();
        async.flushMicrotasks();
        expect(stateOf(c).isOffline, isTrue);

        n.reportReachable();

        expect(stateOf(c).isOnline, isTrue);
        expect(restored(c), 1);
      });
    });

    test('a success while already online announces nothing', () {
      run((async, c, _, _) {
        c.read(connectivityProvider.notifier).reportReachable();
        expect(restored(c), 0);
      });
    });
  });

  group('checking again', () {
    test('finds the network gone', () {
      run((async, c, source, _) {
        source.up = false; // no event, as if one were missed
        c.read(connectivityProvider.notifier).recheck();
        async.flushMicrotasks();

        expect(stateOf(c).reason, OfflineReason.noInterface);
      });
    });

    test('finds the network back, and announces it', () {
      run((async, c, source, probe) {
        probe.reachable = false;
        final n = c.read(connectivityProvider.notifier);
        n.reportUnreachable();
        n.reportUnreachable();
        async.flushMicrotasks();
        expect(stateOf(c).isOffline, isTrue);

        probe.reachable = true;
        n.recheck();
        async.flushMicrotasks();

        expect(stateOf(c).isOnline, isTrue);
        expect(restored(c), 1);
      });
    });

    test('shows checking while it waits, and the answer replaces it', () {
      run((async, c, _, probe) {
        probe.reachable = false;
        final n = c.read(connectivityProvider.notifier);
        n.reportUnreachable();
        n.reportUnreachable();
        async.flushMicrotasks();

        probe.hold = Completer<bool>();
        n.recheck();
        async.flushMicrotasks();
        expect(stateOf(c).isChecking, isTrue);

        probe.hold!.complete(false);
        async.flushMicrotasks();
        expect(stateOf(c).isChecking, isFalse);
        expect(stateOf(c).reason, OfflineReason.unreachable);
      });
    });

    test('a second tap while checking does nothing extra', () {
      run((async, c, _, probe) {
        probe.reachable = false;
        final n = c.read(connectivityProvider.notifier);
        n.reportUnreachable();
        n.reportUnreachable();
        async.flushMicrotasks();
        final before = probe.calls;

        probe.hold = Completer<bool>();
        n.recheck();
        async.flushMicrotasks();
        n.recheck();
        async.flushMicrotasks();

        expect(probe.calls, before + 1);
        probe.hold!.complete(true);
        async.flushMicrotasks();
      });
    });
  });

  group('app lifecycle', () {
    test('re-reads the network when the app comes back to the front', () {
      run((async, c, source, _) {
        final before = source.reads;
        source.up = false; // changed while the app was suspended
        c
            .read(connectivityProvider.notifier)
            .didChangeAppLifecycleState(AppLifecycleState.resumed);
        async.flushMicrotasks();
        expect(source.reads, before + 1);

        async.elapse(ConnectivityNotifier.offlineDelay);
        expect(stateOf(c).reason, OfflineReason.noInterface);
      });
    });

    test('going to the background does nothing', () {
      run((async, c, source, _) {
        final before = source.reads;
        c
            .read(connectivityProvider.notifier)
            .didChangeAppLifecycleState(AppLifecycleState.paused);
        async.flushMicrotasks();
        expect(source.reads, before);
      });
    });
  });

  test('disposing mid-check does not touch a dead notifier', () {
    fakeAsync((async) {
      final source = FakeConnectivitySource();
      final probe = FakeProbe(reachable: false)..hold = Completer<bool>();
      final container = connectivityContainer(source, probe);
      container.listen(connectivityProvider, (_, _) {});
      async.flushMicrotasks();

      final n = container.read(connectivityProvider.notifier);
      n.reportUnreachable();
      n.reportUnreachable();
      async.flushMicrotasks();
      container.dispose();
      probe.hold!.complete(false);
      async.flushMicrotasks();

      source.dispose();
    });
  });
}

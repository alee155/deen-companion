import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:deen_companion/core/connectivity/data/connectivity_plus_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockConnectivity extends Mock implements Connectivity {}

void main() {
  group('what the plugin reports means', () {
    test('only "none" is no network', () {
      expect(
        ConnectivityPlusSource.interfaceUp([ConnectivityResult.none]),
        isFalse,
      );
    });

    test('any real network is a network', () {
      for (final r in [
        ConnectivityResult.wifi,
        ConnectivityResult.mobile,
        ConnectivityResult.ethernet,
        ConnectivityResult.vpn,
        ConnectivityResult.bluetooth,
        ConnectivityResult.other,
      ]) {
        expect(ConnectivityPlusSource.interfaceUp([r]), isTrue, reason: r.name);
      }
    });

    test('Android reports several at once: Wi-Fi with a VPN is up', () {
      expect(
        ConnectivityPlusSource.interfaceUp([
          ConnectivityResult.wifi,
          ConnectivityResult.vpn,
        ]),
        isTrue,
      );
    });

    test('an empty answer is not read as offline', () {
      expect(ConnectivityPlusSource.interfaceUp(const []), isTrue);
    });
  });

  group('reading the network', () {
    late _MockConnectivity plugin;
    setUp(() => plugin = _MockConnectivity());

    test('reports what the plugin says', () async {
      when(
        () => plugin.checkConnectivity(),
      ).thenAnswer((_) async => [ConnectivityResult.none]);
      expect(await ConnectivityPlusSource(plugin).hasInterface(), isFalse);

      when(
        () => plugin.checkConnectivity(),
      ).thenAnswer((_) async => [ConnectivityResult.wifi]);
      expect(await ConnectivityPlusSource(plugin).hasInterface(), isTrue);
    });

    test('a plugin that throws (channel not ready) reads as online', () async {
      when(() => plugin.checkConnectivity()).thenThrow(Exception('not ready'));
      expect(await ConnectivityPlusSource(plugin).hasInterface(), isTrue);
    });

    test('a plugin that never answers reads as online, after a wait', () async {
      when(
        () => plugin.checkConnectivity(),
      ).thenAnswer((_) => Completer<List<ConnectivityResult>>().future);
      final result = await ConnectivityPlusSource(plugin).hasInterface();
      expect(result, isTrue);
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('changes are mapped the same way', () async {
      when(() => plugin.onConnectivityChanged).thenAnswer(
        (_) => Stream.fromIterable([
          [ConnectivityResult.none],
          [ConnectivityResult.mobile],
        ]),
      );
      expect(await ConnectivityPlusSource(plugin).interfaceChanges.toList(), [
        false,
        true,
      ]);
    });
  });
}

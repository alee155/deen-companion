import 'package:deen_companion/core/state/keep_alive_for.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _ttl = Duration(milliseconds: 80);
Future<void> _wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  late int builds;
  late KeepAliveLink? link;
  late ProviderContainer container;

  final provider = FutureProvider.autoDispose<int>((ref) async {
    link = keepAliveFor(ref, _ttl);
    return ++builds;
  });

  setUp(() {
    builds = 0;
    link = null;
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  /// One "visit": listen, wait for data, stop listening.
  Future<int> visit() async {
    final sub = container.listen(provider, (_, _) {});
    final value = await container.read(provider.future);
    sub.close();
    return value;
  }

  test('a plain auto-dispose provider would reload on every visit', () async {
    final plain = FutureProvider.autoDispose<int>((ref) async => ++builds);
    final s1 = container.listen(plain, (_, _) {});
    await container.read(plain.future);
    s1.close();
    await _wait(10);
    final s2 = container.listen(plain, (_, _) {});
    await container.read(plain.future);
    s2.close();
    expect(builds, 2, reason: 'this is the problem keepAliveFor solves');
  });

  test('data survives leaving and coming back within the time limit', () async {
    expect(await visit(), 1);
    await _wait(20);
    expect(await visit(), 1, reason: 'the same data, not a new load');
    expect(builds, 1);
  });

  test('data is dropped once the time limit passes', () async {
    expect(await visit(), 1);
    await _wait(200);
    expect(await visit(), 2);
  });

  test('coming back before the limit restarts the clock', () async {
    await visit();
    await _wait(50);
    await visit(); // clock restarts when this visit ends
    await _wait(50); // 100 ms since the first leave, only 50 since the second
    expect(await visit(), 1);
  });

  test('while someone is listening it is never dropped', () async {
    final sub = container.listen(provider, (_, _) {});
    await container.read(provider.future);
    await _wait(200);
    expect(builds, 1);
    expect(container.read(provider).value, 1);
    sub.close();
  });

  test('the returned link drops the data early', () async {
    await visit();
    link!.close();
    await _wait(10);
    expect(await visit(), 2, reason: 'closing the link ended the keep-alive');
  });

  test('no timer is left running when the container is disposed', () async {
    await visit();
    container.dispose();
    // A leaked timer would fire its callback later and throw.
    await _wait(150);
  });
}

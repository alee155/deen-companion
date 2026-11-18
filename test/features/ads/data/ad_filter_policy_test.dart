import 'package:deen_companion/features/ads/data/constants/ad_filter_policy.dart';
import 'package:deen_companion/features/ads/data/datasources/mobile_ads_initializer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ads are capped at the strictest rating, G', () {
    expect(AdFilterPolicy.maxRating, MaxAdContentRating.g);
    expect(AdFilterPolicy.maxRating, 'G');
    expect(
      AdFilterPolicy.requestConfiguration().maxAdContentRating,
      MaxAdContentRating.g,
    );
  });

  test('the app is not marked child-directed or under the age of consent', () {
    final c = AdFilterPolicy.requestConfiguration();
    expect(c.tagForChildDirectedTreatment, TagForChildDirectedTreatment.no);
    expect(c.tagForUnderAgeOfConsent, TagForUnderAgeOfConsent.no);
  });

  test('every ad type is requested through the one shared request', () {
    expect(AdFilterPolicy.request(), isA<AdRequest>());
  });

  test('the rating is sent to the platform before the SDK starts', () async {
    final calls = <String>[];
    Object? rating;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel(
        'plugins.flutter.io/google_mobile_ads',
        StandardMethodCodec(),
      ),
      (call) async {
        calls.add(call.method);
        if (call.method == 'MobileAds#updateRequestConfiguration') {
          rating = (call.arguments as Map)['maxAdContentRating'];
        }
        return null;
      },
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(
        const MethodChannel(
          'plugins.flutter.io/google_mobile_ads',
          StandardMethodCodec(),
        ),
        null,
      ),
    );

    await const MobileAdsInitializer().initialize();

    final update = calls.indexOf('MobileAds#updateRequestConfiguration');
    final start = calls.indexOf('MobileAds#initialize');
    expect(update, isNonNegative, reason: 'the rating was never sent');
    expect(start, isNonNegative);
    expect(update, lessThan(start), reason: 'rating must come first');
    expect(rating, 'G');
  });
}

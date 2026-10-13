// ignore_for_file: depend_on_referenced_packages
import 'dart:io';
import 'dart:typed_data';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/snaps/data/flutter_snap_image_processor.dart';
import 'package:deen_companion/features/snaps/domain/entities/snap_draft.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Records how the app calls the compression plugin.
class _FakeCompress extends FlutterImageCompressPlatform
    with MockPlatformInterfaceMixin {
  Map<String, Object?>? fileArgs;
  Map<String, Object?>? listArgs;
  Uint8List? fileResult = Uint8List.fromList(List.filled(300, 1));
  Uint8List listResult = Uint8List.fromList(List.filled(120, 2));
  Object? throwOnList;

  @override
  Future<Uint8List?> compressWithFile(
    String path, {
    int minWidth = 1920,
    int minHeight = 1080,
    int inSampleSize = 1,
    int quality = 95,
    int rotate = 0,
    bool autoCorrectionAngle = true,
    CompressFormat format = CompressFormat.jpeg,
    bool keepExif = false,
    int numberOfRetries = 5,
  }) async {
    fileArgs = {
      'path': path,
      'minWidth': minWidth,
      'minHeight': minHeight,
      'quality': quality,
      'autoCorrectionAngle': autoCorrectionAngle,
      'format': format,
      'keepExif': keepExif,
    };
    return fileResult;
  }

  @override
  Future<Uint8List> compressWithList(
    Uint8List image, {
    int minWidth = 1920,
    int minHeight = 1080,
    int quality = 95,
    int rotate = 0,
    int inSampleSize = 1,
    bool autoCorrectionAngle = true,
    CompressFormat format = CompressFormat.jpeg,
    bool keepExif = false,
  }) async {
    if (throwOnList != null) throw throwOnList!;
    listArgs = {
      'minWidth': minWidth,
      'minHeight': minHeight,
      'quality': quality,
      'autoCorrectionAngle': autoCorrectionAngle,
      'format': format,
      'keepExif': keepExif,
    };
    return listResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late _FakeCompress fake;
  late FlutterImageCompressPlatform original;
  const processor = FlutterSnapImageProcessor();

  setUp(() {
    original = FlutterImageCompressPlatform.instance;
    fake = _FakeCompress();
    FlutterImageCompressPlatform.instance = fake;
  });
  tearDown(() => FlutterImageCompressPlatform.instance = original);

  test('editing copy: bounded size, upright, JPEG', () async {
    final r = await processor.prepareForEditing('/tmp/shot.jpg');
    expect((r as Success<Uint8List>).data, hasLength(300));
    expect(fake.fileArgs!['path'], '/tmp/shot.jpg');
    expect(fake.fileArgs!['minWidth'], FlutterSnapImageProcessor.editShortSide);
    expect(
      fake.fileArgs!['minHeight'],
      FlutterSnapImageProcessor.editShortSide,
    );
    expect(fake.fileArgs!['autoCorrectionAngle'], isTrue);
    expect(fake.fileArgs!['format'], CompressFormat.jpeg);
  });

  test('upload copy: 1080 short side, quality 80, no EXIF (privacy)', () async {
    final r = await processor.compressForUpload(
      Uint8List.fromList(List.filled(1000, 3)),
    );
    final prepared = (r as Success<PreparedImage>).data;
    expect(fake.listArgs!['minWidth'], 1080);
    expect(fake.listArgs!['minHeight'], 1080);
    expect(fake.listArgs!['quality'], 80);
    expect(fake.listArgs!['keepExif'], isFalse);
    expect(fake.listArgs!['format'], CompressFormat.jpeg);
    expect(prepared.originalBytes, 1000);
    expect(prepared.compressedBytes, 120);
    expect(prepared.savedFraction, closeTo(0.88, 0.001));

    final f = File(prepared.path);
    expect(await f.exists(), isTrue);
    expect(await f.length(), 120);
    await processor.cleanUp([prepared.path]);
    expect(await f.exists(), isFalse);
  });

  test('failures become a friendly Failure, not an exception', () async {
    fake.fileResult = null;
    expect(await processor.prepareForEditing('/x.jpg'), isA<Error>());
    fake.throwOnList = StateError('native crash');
    expect(
      await processor.compressForUpload(Uint8List.fromList([1])),
      isA<Error>(),
    );
  });

  test('cleanUp ignores files that are already gone', () async {
    await processor.cleanUp(['/definitely/not/here.jpg']);
  });
}

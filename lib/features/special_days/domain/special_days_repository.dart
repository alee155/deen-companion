import '../../../core/usecase/usecase.dart';
import '../../prayer_times/domain/entities/prayer_times.dart';
import 'special_days.dart';

abstract class SpecialDaysRepository {
  /// The photos can't be larger than a snap may be.
  static const maxPhotoBytes = 5 * 1024 * 1024;

  /// `GET /exemption`.
  Future<Result<SpecialDays>> getState();

  /// `GET /exemption/images`: the stored photos with links to see them. A
  /// prayer without a photo is not in the map.
  Future<Result<Map<PrayerName, SpecialDayImage>>> getImages();

  /// `PUT /exemption/status`: [active] true starts a period (needs all five
  /// photos, prayer times and enough time since the last period), false ends
  /// the active one. Returns the state as it is afterwards.
  Future<Result<SpecialDays>> setActive(bool active);

  /// `PUT /exemption/images/{prayer}`: adds or replaces one photo. The five
  /// must all differ. Allowed while special days run: prayers whose window
  /// opens afterwards use the new photo.
  Future<Result<SpecialDays>> uploadImage(PrayerName prayer, String path);

  /// `DELETE /exemption/images/{prayer}`. Allowed while special days run: a
  /// window that opens with no photo for its prayer is skipped.
  Future<Result<SpecialDays>> removeImage(PrayerName prayer);
}

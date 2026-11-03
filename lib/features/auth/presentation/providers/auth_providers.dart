import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/timezone/device_timezone.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/social/plugin_social_auth_service.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/services/social_auth_service.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>(
  (ref) => AuthRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final socialAuthServiceProvider = Provider<SocialAuthService>(
  (ref) => PluginSocialAuthService(),
);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remote: ref.watch(authRemoteDataSourceProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
    deviceTimezone: ref.watch(deviceTimezoneProvider),
    social: ref.watch(socialAuthServiceProvider),
  );
});

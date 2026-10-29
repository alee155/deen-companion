import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/widgets/app_toast.dart';
import '../domain/entities/bayan_video.dart';

/// Opens the video's own page: the platform's app if it is installed, else the
/// browser. Says so if neither can.
Future<void> openVideoExternally(BuildContext context, BayanVideo video) async {
  bool opened = false;
  try {
    opened = await launchUrl(
      video.source.uri,
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    showAppToast(context, 'Couldn’t open the video. Try again in a moment.');
  }
}

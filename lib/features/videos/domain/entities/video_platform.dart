/// Where a video is hosted. The API gives only a link, so this is worked out
/// from it (see `VideoPlatformRegistry`). Add a value here, and a handler for
/// it, to support another platform.
enum VideoPlatform {
  youtube('YouTube'),

  /// A link from a site we have no handler for: shown, and opened in the
  /// browser, never played inside the app.
  other('Web');

  final String label;
  const VideoPlatform(this.label);
}

/// How the app can play a video from a platform.
enum VideoPlayback {
  /// Inside the app, in the platform's own embedded player.
  embedded,

  /// Only by opening the link in the platform's app or the browser.
  external,
}

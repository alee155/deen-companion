/// Drives what a banner ad slot renders. Kept deliberately small — the UI
/// only ever needs to distinguish "still deciding", "show a placeholder",
/// "show the ad", or "show nothing".
enum AdLoadStatus { initial, loading, loaded, failed }

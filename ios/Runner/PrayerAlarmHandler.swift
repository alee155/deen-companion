import ActivityKit
import AlarmKit
import AppIntents
import Flutter
import SwiftUI

/// iOS side of the `prayer_alarms` channel, backed by AlarmKit (iOS 26+).
///
/// AlarmKit alarms ring through the silent switch and Focus modes, which is
/// the closest iOS gets to the Android full-screen prayer alarm. On older iOS
/// every scheduling call answers "not implemented", which the Dart side reads
/// as "fall back to local notifications".
final class PrayerAlarmHandler {
  static let channelName = "com.devsouq.deen_companion.app/prayer_alarms"

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard #available(iOS 26.0, *) else {
        // checks that have a harmless answer on old iOS keep working
        switch call.method {
        case "checkFullScreenIntentPermission", "checkIgnoreBatteryOptimizations":
          result(true)
        case "requestNotificationPermission", "alarmKitAvailable":
          result(false)
        case "consumeAlarmOpen":
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
        return
      }
      Task { @MainActor in
        await PrayerAlarmController.shared.handle(call, result: result)
      }
    }
  }
}

/// Hand-off from the alarm screen's "Open" button to Flutter. The intent runs
/// in the app's process and the app is then brought to the front; Dart asks
/// for the pending alarm on launch and on resume (`consumeAlarmOpen`).
enum PrayerAlarmOpenStore {
  private static let key = "prayer_alarm_open"

  static func save(_ values: [String: Any]) {
    UserDefaults.standard.set(values, forKey: key)
  }

  static func consume() -> [String: Any]? {
    let values = UserDefaults.standard.dictionary(forKey: key)
    UserDefaults.standard.removeObject(forKey: key)
    return values
  }
}

/// The "Open" button on the ringing alarm: stops it and opens Deen Companion
/// on the prayer screen, where the user can dismiss or snooze.
@available(iOS 26.0, *)
struct OpenPrayerAlarmIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "Open prayer"
  static var openAppWhenRun: Bool = true

  @Parameter(title: "Alarm") var alarmID: String
  @Parameter(title: "Prayer") var prayer: String
  @Parameter(title: "Label") var label: String
  @Parameter(title: "Time") var epochMillis: Double
  @Parameter(title: "Snooze minutes") var snoozeMinutes: Int

  init() {}

  init(alarmID: String, prayer: String, label: String, epochMillis: Double, snoozeMinutes: Int) {
    self.alarmID = alarmID
    self.prayer = prayer
    self.label = label
    self.epochMillis = epochMillis
    self.snoozeMinutes = snoozeMinutes
  }

  func perform() async throws -> some IntentResult {
    if let id = UUID(uuidString: alarmID) {
      try? AlarmManager.shared.stop(id: id)
    }
    PrayerAlarmOpenStore.save([
      "prayerName": prayer,
      "label": label,
      "epochMillis": epochMillis,
      "snoozeMinutes": snoozeMinutes,
    ])
    return .result()
  }
}

@available(iOS 26.0, *)
struct PrayerAlarmMetadata: AlarmMetadata {
  var prayerName: String
}

@available(iOS 26.0, *)
@MainActor
final class PrayerAlarmController {
  static let shared = PrayerAlarmController()
  private let manager = AlarmManager.shared
  private let soundFile = "azan_ringtone.caf"

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) async {
    switch call.method {
    case "pushSchedule":
      guard let args = call.arguments as? [String: Any],
        let entries = args["entries"] as? [[String: Any]]
      else {
        result(FlutterError(code: "bad_args", message: "entries missing", details: nil))
        return
      }
      result(await pushSchedule(entries))
    case "cancelAllAlarms":
      cancelAll()
      result(nil)
    case "requestNotificationPermission":
      // On iOS this is the alarm permission: the prompt reads
      // NSAlarmKitUsageDescription from Info.plist.
      result(await requestAuthorization())
    case "checkFullScreenIntentPermission":
      result(manager.authorizationState == .authorized)
    case "openFullScreenIntentSettings", "openBatterySettings":
      if let url = URL(string: UIApplication.openSettingsURLString) {
        await UIApplication.shared.open(url)
      }
      result(nil)
    case "checkIgnoreBatteryOptimizations":
      result(true)
    case "alarmKitAvailable":
      result(true)
    case "consumeAlarmOpen":
      result(PrayerAlarmOpenStore.consume())
    case "snoozeAlarm":
      guard let args = call.arguments as? [String: Any] else {
        result(false)
        return
      }
      result(await snooze(args))
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func requestAuthorization() async -> Bool {
    switch manager.authorizationState {
    case .authorized: return true
    case .denied: return false
    default:
      return (try? await manager.requestAuthorization()) == .authorized
    }
  }

  private func cancelAll() {
    guard let alarms = try? manager.alarms else { return }
    for alarm in alarms {
      try? manager.cancel(id: alarm.id)
    }
  }

  /// Replaces every armed alarm with [entries]; returns how many are armed.
  private func pushSchedule(_ entries: [[String: Any]]) async -> Int {
    guard await requestAuthorization() else { return 0 }
    cancelAll()

    var armed = 0
    for entry in entries {
      guard let millis = (entry["epochMillis"] as? NSNumber)?.doubleValue,
        let label = entry["label"] as? String
      else { continue }
      let prayer = entry["prayerName"] as? String ?? ""
      let snoozeOn = entry["snoozeEnabled"] as? Bool ?? true
      let minutes = (entry["snoozeMinutes"] as? NSNumber)?.intValue ?? 10
      let date = Date(timeIntervalSince1970: millis / 1000)
      guard date > Date() else { continue }

      // 0 tells the prayer screen to hide Snooze for this prayer.
      switch await arm(
        label: label, prayer: prayer, date: date, snoozeMinutes: snoozeOn ? minutes : 0)
      {
      case .armed: armed += 1
      case .limit: return armed  // keep what fit: the earliest alarms matter most
      case .failed: continue
      }
    }
    return armed
  }

  /// A one-off alarm [minutes] from now, scheduled from the prayer screen's
  /// Snooze button.
  private func snooze(_ args: [String: Any]) async -> Bool {
    guard await requestAuthorization() else { return false }
    let minutes = (args["minutes"] as? NSNumber)?.intValue ?? 10
    let prayer = args["prayerName"] as? String ?? ""
    let label = args["label"] as? String ?? prayer
    let date = Date().addingTimeInterval(Double(minutes) * 60)
    return await arm(label: label, prayer: prayer, date: date, snoozeMinutes: minutes) == .armed
  }

  private enum ArmResult { case armed, limit, failed }

  private func arm(label: String, prayer: String, date: Date, snoozeMinutes: Int) async -> ArmResult {
    let id = UUID()
    do {
      _ = try await manager.schedule(
        id: id,
        configuration: configuration(
          id: id, label: label, prayer: prayer, date: date, snoozeMinutes: snoozeMinutes))
      return .armed
    } catch AlarmManager.AlarmError.maximumLimitReached {
      return .limit
    } catch {
      NSLog("PrayerAlarm: scheduling \(prayer) failed: \(error)")
      return .failed
    }
  }

  /// The adhan on a device. The Simulator's tone library cannot play alarm
  /// sounds and crashes SpringBoard when handed a custom one, so debug runs
  /// there use the system default.
  private var alarmSound: ActivityKit.AlertConfiguration.AlertSound {
    #if targetEnvironment(simulator)
      return .default
    #else
      return .named(soundFile)
    #endif
  }

  private func configuration(
    id: UUID, label: String, prayer: String, date: Date, snoozeMinutes: Int
  ) -> AlarmManager.AlarmConfiguration<PrayerAlarmMetadata> {
    let title = LocalizedStringResource(String.LocalizationValue(label))
    let openButton = AlarmButton(
      text: "Open", textColor: .white, systemImageName: "book.fill")

    let alert: AlarmPresentation.Alert
    if #available(iOS 26.1, *) {
      alert = AlarmPresentation.Alert(
        title: title,
        secondaryButton: openButton,
        secondaryButtonBehavior: .custom)
    } else {
      alert = AlarmPresentation.Alert(
        title: title,
        stopButton: AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.circle"),
        secondaryButton: openButton,
        secondaryButtonBehavior: .custom)
    }

    let attributes = AlarmAttributes(
      presentation: AlarmPresentation(alert: alert),
      metadata: PrayerAlarmMetadata(prayerName: prayer),
      tintColor: Color(red: 0.94, green: 0.51, blue: 0.20))

    let open = OpenPrayerAlarmIntent(
      alarmID: id.uuidString, prayer: prayer, label: label,
      epochMillis: date.timeIntervalSince1970 * 1000, snoozeMinutes: snoozeMinutes)

    return AlarmManager.AlarmConfiguration.alarm(
      schedule: .fixed(date),
      attributes: attributes,
      secondaryIntent: open,
      sound: alarmSound)
  }
}

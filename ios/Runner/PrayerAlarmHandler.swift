import ActivityKit
import AlarmKit
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
      let snooze = entry["snoozeEnabled"] as? Bool ?? false
      let snoozeMinutes = (entry["snoozeMinutes"] as? NSNumber)?.intValue ?? 10
      let date = Date(timeIntervalSince1970: millis / 1000)
      guard date > Date() else { continue }

      do {
        _ = try await manager.schedule(
          id: UUID(),
          configuration: configuration(
            label: label, prayer: prayer, date: date,
            snoozeSeconds: snooze ? Double(snoozeMinutes * 60) : nil))
        armed += 1
      } catch AlarmManager.AlarmError.maximumLimitReached {
        // Keep what fit: the earliest alarms are the ones that matter.
        break
      } catch {
        NSLog("PrayerAlarm: scheduling \(prayer) failed: \(error)")
      }
    }
    return armed
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
    label: String, prayer: String, date: Date, snoozeSeconds: Double?
  ) -> AlarmManager.AlarmConfiguration<PrayerAlarmMetadata> {
    let title = LocalizedStringResource(String.LocalizationValue(label))
    let snoozeButton = AlarmButton(
      text: "Snooze", textColor: .white, systemImageName: "zzz")

    let alert: AlarmPresentation.Alert
    if #available(iOS 26.1, *) {
      alert = AlarmPresentation.Alert(
        title: title,
        secondaryButton: snoozeSeconds == nil ? nil : snoozeButton,
        secondaryButtonBehavior: snoozeSeconds == nil ? nil : .countdown)
    } else {
      alert = AlarmPresentation.Alert(
        title: title,
        stopButton: AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.circle"),
        secondaryButton: snoozeSeconds == nil ? nil : snoozeButton,
        secondaryButtonBehavior: snoozeSeconds == nil ? nil : .countdown)
    }

    let presentation = AlarmPresentation(
      alert: alert,
      countdown: snoozeSeconds == nil ? nil : AlarmPresentation.Countdown(title: "Snoozed"))

    let attributes = AlarmAttributes(
      presentation: presentation,
      metadata: PrayerAlarmMetadata(prayerName: prayer),
      tintColor: Color(red: 0.89, green: 0.55, blue: 0.22))

    return AlarmManager.AlarmConfiguration(
      countdownDuration: snoozeSeconds.map {
        Alarm.CountdownDuration(preAlert: nil, postAlert: $0)
      },
      schedule: .fixed(date),
      attributes: attributes,
      sound: alarmSound)
  }
}

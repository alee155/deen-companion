import 'package:flutter/material.dart';

/// Everything the OS must allow before reminders and notifications can fire
/// at their exact time. Declared in the order they are asked for.
enum ReliabilityRequirement {
  location(
    icon: Icons.my_location_rounded,
    title: 'Location',
    why: 'Calculates prayer times, and so Fajr alerts, for where you are.',
  ),
  notifications(
    icon: Icons.notifications_active_rounded,
    title: 'Notifications',
    why:
        'Lets Deen alert you at prayer times and send the daily Ayat & Hadith.',
  ),
  exactAlarms(
    icon: Icons.alarm_on_rounded,
    title: 'Alarms & reminders',
    why: 'Makes alerts fire at the exact minute instead of minutes late.',
  ),
  fullScreenAlerts(
    icon: Icons.lock_clock_rounded,
    title: 'Full-screen alerts',
    why: 'Lets the prayer alarm ring over your lock screen.',
  ),
  batteryOptimization(
    icon: Icons.battery_saver_rounded,
    title: 'Unrestricted battery',
    why: 'Stops Android delaying or silencing alarms while your phone is idle.',
  );

  const ReliabilityRequirement({
    required this.icon,
    required this.title,
    required this.why,
  });

  final IconData icon;
  final String title;
  final String why;
}

typedef ReliabilityStatus = Map<ReliabilityRequirement, bool>;

extension ReliabilityStatusX on ReliabilityStatus {
  List<ReliabilityRequirement> get missing => [
    for (final e in entries)
      if (!e.value) e.key,
  ];

  bool get allGranted => missing.isEmpty;
}

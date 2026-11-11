import 'package:livecoding/models/time_range.dart';

class Specialist {
  const Specialist({
    required this.id,
    required this.name,
    required this.service,
    required this.slotMinutes,
    required this.workingHours,
    this.breakRange,
  });

  final String id;
  final String name;
  final String service;
  final int slotMinutes;
  final Map<int, TimeRange?> workingHours;
  final TimeRange? breakRange;

  TimeRange? workingHoursFor(DateTime day) => workingHours[day.weekday];
}

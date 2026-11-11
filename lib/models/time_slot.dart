class TimeSlot {
  const TimeSlot({
    required this.start,
    required this.end,
    this.isAvailable = true,
  });

  final DateTime start;
  final DateTime end;
  final bool isAvailable;
}

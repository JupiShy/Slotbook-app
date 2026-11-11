/// Represents a time-of-day interval relative to midnight (`00:00`).
///
/// Using [Duration] offsets allows end-of-day values like `'00:00'`
/// to be normalized as 24 hours without date wrap-around ambiguity.
class TimeRange {
  const TimeRange({
    required this.start,
    required this.end,
  });

  final Duration start;
  final Duration end;

  bool overlaps(TimeRange other) => start < other.end && end > other.start;
}

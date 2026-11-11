enum BookingStatus {
  active,
  pending,
  cancelled,
}

class Booking {
  const Booking({
    required this.id,
    required this.specialistId,
    required this.start,
    required this.end,
    required this.status,
    this.clientName,
    this.expiresAt,
  });

  final String id;
  final String specialistId;
  final DateTime start;
  final DateTime end;
  final BookingStatus status;
  final String? clientName;
  final DateTime? expiresAt;

  bool get isActive => status == BookingStatus.active;

  bool get isPending => status == BookingStatus.pending;

  bool isBlockingAt(DateTime now) {
    if (status == BookingStatus.active) return true;
    if (status == BookingStatus.pending) {
      return expiresAt == null || expiresAt!.isAfter(now);
    }
    return false;
  }

  Booking copyWith({
    String? clientName,
  }) {
    return Booking(
      id: id,
      specialistId: specialistId,
      start: start,
      end: end,
      status: status,
      clientName: clientName ?? this.clientName,
      expiresAt: expiresAt,
    );
  }
}

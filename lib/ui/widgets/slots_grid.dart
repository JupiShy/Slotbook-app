import 'package:flutter/material.dart';

import 'package:livecoding/models/time_slot.dart';
import 'package:livecoding/ui/widgets/slot_chip.dart';

class SlotsGrid extends StatelessWidget {
  const SlotsGrid({
    required this.slots,
    required this.onSlotTap,
    this.shrinkWrap = false,
    super.key,
  });

  final List<TimeSlot> slots;
  final ValueChanged<TimeSlot> onSlotTap;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.25,
      ),
      itemCount: slots.length,
      itemBuilder: (context, index) {
        final slot = slots[index];
        return SlotChip(
          slot: slot,
          onTap: () => onSlotTap(slot),
        );
      },
    );
  }
}

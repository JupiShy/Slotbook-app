import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:livecoding/logic/client_name_validator.dart';
import 'package:livecoding/models/booking.dart';
import 'package:livecoding/models/specialist.dart';
import 'package:livecoding/models/time_slot.dart';
import 'package:livecoding/state/booking_cubit.dart';
import 'package:livecoding/state/booking_state.dart';
import 'package:livecoding/ui/formatters/date_time_formatter.dart';
import 'package:livecoding/ui/theme/app_theme.dart';

class BookingSheet extends StatefulWidget {
  const BookingSheet({
    required this.specialist,
    required this.slot,
    required this.today,
    super.key,
  });

  final Specialist specialist;
  final TimeSlot slot;
  final DateTime today;

  static Future<bool?> show({
    required BuildContext context,
    required Specialist specialist,
    required TimeSlot slot,
    required DateTime today,
  }) {
    final cubit = context.read<BookingCubit>()
      ..logBreadcrumb(
        'BookingSheet opened',
        data: {
          'specialistId': specialist.id,
          'slotStart': slot.start.toIso8601String(),
        },
      );
    unawaited(cubit.acquireHold(slot));
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      builder: (_) => BlocProvider<BookingCubit>.value(
        value: cubit,
        child: BookingSheet(
          specialist: specialist,
          slot: slot,
          today: today,
        ),
      ),
    );
  }

  @override
  State<BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<BookingSheet> {
  final _nameController = TextEditingController();
  late BookingCubit _cubit;
  String? _fieldError;
  bool _hasSubmitted = false;
  bool _confirmed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cubit = context.read<BookingCubit>();
  }

  @override
  void dispose() {
    _nameController.dispose();
    if (!_confirmed) {
      unawaited(_cubit.releaseActiveHold());
    }
    super.dispose();
  }

  void _onNameChanged(String value) {
    if (!_hasSubmitted && _fieldError == null) return;
    final nextError = ClientNameValidator.validate(value);
    if (nextError != _fieldError) {
      setState(() => _fieldError = nextError);
    }
  }

  Future<void> _submit() async {
    final validationError = ClientNameValidator.validate(_nameController.text);
    setState(() {
      _hasSubmitted = true;
      _fieldError = validationError;
    });
    if (validationError != null) return;

    final success = await _cubit.bookSlot(
      slot: widget.slot,
      clientName: _nameController.text,
    );
    if (success && mounted) {
      _confirmed = true;
      context.pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
        child: BlocBuilder<BookingCubit, BookingState>(
          builder: (context, state) => _BookingSheetBody(
            specialist: widget.specialist,
            slot: widget.slot,
            today: widget.today,
            nameController: _nameController,
            fieldError: _fieldError,
            isHoldingSlot: state.isHoldingSlot,
            activeHold: state.activeHold,
            isSubmitting: state.isSubmitting,
            errorMessage: state.bookingError,
            isConflict: state.isBookingConflict,
            onNameChanged: _onNameChanged,
            onCancel: () {
              _cubit.logBreadcrumb('BookingSheet cancelled');
              context.pop(false);
            },
            onSubmit: _submit,
          ),
        ),
      ),
    );
  }
}

class _BookingSheetBody extends StatelessWidget {
  const _BookingSheetBody({
    required this.specialist,
    required this.slot,
    required this.today,
    required this.nameController,
    required this.fieldError,
    required this.isHoldingSlot,
    required this.activeHold,
    required this.isSubmitting,
    required this.errorMessage,
    required this.isConflict,
    required this.onNameChanged,
    required this.onCancel,
    required this.onSubmit,
  });

  final Specialist specialist;
  final TimeSlot slot;
  final DateTime today;
  final TextEditingController nameController;
  final String? fieldError;
  final bool isHoldingSlot;
  final Booking? activeHold;
  final bool isSubmitting;
  final String? errorMessage;
  final bool isConflict;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final busy = isHoldingSlot || isSubmitting;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Підтвердження запису',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        _BookingSummary(
          specialist: specialist,
          slot: slot,
          today: today,
          isHoldingSlot: isHoldingSlot,
          activeHold: activeHold,
        ),
        const SizedBox(height: 16),
        _ClientNameField(
          controller: nameController,
          enabled: !busy && !isConflict,
          errorText: fieldError,
          onChanged: onNameChanged,
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 12),
          _BookingErrorBanner(message: errorMessage!),
        ],
        const SizedBox(height: 16),
        _BookingActions(
          isHoldingSlot: isHoldingSlot,
          isSubmitting: isSubmitting,
          isConflict: isConflict,
          onCancel: onCancel,
          onSubmit: onSubmit,
        ),
      ],
    );
  }
}

class _BookingSummary extends StatelessWidget {
  const _BookingSummary({
    required this.specialist,
    required this.slot,
    required this.today,
    required this.isHoldingSlot,
    required this.activeHold,
  });

  final Specialist specialist;
  final TimeSlot slot;
  final DateTime today;
  final bool isHoldingSlot;
  final Booking? activeHold;

  @override
  Widget build(BuildContext context) {
    final dayText = DateTimeFormatter.fullDayLabel(slot.start, today: today);
    final start = DateTimeFormatter.time(slot.start);
    final end = DateTimeFormatter.time(slot.end);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${specialist.name} · ${specialist.service}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '$dayText, $start – $end',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            if (isHoldingSlot || activeHold != null) ...[
              const SizedBox(height: 8),
              _HoldStatusBadge(
                isHoldingSlot: isHoldingSlot,
                expiresAt: activeHold?.expiresAt,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HoldStatusBadge extends StatelessWidget {
  const _HoldStatusBadge({
    required this.isHoldingSlot,
    required this.expiresAt,
  });

  final bool isHoldingSlot;
  final DateTime? expiresAt;

  @override
  Widget build(BuildContext context) {
    final label = isHoldingSlot
        ? 'Резервування слота...'
        : expiresAt == null
            ? 'Час тимчасово зарезервовано'
            : 'Зарезервовано до ${DateTimeFormatter.time(expiresAt!)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isHoldingSlot)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            const Icon(
              Icons.lock_clock_outlined,
              size: 14,
              color: AppColors.primary,
            ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _ClientNameField extends StatelessWidget {
  const _ClientNameField({
    required this.controller,
    required this.enabled,
    required this.errorText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final String? errorText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      autofocus: true,
      textCapitalization: TextCapitalization.words,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: 'Імʼя клієнта',
        hintText: 'Наприклад, Анна',
        errorText: errorText,
        errorMaxLines: 2,
      ),
    );
  }
}

class _BookingErrorBanner extends StatelessWidget {
  const _BookingErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingActions extends StatelessWidget {
  const _BookingActions({
    required this.isHoldingSlot,
    required this.isSubmitting,
    required this.isConflict,
    required this.onCancel,
    required this.onSubmit,
  });

  final bool isHoldingSlot;
  final bool isSubmitting;
  final bool isConflict;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    if (isConflict) {
      return FilledButton(
        onPressed: onCancel,
        child: const Text('Обрати інший час'),
      );
    }

    final busy = isHoldingSlot || isSubmitting;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: isSubmitting ? null : onCancel,
            child: const Text('Скасувати'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: busy ? null : onSubmit,
            child: isSubmitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Записатися'),
          ),
        ),
      ],
    );
  }
}

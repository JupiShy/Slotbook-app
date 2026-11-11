import 'package:flutter/material.dart';

import 'package:livecoding/ui/theme/app_theme.dart';
import 'package:livecoding/ui/widgets/circle_icon_button.dart';

class BookingAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BookingAppBar({
    required this.title,
    required this.onBack,
    required this.onClose,
    super.key,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onClose;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            CircleIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Назад',
              onPressed: onBack,
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
            CircleIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Закрити',
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

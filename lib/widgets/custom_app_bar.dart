import 'package:flutter/material.dart';
import '../utils/palette.dart';
import 'notification_badge.dart';

/// A small reusable AppBar with white bold title and white back button/icon.
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool automaticallyImplyLeading;
  final Color backgroundColor;
  final bool centerTitle;
  final bool showNotifications;
  final List<Widget>? actions;

  const CustomAppBar({
    super.key,
    required this.title,
    this.automaticallyImplyLeading = true,
    this.backgroundColor = Palette.primaryDark,
    this.centerTitle = true,
    this.showNotifications = false,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: automaticallyImplyLeading,
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: backgroundColor,
      centerTitle: centerTitle,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        if (showNotifications)
          const Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: NotificationBadge(),
          ),
        if (actions != null) ...actions!,
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

import 'package:flutter/material.dart';

class UIUtils {
  static void showPremiumSnackBar(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    IconData? icon,
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final screenWidth = MediaQuery.of(context).size.width;
    final bool isWideScreen = screenWidth > 600;

    final displayIcon = icon ?? (isError ? Icons.error_outline : null);
    final displayBackgroundColor = backgroundColor ??
        (isError 
            ? Colors.red.shade800 
            : (isDark ? theme.colorScheme.primary : const Color(0xFF2C3E50)));

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (displayIcon != null) ...[
              Icon(
                displayIcon,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
            ],
            Flexible(
              child: Text(
                message,
                style: const TextStyle(fontFamily: 'Outfit', 
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: displayBackgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: duration,
        elevation: 6,
        width: isWideScreen ? 400 : null,
        margin: isWideScreen ? null : const EdgeInsets.all(20),
      ),
    );
  }

  static void showMaintenanceModeDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.build_circle_rounded, color: Colors.redAccent, size: 48),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Sistem Bakım Modunda',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Şu anda servislerimizde bakım çalışması yapılmaktadır. Lütfen daha sonra tekrar deneyiniz.\n\nServices are currently under maintenance. Please try again later.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 15, color: isDark ? Colors.grey[300] : Colors.grey[800], height: 1.4),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Tamam / OK', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget buildGlowingName(String name, {TextStyle? style}) {
    return Text(
      name,
      style: (style ?? const TextStyle()).copyWith(
        color: Colors.redAccent,
        shadows: [
          Shadow(
            color: Colors.redAccent.withValues(alpha: 0.8),
            blurRadius: 10,
          ),
          Shadow(
            color: Colors.red.withValues(alpha: 0.8),
            blurRadius: 20,
          ),
        ],
      ),
    );
  }
}

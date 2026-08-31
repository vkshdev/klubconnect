import 'dart:ui';
import 'package:flutter/material.dart';

import '../routes/app_router.dart';
import 'theme.dart';

enum SnackBarVariant {
  success,
  error,
  warning,
  info,
}

class AppSnackBar {
  static void showSuccess(
    BuildContext? context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    show(
      context,
      message: message,
      title: title,
      variant: SnackBarVariant.success,
      duration: duration,
      action: action,
    );
  }

  static void showError(
    BuildContext? context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    show(
      context,
      message: message,
      title: title,
      variant: SnackBarVariant.error,
      duration: duration,
      action: action,
    );
  }

  static void showWarning(
    BuildContext? context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    show(
      context,
      message: message,
      title: title,
      variant: SnackBarVariant.warning,
      duration: duration,
      action: action,
    );
  }

  static void showInfo(
    BuildContext? context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    show(
      context,
      message: message,
      title: title,
      variant: SnackBarVariant.info,
      duration: duration,
      action: action,
    );
  }

  static void show(
    BuildContext? context, {
    required String message,
    String? title,
    SnackBarVariant variant = SnackBarVariant.info,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    final effectiveContext = context ?? AppRouter.currentContext;
    if (effectiveContext == null) return;

    final messenger = ScaffoldMessenger.maybeOf(effectiveContext);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();

    Color accentColor;
    IconData iconData;

    switch (variant) {
      case SnackBarVariant.success:
        accentColor = AppTheme.successColor;
        iconData = Icons.check_circle_rounded;
        break;
      case SnackBarVariant.error:
        accentColor = AppTheme.errorColor;
        iconData = Icons.error_outline_rounded;
        break;
      case SnackBarVariant.warning:
        accentColor = AppTheme.warningColor;
        iconData = Icons.warning_amber_rounded;
        break;
      case SnackBarVariant.info:
        accentColor = AppTheme.primaryColor;
        iconData = Icons.info_outline_rounded;
        break;
    }

    final hasTitle = title != null && title.isNotEmpty;

    final snackBar = SnackBar(
      duration: duration,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      content: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.95),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    iconData,
                    color: accentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasTitle) ...[
                        Text(
                          title,
                          style: const TextStyle(
                            color: AppTheme.darkTextColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        message,
                        style: TextStyle(
                          color: hasTitle
                              ? AppTheme.lightTextColor
                              : AppTheme.darkTextColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      action.onPressed();
                      messenger.hideCurrentSnackBar();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: action.textColor ?? accentColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
                    child: Text(
                      action.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    messenger.showSnackBar(snackBar);
  }
}

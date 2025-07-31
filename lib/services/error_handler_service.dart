import 'dart:io';
import 'package:flutter/material.dart';
import 'windows_stability_service.dart';
import '../core/theme/app_theme.dart';

class ErrorHandlerService {
  /// Shows a user-friendly error dialog
  static void showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
    String? details,
    List<ErrorAction>? actions,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.darkText,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 14,
                color: AppTheme.darkText,
              ),
            ),
            if (details != null) ...[
              const SizedBox(height: 16),
              ExpansionTile(
                title: const Text(
                  'Technical Details',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 12,
                    color: AppTheme.mediumGray,
                  ),
                ),
                children: [
                  Text(
                    details,
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11,
                      color: AppTheme.mediumGray,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          ...?actions?.map((action) => TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              action.onPressed?.call();
            },
            child: Text(
              action.label,
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
              ),
            ),
          )),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'OK',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
                color: AppTheme.warmBrown,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Shows a simple error snackbar
  static void showErrorSnackBar(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onRetry,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 12,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.warmBrown,
        duration: duration,
        action: onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: AppTheme.creamBeige,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  /// Converts common exceptions to user-friendly messages
  static ErrorInfo processError(dynamic error) {
    String title = 'Error';
    String message = 'An unexpected error occurred.';
    String? details = error.toString();
    List<ErrorAction> actions = [];
    
    // Handle Windows-specific errors first
    if (Platform.isWindows && error.toString().isNotEmpty) {
      final windowsGuidance = WindowsStabilityService.getWindowsErrorGuidance(error.toString());
      if (windowsGuidance.isNotEmpty) {
        title = 'Windows Error';
        message = windowsGuidance;
        
        // Add Windows-specific actions
        if (error.toString().contains('dll')) {
          actions.add(ErrorAction(
            label: 'Download VC++ Redistributable',
            onPressed: () async {
              // Could open the download URL
            },
          ));
        }
        
        actions.add(ErrorAction(
          label: 'Restart in Safe Mode',
          onPressed: () async {
            await WindowsStabilityService.recordCrash();
          },
        ));
        
        return ErrorInfo(
          title: title,
          message: message,
          details: details,
          actions: actions,
        );
      }
    }

    if (error.toString().contains('DatabaseException')) {
      title = 'Database Error';
      message = 'There was a problem accessing your files. Please try again.';
      actions.add(ErrorAction(
        label: 'Retry',
        onPressed: () {
          // Could implement a retry mechanism here
        },
      ));
    } else if (error.toString().contains('FileSystemException')) {
      title = 'File System Error';
      message = 'There was a problem reading or writing files. Check your storage permissions.';
    } else if (error.toString().contains('PermissionException')) {
      title = 'Permission Error';
      message = 'The app doesn\'t have permission to access your files. Please check your settings.';
      actions.add(ErrorAction(
        label: 'Open Settings',
        onPressed: () {
          // Could open app settings here
        },
      ));
    } else if (error.toString().contains('NetworkException')) {
      title = 'Network Error';
      message = 'There was a problem with your internet connection. Please try again.';
      actions.add(ErrorAction(
        label: 'Retry',
        onPressed: () {
          // Could implement retry mechanism
        },
      ));
    } else if (error.toString().contains('ValidationException')) {
      title = 'Invalid Input';
      message = 'Please check your input and try again.';
    }

    return ErrorInfo(
      title: title,
      message: message,
      details: details,
      actions: actions,
    );
  }

  /// Handle file operation errors
  static ErrorInfo handleFileError(dynamic error, String operation) {
    String title = 'File Operation Error';
    String message = 'Failed to $operation. Please try again.';
    List<ErrorAction> actions = [];

    if (error.toString().contains('already exists')) {
      title = 'File Already Exists';
      message = 'A file with this name already exists. Please choose a different name.';
    } else if (error.toString().contains('not found')) {
      title = 'File Not Found';
      message = 'The file you\'re trying to access no longer exists.';
    } else if (error.toString().contains('permission')) {
      title = 'Permission Denied';
      message = 'You don\'t have permission to $operation this file.';
    }

    actions.add(ErrorAction(
      label: 'Try Again',
      onPressed: () {
        // Could implement retry logic
      },
    ));

    return ErrorInfo(
      title: title,
      message: message,
      details: error.toString(),
      actions: actions,
    );
  }

  /// Handle import errors
  static ErrorInfo handleImportError(dynamic error, String fileName) {
    String title = 'Import Error';
    String message = 'Failed to import "$fileName". The file may be corrupted or in an unsupported format.';
    List<ErrorAction> actions = [];

    if (error.toString().contains('format')) {
      message = 'The file "$fileName" is in an unsupported format. Only Markdown (.md) files are supported.';
    } else if (error.toString().contains('corrupted') || error.toString().contains('invalid')) {
      message = 'The file "$fileName" appears to be corrupted or invalid.';
    } else if (error.toString().contains('too large')) {
      message = 'The file "$fileName" is too large. Please choose a smaller file.';
    }

    actions.add(ErrorAction(
      label: 'Choose Different File',
      onPressed: () {
        // Could reopen file picker
      },
    ));

    return ErrorInfo(
      title: title,
      message: message,
      details: error.toString(),
      actions: actions,
    );
  }
}

class ErrorInfo {
  final String title;
  final String message;
  final String? details;
  final List<ErrorAction> actions;

  ErrorInfo({
    required this.title,
    required this.message,
    this.details,
    this.actions = const [],
  });
}

class ErrorAction {
  final String label;
  final VoidCallback? onPressed;

  ErrorAction({
    required this.label,
    this.onPressed,
  });
} 
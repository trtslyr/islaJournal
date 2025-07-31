import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

/// Service for opening URLs in the user's preferred browser
class BrowserService {
  /// Opens a URL in the user's default browser
  static Future<bool> openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // Force external browser
        );
      }
      return false;
    } catch (e) {
      debugPrint('Error opening URL: $e');
      return false;
    }
  }

  /// Opens URL with user confirmation dialog
  static Future<void> openUrlWithConfirmation(
    BuildContext context, 
    String url, 
    {String? title}
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title ?? 'Open Link'),
        content: Text('This will open in your default browser:\n\n$url'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Open Browser'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await openUrl(url);
      if (!success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open link in browser'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
} 
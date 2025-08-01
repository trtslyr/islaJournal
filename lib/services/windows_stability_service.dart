import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to handle Windows-specific stability issues and crash prevention
class WindowsStabilityService {
  static const String _crashCountKey = 'windows_crash_count';
  static const String _lastCrashTimeKey = 'windows_last_crash_time';
  static const int _maxCrashesBeforeSafeMode = 3;
  static const int _crashResetHours = 24;

  /// Check if the app should run in safe mode due to recent crashes
  static Future<bool> shouldRunInSafeMode() async {
    if (!Platform.isWindows) return false;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final crashCount = prefs.getInt(_crashCountKey) ?? 0;
      final lastCrashTime = prefs.getString(_lastCrashTimeKey);
      
      if (lastCrashTime != null) {
        final lastCrash = DateTime.parse(lastCrashTime);
        final hoursSinceLastCrash = DateTime.now().difference(lastCrash).inHours;
        
        // Reset crash count if it's been more than 24 hours
        if (hoursSinceLastCrash > _crashResetHours) {
          await _resetCrashCount();
          return false;
        }
        
        // Enable safe mode if we've had too many recent crashes
        return crashCount >= _maxCrashesBeforeSafeMode;
      }
      
      return false;
    } catch (e) {
      debugPrint('⚠️ Error checking Windows safe mode: $e');
      return false;
    }
  }

  /// Record a crash occurrence
  static Future<void> recordCrash() async {
    if (!Platform.isWindows) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final crashCount = (prefs.getInt(_crashCountKey) ?? 0) + 1;
      
      await prefs.setInt(_crashCountKey, crashCount);
      await prefs.setString(_lastCrashTimeKey, DateTime.now().toIso8601String());
      
      debugPrint('🔴 Windows crash recorded. Count: $crashCount');
      
      if (crashCount >= _maxCrashesBeforeSafeMode) {
        debugPrint('⚠️ Windows entering safe mode due to frequent crashes');
      }
    } catch (e) {
      debugPrint('⚠️ Error recording Windows crash: $e');
    }
  }

  /// Reset crash count (called after successful stable operation)
  static Future<void> _resetCrashCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_crashCountKey);
      await prefs.remove(_lastCrashTimeKey);
      debugPrint('✅ Windows crash count reset');
    } catch (e) {
      debugPrint('⚠️ Error resetting Windows crash count: $e');
    }
  }

  /// Get Windows-safe AI configuration
  static Map<String, dynamic> getSafeAIConfig() {
    return {
      'numGpuLayers': 5,           // Was 0, now allows some GPU usage
      'contextSize': 1536,         // Was 1024, now more reasonable
      'maxTokens': 100,            // Was 50, now more usable
      'temperature': 0.4,          // Was 0.3, now less restrictive
      'topP': 0.8,                 // Keep focused sampling
      'enableBatching': false,     // Keep disabled for stability
      'useF16': false,             // Use F32 for stability
    };
  }

  /// Check Windows system health before AI operations
  static Future<bool> isSystemHealthy() async {
    if (!Platform.isWindows) return true;
    
    try {
      // Check available memory
      final processResult = await Process.run(
        'wmic', 
        ['OS', 'get', 'TotalAvailableMemoryBytes', '/value'],
        runInShell: true,
      );
      
      if (processResult.exitCode == 0) {
        final output = processResult.stdout.toString();
        final memoryMatch = RegExp(r'TotalAvailableMemoryBytes=(\d+)').firstMatch(output);
        
        if (memoryMatch != null) {
          final availableBytes = int.parse(memoryMatch.group(1)!);
          final availableGB = availableBytes / (1024 * 1024 * 1024);
          
          // Require at least 2GB available memory
          if (availableGB < 2.0) {
            debugPrint('⚠️ Windows: Low memory detected: ${availableGB.toStringAsFixed(1)}GB');
            return false;
          }
        }
      }
      
      return true;
    } catch (e) {
      debugPrint('⚠️ Error checking Windows system health: $e');
      return true; // Default to healthy if check fails
    }
  }

  /// Initialize Windows stability monitoring
  static Future<void> initialize() async {
    if (!Platform.isWindows) return;
    
    debugPrint('🔧 Initializing Windows stability service...');
    
    final inSafeMode = await shouldRunInSafeMode();
    if (inSafeMode) {
      debugPrint('⚠️ Windows running in SAFE MODE due to recent crashes');
    }
    
    // Check system health
    final healthy = await isSystemHealthy();
    if (!healthy) {
      debugPrint('⚠️ Windows system health check failed');
    }
  }

  /// Handle Windows-specific error scenarios
  static String getWindowsErrorGuidance(String error) {
    if (error.contains('dll')) {
      return 'Windows DLL Error: Please install Microsoft Visual C++ Redistributable from https://aka.ms/vs/17/release/vc_redist.x64.exe';
    } else if (error.contains('memory') || error.contains('allocation')) {
      return 'Windows Memory Error: Close other applications and restart Isla Journal';
    } else if (error.contains('gpu') || error.contains('driver')) {
      return 'Windows GPU Error: Update your graphics drivers or run in CPU-only mode';
    } else if (error.contains('permission') || error.contains('access')) {
      return 'Windows Permission Error: Run as administrator or check antivirus settings';
    } else {
      return 'Windows Error: Restart the application. If this persists, run in safe mode';
    }
  }

  /// Mark successful operation (helps reset crash counter over time)
  static Future<void> markSuccessfulOperation() async {
    if (!Platform.isWindows) return;
    
    // After 10 successful operations, consider resetting crash count
    try {
      final prefs = await SharedPreferences.getInstance();
      final successCount = (prefs.getInt('windows_success_count') ?? 0) + 1;
      await prefs.setInt('windows_success_count', successCount);
      
      if (successCount >= 10) {
        await _resetCrashCount();
        await prefs.remove('windows_success_count');
        debugPrint('✅ Windows stability restored after successful operations');
      }
    } catch (e) {
      debugPrint('⚠️ Error marking Windows success: $e');
    }
  }
} 
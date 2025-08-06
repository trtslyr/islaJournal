import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to handle Windows-specific stability issues and crash prevention
class WindowsStabilityService {
  static const String _crashCountKey = 'windows_crash_count';
  static const String _lastCrashTimeKey = 'windows_last_crash_time';
  static const String _nativeCrashCountKey = 'windows_native_crash_count';
  static const String _lastNativeCrashKey = 'windows_last_native_crash';
  static const String _crashDetailsKey = 'windows_crash_details';
  static const int _maxCrashesBeforeSafeMode = 3;
  static const int _crashResetHours = 24;

  /// Check if the app should run in safe mode due to recent crashes
  static Future<bool> shouldRunInSafeMode() async {
    if (!Platform.isWindows) return false;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final crashCount = prefs.getInt(_crashCountKey) ?? 0;
      final nativeCrashCount = prefs.getInt(_nativeCrashCountKey) ?? 0;
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
        final totalCrashes = crashCount + (nativeCrashCount * 2); // Weight native crashes more
        return totalCrashes >= _maxCrashesBeforeSafeMode;
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

  /// Record a native library crash with details
  static Future<void> recordNativeCrash({
    required String operation,
    String? modelPath,
    String? errorDetails,
    Map<String, dynamic>? parameters,
  }) async {
    if (!Platform.isWindows) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final nativeCrashCount = (prefs.getInt(_nativeCrashCountKey) ?? 0) + 1;
      
      // Store crash details
      final crashDetails = {
        'timestamp': DateTime.now().toIso8601String(),
        'operation': operation,
        'modelPath': modelPath,
        'errorDetails': errorDetails,
        'parameters': parameters,
        'crashCount': nativeCrashCount,
      };
      
      await prefs.setInt(_nativeCrashCountKey, nativeCrashCount);
      await prefs.setString(_lastNativeCrashKey, DateTime.now().toIso8601String());
      await prefs.setString(_crashDetailsKey, crashDetails.toString());
      
      debugPrint('💥 Native crash recorded:');
      debugPrint('   Operation: $operation');
      debugPrint('   Model: $modelPath');
      debugPrint('   Details: $errorDetails');
      debugPrint('   Count: $nativeCrashCount');
      
      // Also record a regular crash
      await recordCrash();
      
    } catch (e) {
      debugPrint('⚠️ Error recording native crash: $e');
    }
  }

  /// Get diagnostic information for troubleshooting
  static Future<Map<String, dynamic>> getDiagnosticInfo() async {
    if (!Platform.isWindows) return {};
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      return {
        'totalCrashes': prefs.getInt(_crashCountKey) ?? 0,
        'nativeCrashes': prefs.getInt(_nativeCrashCountKey) ?? 0,
        'lastCrash': prefs.getString(_lastCrashTimeKey),
        'lastNativeCrash': prefs.getString(_lastNativeCrashKey),
        'inSafeMode': await shouldRunInSafeMode(),
        'crashDetails': prefs.getString(_crashDetailsKey),
        'systemInfo': await _getSystemInfo(),
      };
    } catch (e) {
      debugPrint('⚠️ Error getting diagnostic info: $e');
      return {'error': e.toString()};
    }
  }

  /// Print comprehensive diagnostic information
  static Future<void> printDiagnostics() async {
    if (!Platform.isWindows) return;
    
    final info = await getDiagnosticInfo();
    
    debugPrint('🔍 WINDOWS DIAGNOSTIC REPORT:');
    debugPrint('   Total crashes: ${info['totalCrashes']}');
    debugPrint('   Native crashes: ${info['nativeCrashes']}');
    debugPrint('   Safe mode: ${info['inSafeMode']}');
    debugPrint('   Last crash: ${info['lastCrash']}');
    debugPrint('   Last native crash: ${info['lastNativeCrash']}');
    debugPrint('   System info: ${info['systemInfo']}');
    debugPrint('   Recent crash details: ${info['crashDetails']}');
  }

  /// Get basic system information
  static Future<Map<String, dynamic>> _getSystemInfo() async {
    try {
      // Get available memory
      final memResult = await Process.run(
        'wmic', 
        ['OS', 'get', 'TotalAvailableMemoryBytes', '/value'],
        runInShell: true,
      );
      
      // Get CPU info
      final cpuResult = await Process.run(
        'wmic', 
        ['cpu', 'get', 'name', '/value'],
        runInShell: true,
      );
      
      return {
        'memoryOutput': memResult.stdout.toString(),
        'cpuOutput': cpuResult.stdout.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Pre-operation safety check with detailed logging
  static Future<bool> preOperationSafetyCheck({
    required String operation,
    String? modelPath,
    Map<String, dynamic>? parameters,
  }) async {
    if (!Platform.isWindows) return true;
    
    debugPrint('🛡️ Pre-operation safety check for: $operation');
    
    try {
      // 1. Check if in safe mode
      final inSafeMode = await shouldRunInSafeMode();
      if (inSafeMode) {
        debugPrint('⚠️ SAFE MODE: Operation $operation restricted');
        return false;
      }
      
      // 2. Check system health
      final healthy = await isSystemHealthy();
      if (!healthy) {
        debugPrint('⚠️ SYSTEM UNHEALTHY: Operation $operation restricted');
        return false;
      }
      
      // 3. Check if model file is accessible (if provided)
      if (modelPath != null) {
        final modelFile = File(modelPath);
        if (!await modelFile.exists()) {
          debugPrint('❌ Model file not accessible: $modelPath');
          return false;
        }
      }
      
      // 4. Log operation attempt
      debugPrint('✅ Safety check passed for: $operation');
      await _logOperationAttempt(operation, parameters);
      
      return true;
      
    } catch (e) {
      debugPrint('❌ Safety check failed: $e');
      return false;
    }
  }

  /// Log operation attempt for debugging
  static Future<void> _logOperationAttempt(String operation, Map<String, dynamic>? parameters) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final attempts = prefs.getStringList('operation_attempts') ?? [];
      
      final logEntry = {
        'timestamp': DateTime.now().toIso8601String(),
        'operation': operation,
        'parameters': parameters?.toString() ?? 'none',
      }.toString();
      
      attempts.add(logEntry);
      
      // Keep only last 10 attempts
      if (attempts.length > 10) {
        attempts.removeRange(0, attempts.length - 10);
      }
      
      await prefs.setStringList('operation_attempts', attempts);
      
    } catch (e) {
      debugPrint('⚠️ Failed to log operation attempt: $e');
    }
  }

  /// Reset crash count (called after successful stable operation)
  static Future<void> _resetCrashCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_crashCountKey);
      await prefs.remove(_lastCrashTimeKey);
      await prefs.remove(_nativeCrashCountKey);
      await prefs.remove(_lastNativeCrashKey);
      await prefs.remove(_crashDetailsKey);
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
          
          debugPrint('💾 Available memory: ${availableGB.toStringAsFixed(1)}GB');
          
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
    
    // Print diagnostics on startup
    await printDiagnostics();
    
    final inSafeMode = await shouldRunInSafeMode();
    if (inSafeMode) {
      debugPrint('⚠️ Windows running in SAFE MODE due to recent crashes');
    }
    
    // Check system health
    final healthy = await isSystemHealthy();
    if (!healthy) {
      debugPrint('⚠️ Windows system health check failed');
    }
    
    debugPrint('✅ Windows stability service initialized');
  }

  /// Handle Windows-specific error scenarios
  static String getWindowsErrorGuidance(String error) {
    if (error.contains('dll') || error.contains('library')) {
      return 'Windows DLL Error: Install Microsoft Visual C++ Redistributable from https://aka.ms/vs/17/release/vc_redist.x64.exe and restart.';
    } else if (error.contains('memory') || error.contains('allocation') || error.contains('insufficient')) {
      return 'Windows Memory Error: Close other applications, restart Isla Journal, or use a smaller AI model.';
    } else if (error.contains('gpu') || error.contains('driver') || error.contains('graphics')) {
      return 'Windows GPU Error: Update your graphics drivers or the app will automatically use CPU-only mode.';
    } else if (error.contains('permission') || error.contains('access') || error.contains('denied')) {
      return 'Windows Permission Error: Run as administrator or check antivirus settings.';
    } else if (error.contains('timeout') || error.contains('took too long')) {
      return 'Windows Timeout: The AI took too long. The app will use faster settings automatically.';
    } else if (error.contains('already completed') || error.contains('race condition')) {
      return 'Windows Threading Issue: Restart the app - this has been fixed in the latest version.';
    } else if (error.contains('native') || error.contains('fllama') || error.contains('model')) {
      return 'Windows Native Library Issue: The AI model encountered a problem. Try reloading the model or restart the app.';
    } else {
      return 'Windows Error: Restart the application. If problems persist, the app will automatically enter safe mode.';
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
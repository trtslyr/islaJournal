import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

// License Types
enum LicenseType {
  none,
  trial,
  lifetime,
  subscription,
}

// License Status Model
class LicenseStatus {
  final LicenseType type;
  final bool isValid;
  final String? customerName;
  final String? planType; // monthly, annual
  final DateTime? expiresAt;
  final DateTime? grantedAt;
  final DateTime? lastValidated;
  final int? trialHoursRemaining;
  final String? stripeCustomerId;
  final bool neverExpires;

  LicenseStatus({
    required this.type,
    required this.isValid,
    this.customerName,
    this.planType,
    this.expiresAt,
    this.grantedAt,
    this.lastValidated,
    this.trialHoursRemaining,
    this.stripeCustomerId,
    this.neverExpires = false,
  });

  bool get isLifetime => type == LicenseType.lifetime;
  bool get isSubscription => type == LicenseType.subscription;
  bool get isTrial => type == LicenseType.trial;

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'isValid': isValid,
      'customerName': customerName,
      'planType': planType,
      'expiresAt': expiresAt?.toIso8601String(),
      'grantedAt': grantedAt?.toIso8601String(),
      'lastValidated': lastValidated?.toIso8601String(),
      'trialHoursRemaining': trialHoursRemaining,
      'stripeCustomerId': stripeCustomerId,
      'neverExpires': neverExpires,
    };
  }

  static LicenseStatus fromJson(Map<String, dynamic> json) {
    return LicenseStatus(
      type: LicenseType.values.firstWhere((e) => e.name == json['type']),
      isValid: json['isValid'] ?? false,
      customerName: json['customerName'],
      planType: json['planType'],
      expiresAt: json['expiresAt'] != null ? DateTime.parse(json['expiresAt']) : null,
      grantedAt: json['grantedAt'] != null ? DateTime.parse(json['grantedAt']) : null,
      lastValidated: json['lastValidated'] != null ? DateTime.parse(json['lastValidated']) : null,
      trialHoursRemaining: json['trialHoursRemaining'],
      stripeCustomerId: json['stripeCustomerId'],
      neverExpires: json['neverExpires'] ?? false,
    );
  }
}

class LicenseService {
  static const String baseUrl = 'https://islajournalbackend-production.up.railway.app';
  static const _storage = FlutterSecureStorage();
  
  // Storage keys
  static const String _licenseStatusKey = 'license_status';
  static const String _licenseKeyKey = 'license_key';
  static const String _subscriptionKeyKey = 'subscription_key';
  static const String _deviceIdKey = 'device_id';
  static const String _trialStartKey = 'trial_start';

  /// Main license check - smart validation based on license type
  Future<LicenseStatus> checkLicense() async {
    debugPrint('🔍 Checking license status...');
    
    try {
      // 1. Check for cached license status
      final cachedStatus = await _getCachedLicenseStatus();
      
      if (cachedStatus != null) {
        // 2. Determine if we need to validate online
        if (_shouldValidateOnline(cachedStatus)) {
          debugPrint('📡 Online validation required');
          return await _validateOnlineAndCache(cachedStatus);
        } else {
          debugPrint('💾 Using cached license (still valid)');
          return cachedStatus;
        }
      }
      
      // 3. No cached license - check for lifetime key
      final lifetimeKey = await _getStoredLifetimeKey();
      if (lifetimeKey != null) {
        debugPrint('🔑 Found stored lifetime key, validating...');
        return await validateLifetimeKey(lifetimeKey);
      }
      
      // 4. Check for subscription key
      final subscriptionKey = await _getStoredSubscriptionKey();
      if (subscriptionKey != null) {
        debugPrint('🔑 Found stored subscription key, validating...');
        return await validateSubscriptionKey(subscriptionKey);
      }
      
      // 5. Fall back to trial
      return await _handleTrialLogic();
      
    } catch (e) {
      debugPrint('❌ License check error: $e');
      // Return cached status if available, otherwise trial
      final cachedStatus = await _getCachedLicenseStatus();
      return cachedStatus ?? await _handleTrialLogic();
    }
  }

  /// Validate lifetime license key
  Future<LicenseStatus> validateLifetimeKey(String licenseKey) async {
    try {
      debugPrint('🔑 Validating lifetime key online...');
      
      final response = await http.post(
        Uri.parse('$baseUrl/validate-lifetime-key'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'license_key': licenseKey}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['valid'] == true) {
          debugPrint('✅ Online lifetime validation successful');
          
          // Store the key securely
          await _storeLifetimeKey(licenseKey);
          
          final status = LicenseStatus(
            type: LicenseType.lifetime,
            isValid: true,
            customerName: data['customer_name'],
            grantedAt: data['granted_at'] != null ? DateTime.parse(data['granted_at']) : null,
            lastValidated: DateTime.now(),
            neverExpires: true,
          );
          
          // Cache the status - lifetime keys are valid forever
          await _cacheLicenseStatus(status);
          
          return status;
        }
      }
      
      return LicenseStatus(type: LicenseType.none, isValid: false);
    } catch (e) {
      debugPrint('❌ Lifetime key validation error: $e');
      return LicenseStatus(type: LicenseType.none, isValid: false);
    }
  }

  /// Validate subscription license key (monthly/annual)
  Future<LicenseStatus> validateSubscriptionKey(String licenseKey) async {
    try {
      debugPrint('🔑 Validating subscription key online...');
      
      final response = await http.post(
        Uri.parse('$baseUrl/validate-subscription-key'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'license_key': licenseKey}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['valid'] == true) {
          debugPrint('✅ Online subscription validation successful');
          
          // Store the key securely
          await _storeSubscriptionKey(licenseKey);
          
          final status = LicenseStatus(
            type: LicenseType.subscription,
            isValid: true,
            planType: data['plan_type'],
            expiresAt: data['expires_at'] != null ? DateTime.parse(data['expires_at']) : null,
            stripeCustomerId: data['stripe_customer_id'],
            lastValidated: DateTime.now(),
          );
          
          // Cache the status
          await _cacheLicenseStatus(status);
          
          return status;
        }
      }
      
      return LicenseStatus(type: LicenseType.none, isValid: false);
    } catch (e) {
      debugPrint('❌ Subscription key validation error: $e');
      return LicenseStatus(type: LicenseType.none, isValid: false);
    }
  }

  /// Create Stripe checkout session
  Future<Map<String, dynamic>> createCheckoutSession(String planType) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/create-checkout-session'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'plan_type': planType,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      
      throw Exception('Failed to create checkout session');
    } catch (e) {
      debugPrint('❌ Checkout session error: $e');
      rethrow;
    }
  }

  /// Get customer portal URL
  Future<String?> getCustomerPortalUrl() async {
    try {
      // Try to get subscription key first
      final subscriptionKey = await _getStoredSubscriptionKey();
      if (subscriptionKey == null) {
        debugPrint('❌ No subscription key found for customer portal');
        return null;
      }
      
      final response = await http.post(
        Uri.parse('$baseUrl/customer-portal'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'license_key': subscriptionKey}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['url'];
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ Customer portal error: $e');
      return null;
    }
  }

  /// Clear all license data (for testing)
  Future<void> clearLicenseData() async {
    await _storage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_licenseStatusKey);
    await prefs.remove(_licenseKeyKey);
    await prefs.remove(_subscriptionKeyKey);
    await prefs.remove(_trialStartKey);
  }

  /// Reset trial (for testing)
  Future<void> resetTrialForTesting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_trialStartKey);
    await prefs.remove(_licenseStatusKey);
  }

  // Private helper methods

  /// Determine if we need to validate online based on license type
  bool _shouldValidateOnline(LicenseStatus status) {
    final now = DateTime.now();
    final lastValidated = status.lastValidated ?? DateTime(2000);
    
    switch (status.type) {
      case LicenseType.lifetime:
        // Lifetime keys: NEVER validate again after first success
        return false;
        
      case LicenseType.subscription:
        if (status.planType == 'monthly') {
          // Monthly: validate on monthly anniversary
          return _shouldValidateOnAnniversary(status, 30);
        } else if (status.planType == 'annual') {
          // Annual: validate on annual anniversary  
          return _shouldValidateOnAnniversary(status, 365);
        }
        return now.difference(lastValidated).inDays > 7; // Default weekly
        
      case LicenseType.trial:
        // Trial: validate every 24 hours
        return now.difference(lastValidated).inHours > 24;
        
      case LicenseType.none:
        return true;
    }
  }

  /// Check if we should validate based on anniversary date
  bool _shouldValidateOnAnniversary(LicenseStatus status, int dayInterval) {
    final now = DateTime.now();
    final lastValidated = status.lastValidated ?? DateTime(2000);
    final daysSinceValidation = now.difference(lastValidated).inDays;
    
    // Validate if more than the interval has passed
    return daysSinceValidation >= dayInterval;
  }

  /// Validate online and update cache
  Future<LicenseStatus> _validateOnlineAndCache(LicenseStatus cachedStatus) async {
    try {
      if (cachedStatus.type == LicenseType.lifetime) {
        // Re-validate lifetime key
        final lifetimeKey = await _getStoredLifetimeKey();
        if (lifetimeKey != null) {
          return await validateLifetimeKey(lifetimeKey);
        }
      } else if (cachedStatus.type == LicenseType.subscription) {
        // Re-validate subscription
        final subscriptionKey = await _getStoredSubscriptionKey();
        if (subscriptionKey != null) {
          return await validateSubscriptionKey(subscriptionKey);
        }
      }
      
      // If validation fails, return cached status if still within grace period
      final now = DateTime.now();
      final lastValidated = cachedStatus.lastValidated ?? DateTime(2000);
      
      if (now.difference(lastValidated).inDays < 7) {
        debugPrint('⚠️ Online validation failed, using cached status (grace period)');
        return cachedStatus;
      }
      
      // Grace period expired
      return LicenseStatus(type: LicenseType.none, isValid: false);
      
    } catch (e) {
      debugPrint('❌ Online validation error: $e');
      return cachedStatus; // Return cached on error
    }
  }

  /// Handle trial logic
  Future<LicenseStatus> _handleTrialLogic() async {
    final prefs = await SharedPreferences.getInstance();
    final trialStartStr = prefs.getString(_trialStartKey);
    
    DateTime trialStart;
    if (trialStartStr != null) {
      trialStart = DateTime.parse(trialStartStr);
    } else {
      // Start new trial
      trialStart = DateTime.now();
      await prefs.setString(_trialStartKey, trialStart.toIso8601String());
      debugPrint('🆕 Starting new 24-hour trial');
    }
    
    final now = DateTime.now();
    final trialHours = 24;
    final hoursElapsed = now.difference(trialStart).inHours;
    final hoursRemaining = trialHours - hoursElapsed;
    
    final isValid = hoursRemaining > 0;
    
    final status = LicenseStatus(
      type: LicenseType.trial,
      isValid: isValid,
      trialHoursRemaining: hoursRemaining > 0 ? hoursRemaining : 0,
      lastValidated: now,
    );
    
    await _cacheLicenseStatus(status);
    return status;
  }

  /// Cache license status
  Future<void> _cacheLicenseStatus(LicenseStatus status) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_licenseStatusKey, jsonEncode(status.toJson()));
    } catch (e) {
      debugPrint('❌ Error caching license status: $e');
    }
  }

  /// Get cached license status
  Future<LicenseStatus?> _getCachedLicenseStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_licenseStatusKey);
      
      if (cachedJson != null) {
        final data = jsonDecode(cachedJson);
        return LicenseStatus.fromJson(data);
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ Error loading cached license status: $e');
      return null;
    }
  }

  /// Store lifetime key securely
  Future<void> _storeLifetimeKey(String licenseKey) async {
    try {
      await _storage.write(key: _licenseKeyKey, value: licenseKey);
      debugPrint('✅ License key stored securely');
    } catch (e) {
      debugPrint('Warning: Could not store license key in keychain: $e');
      // Fallback to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_licenseKeyKey, licenseKey);
      debugPrint('✅ License key stored in SharedPreferences fallback');
    }
  }

  /// Store subscription key securely
  Future<void> _storeSubscriptionKey(String licenseKey) async {
    try {
      await _storage.write(key: _subscriptionKeyKey, value: licenseKey);
      debugPrint('✅ Subscription key stored securely');
    } catch (e) {
      debugPrint('Warning: Could not store subscription key in keychain: $e');
      // Fallback to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_subscriptionKeyKey, licenseKey);
      debugPrint('✅ Subscription key stored in SharedPreferences fallback');
    }
  }

  /// Get stored lifetime key
  Future<String?> _getStoredLifetimeKey() async {
    try {
      // Try secure storage first
      final key = await _storage.read(key: _licenseKeyKey);
      if (key != null) return key;
      
      // Fallback to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_licenseKeyKey);
    } catch (e) {
      debugPrint('❌ Error loading stored license key: $e');
      return null;
    }
  }

  /// Get stored subscription key
  Future<String?> _getStoredSubscriptionKey() async {
    try {
      // Try secure storage first
      final key = await _storage.read(key: _subscriptionKeyKey);
      if (key != null) return key;
      
      // Fallback to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_subscriptionKeyKey);
    } catch (e) {
      debugPrint('❌ Error loading stored subscription key: $e');
      return null;
    }
  }

  /// Generate unique device ID
  Future<String> _getDeviceId() async {
    try {
      // Try to get cached device ID first
      String? deviceId = await _storage.read(key: _deviceIdKey);
      if (deviceId != null) return deviceId;
      
      // Generate new device ID based on platform
      final deviceInfo = DeviceInfoPlugin();
      String uniqueId;
      
      if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        uniqueId = '${iosInfo.name}_${iosInfo.identifierForVendor}_${iosInfo.model}';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        uniqueId = '${androidInfo.device}_${androidInfo.id}_${androidInfo.model}';
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        uniqueId = '${macInfo.computerName}_${macInfo.systemGUID}';
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        uniqueId = '${windowsInfo.computerName}_${windowsInfo.numberOfCores}_${windowsInfo.systemMemoryInMegabytes}';
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        uniqueId = '${linuxInfo.machineId}_${linuxInfo.variant}';
      } else {
        uniqueId = 'unknown_${DateTime.now().millisecondsSinceEpoch}';
      }
      
      // Hash the unique ID for privacy
      final bytes = utf8.encode(uniqueId);
      final digest = sha256.convert(bytes);
      deviceId = digest.toString();
      
      // Cache the device ID
      await _storage.write(key: _deviceIdKey, value: deviceId);
      
      return deviceId;
    } catch (e) {
      debugPrint('❌ Error generating device ID: $e');
      // Fallback to timestamp-based ID
      return 'fallback_${DateTime.now().millisecondsSinceEpoch}';
    }
  }
} 
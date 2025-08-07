import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';  // Removed for simpler Windows deployment
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

// License Types
enum LicenseType {
  none,
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
    this.stripeCustomerId,
    this.neverExpires = false,
  });

  bool get isLifetime => type == LicenseType.lifetime;
  bool get isSubscription => type == LicenseType.subscription;

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'isValid': isValid,
      'customerName': customerName,
      'planType': planType,
      'expiresAt': expiresAt?.toIso8601String(),
      'grantedAt': grantedAt?.toIso8601String(),
      'lastValidated': lastValidated?.toIso8601String(),
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
      expiresAt:
          json['expiresAt'] != null ? DateTime.parse(json['expiresAt']) : null,
      grantedAt:
          json['grantedAt'] != null ? DateTime.parse(json['grantedAt']) : null,
      lastValidated: json['lastValidated'] != null
          ? DateTime.parse(json['lastValidated'])
          : null,
      stripeCustomerId: json['stripeCustomerId'],
      neverExpires: json['neverExpires'] ?? false,
    );
  }
}

class LicenseService {
  static const String baseUrl =
      'https://islajournalbackend-production.up.railway.app';
  // static const _storage = FlutterSecureStorage();  // Removed for simpler Windows deployment

  // Storage keys
  static const String _licenseStatusKey = 'license_status';
  static const String _licenseKeyKey = 'license_key';
  static const String _deviceIdKey = 'device_id';

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

      // 4. Check for stored subscription key
      final subscriptionKey = await _getStoredSubscriptionKey();
      if (subscriptionKey != null) {
        debugPrint('🔑 Found stored subscription key, validating...');
        final subscriptionStatus =
            await validateSubscriptionKey(subscriptionKey);
        if (subscriptionStatus.isValid) {
          await _cacheLicenseStatus(subscriptionStatus);
          return subscriptionStatus;
        }
      }

      // 5. No valid license found - return none
      return LicenseStatus(type: LicenseType.none, isValid: false);
    } catch (e) {
      debugPrint('❌ License check error: $e');
      // Return cached status if available, otherwise none
      final cachedStatus = await _getCachedLicenseStatus();
      return cachedStatus ??
          LicenseStatus(type: LicenseType.none, isValid: false);
    }
  }

  /// Validate subscription license key (monthly/annual)
  Future<LicenseStatus> validateSubscriptionKey(String licenseKey) async {
    try {
      debugPrint('🔑 Validating subscription key online...');
      debugPrint('🌐 Calling: $baseUrl/validate-subscription-key');
      debugPrint('📝 Key: ${licenseKey.substring(0, 10)}...');

      final response = await http.post(
        Uri.parse('$baseUrl/validate-subscription-key'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'license_key': licenseKey}),
      );

      debugPrint('📡 Response status: ${response.statusCode}');
      debugPrint('📡 Response body: ${response.body}');

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
            expiresAt: data['expires_at'] != null
                ? DateTime.parse(data['expires_at'])
                : null,
            stripeCustomerId: data['stripe_customer_id'],
            lastValidated: DateTime.now(),
          );

          // Cache the status
          await _cacheLicenseStatus(status);

          return status;
        } else {
          debugPrint('❌ Backend says key is invalid: ${data['reason']}');
        }
      } else {
        debugPrint('❌ HTTP error: ${response.statusCode}');
      }

      return LicenseStatus(type: LicenseType.none, isValid: false);
    } catch (e) {
      debugPrint('❌ Subscription key validation error: $e');
      return LicenseStatus(type: LicenseType.none, isValid: false);
    }
  }

  /// Validate lifetime license key
  Future<LicenseStatus> validateLifetimeKey(String licenseKey) async {
    try {
      debugPrint('');
      debugPrint('🔑🔑🔑 ISLA JOURNAL LICENSE VALIDATION 🔑🔑🔑');
      debugPrint('🌐 Backend URL: $baseUrl');
      debugPrint('📝 License Key: ${licenseKey.substring(0, 10)}...');
      debugPrint('🖥️ Platform: ${Platform.operatingSystem}');
      debugPrint('📱 Key length: ${licenseKey.length}');
      debugPrint('⏰ Timestamp: ${DateTime.now()}');

      final startTime = DateTime.now();
      debugPrint('🚀 Starting HTTP request to backend...');

      final response = await http.post(
        Uri.parse('$baseUrl/validate-lifetime-key'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'IslaJournal/1.0',
        },
        body: jsonEncode({'license_key': licenseKey}),
      ).timeout(Duration(seconds: 15));

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint('⏱️ Request completed in ${duration}ms');
      debugPrint('📡 HTTP Status: ${response.statusCode}');
      debugPrint('📄 Response headers: ${response.headers}');
      debugPrint('📝 Response body: ${response.body}');

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
            grantedAt: data['granted_at'] != null
                ? DateTime.parse(data['granted_at'])
                : null,
            lastValidated: DateTime.now(),
            neverExpires: true,
          );

          // Cache the status - lifetime keys are valid forever
          await _cacheLicenseStatus(status);

          return status;
        } else {
          debugPrint('❌ Backend says key is invalid: ${data['reason']}');
        }
      } else {
        debugPrint('❌ HTTP error: ${response.statusCode}');
      }

      return LicenseStatus(type: LicenseType.none, isValid: false);
    } catch (e) {
      debugPrint('');
      debugPrint('💥💥💥 LICENSE VALIDATION EXCEPTION 💥💥💥');
      debugPrint('🔥 Error type: ${e.runtimeType}');
      debugPrint('🔥 Error message: $e');
      debugPrint('🔥 Backend URL: $baseUrl');
      
      if (e.toString().contains('Connection refused')) {
        debugPrint('💡 Suggestion: Backend server may not be running');
      } else if (e.toString().contains('TimeoutException')) {
        debugPrint('💡 Suggestion: Backend timeout - check internet connection');
      } else if (e.toString().contains('SocketException')) {
        debugPrint('💡 Suggestion: Network connectivity issue');
      }
      
      return LicenseStatus(type: LicenseType.none, isValid: false);
    }
  }

  /// Create Stripe checkout session (no device ID needed)
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

  /// Get customer portal URL (works for both lifetime and subscription licenses)
  Future<String?> getCustomerPortalUrl() async {
    try {
      // First try subscription key
      final subscriptionKey = await _getStoredSubscriptionKey();
      if (subscriptionKey != null) {
        final response = await http.post(
          Uri.parse('$baseUrl/customer-portal'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'license_key': subscriptionKey}),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['portal_url'];
        }
      }

      // If subscription doesn't work, try lifetime key
      final lifetimeKey = await _getStoredLifetimeKey();
      if (lifetimeKey != null) {
        final response = await http.post(
          Uri.parse('$baseUrl/customer-portal'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'license_key': lifetimeKey}),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['portal_url'];
        }
        
        // Handle legacy lifetime licenses
        if (response.statusCode == 404) {
          final errorData = jsonDecode(response.body);
          if (errorData['legacy'] == true) {
            debugPrint('ℹ️ Legacy lifetime license detected - directing to direct portal');
            // Return the direct Stripe portal URL for legacy customers
            return 'https://billing.stripe.com/p/login/cNieVc50A7yGfkv4BQ73G00';
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('❌ Customer portal error: $e');
      return null;
    }
  }

  /// Clear all license data
  Future<void> clearLicenseData() async {
    debugPrint('🧹 LicenseService: Clearing all license data...');

    // Clear all secure storage (now skipped since we don't use it)
    debugPrint('✅ Secure storage cleared (skipped - using SharedPreferences only)');

    // Clear all SharedPreferences license-related keys
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_licenseStatusKey); // Cached license status
    await prefs.remove(_licenseKeyKey); // 'license_key' for lifetime keys
    await prefs.remove('subscription_key'); // Subscription keys
    await prefs.remove(_deviceIdKey); // Device ID

    // Clear any legacy keys that might exist
    await prefs.remove('license_type');
    await prefs.remove('license_valid');
    await prefs.remove('trial_start');
    await prefs.remove('trial_start_time');

    debugPrint('✅ All license data cleared from storage');
  }

  // Private helper methods

  /// Determine if we need to validate online based on license type
  bool _shouldValidateOnline(LicenseStatus status) {
    final now = DateTime.now();
    final lastValidated = status.lastValidated ?? DateTime(2000);

    switch (status.type) {
      case LicenseType.lifetime:
        // Lifetime keys: NEVER validate again after first successful validation
        return false;

      case LicenseType.subscription:
        if (status.planType == 'monthly') {
          // Monthly: validate every 30 days
          return now.difference(lastValidated).inDays > 30;
        } else if (status.planType == 'annual') {
          // Annual: validate every 365 days
          return now.difference(lastValidated).inDays > 365;
        }
        // Default: validate weekly for unknown subscription types
        return now.difference(lastValidated).inDays > 7;

      case LicenseType.none:
        return true;
    }
  }

  /// Check if we should validate based on anniversary date (payment date)
  bool _shouldValidateOnAnniversary(LicenseStatus status, int intervalDays) {
    final now = DateTime.now();
    final lastValidated = status.lastValidated ?? DateTime(2000);

    // If we have an expiration date, use it to calculate the payment cycle
    if (status.expiresAt != null) {
      final expiresAt = status.expiresAt!;

      // Calculate when the next validation should occur
      // For monthly: 30 days before expiration (around payment date)
      // For annual: 365 days before expiration (around payment date)
      final validationWindow = expiresAt.subtract(Duration(days: intervalDays));

      // Only validate if we're past the validation window AND haven't validated recently
      return now.isAfter(validationWindow) &&
          now.difference(lastValidated).inDays >
              (intervalDays - 5); // 5-day buffer
    }

    // Fallback: if no expiration date, use simple time-based validation
    return now.difference(lastValidated).inDays > intervalDays;
  }

  /// Validate online and update cache
  Future<LicenseStatus> _validateOnlineAndCache(
      LicenseStatus cachedStatus) async {
    try {
      if (cachedStatus.type == LicenseType.lifetime) {
        // Re-validate lifetime key
        final lifetimeKey = await _getStoredLifetimeKey();
        if (lifetimeKey != null) {
          return await validateLifetimeKey(lifetimeKey);
        }
      } else if (cachedStatus.type == LicenseType.subscription) {
        // Re-validate subscription key
        final subscriptionKey = await _getStoredSubscriptionKey();
        if (subscriptionKey != null) {
          return await validateSubscriptionKey(subscriptionKey);
        }
      }

      // If validation fails, return cached status if still within grace period
      final now = DateTime.now();
      final lastValidated = cachedStatus.lastValidated ?? DateTime(2000);

      if (now.difference(lastValidated).inDays < 7) {
        debugPrint(
            '⚠️ Online validation failed, using cached status (grace period)');
        return cachedStatus;
      }

      // Grace period expired
      return LicenseStatus(type: LicenseType.none, isValid: false);
    } catch (e) {
      debugPrint('❌ Online validation error: $e');
      return cachedStatus; // Return cached on error
    }
  }

  /// Check device subscription with Stripe
  Future<LicenseStatus> _checkDeviceSubscription(String deviceId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/check-device-license'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'device_id': deviceId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['licensed'] == true) {
          return LicenseStatus(
            type: LicenseType.subscription,
            isValid: true,
            planType: data['plan_type'],
            expiresAt: data['expires_at'] != null
                ? DateTime.parse(data['expires_at'])
                : null,
            stripeCustomerId: data['stripe_customer_id'],
            lastValidated: DateTime.now(),
          );
        }
      }

      return LicenseStatus(type: LicenseType.none, isValid: false);
    } catch (e) {
      debugPrint('❌ Device subscription check error: $e');
      return LicenseStatus(type: LicenseType.none, isValid: false);
    }
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

  /// Store lifetime key 
  Future<void> _storeLifetimeKey(String licenseKey) async {
    // Use SharedPreferences directly for simpler Windows deployment
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_licenseKeyKey, licenseKey);
    debugPrint('✅ License key stored in SharedPreferences');
  }

  /// Get stored lifetime key
  Future<String?> _getStoredLifetimeKey() async {
    try {
      // Use SharedPreferences directly for simpler Windows deployment
      final prefs = await SharedPreferences.getInstance();
      final storedKey = prefs.getString(_licenseKeyKey);
      debugPrint('🔍 Checking stored key: ${storedKey != null ? "Found key starting with ${storedKey.substring(0, 10)}..." : "No key found"}');
      debugPrint('🖥️ Platform: ${Platform.operatingSystem}');
      
      if (storedKey != null && storedKey.startsWith('ij_life_')) {
        debugPrint('✅ Valid lifetime key found in storage');
        return storedKey;
      }

      debugPrint('❌ No valid lifetime key in storage');
      return null;
    } catch (e) {
      debugPrint('❌ Error loading stored lifetime key: $e');
      return null;
    }
  }

  /// Store subscription key 
  Future<void> _storeSubscriptionKey(String licenseKey) async {
    // Use SharedPreferences directly for simpler Windows deployment
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('subscription_key', licenseKey);
    debugPrint('✅ Subscription key stored in SharedPreferences');
  }

  /// Get stored subscription key
  Future<String?> _getStoredSubscriptionKey() async {
    try {
      // Use SharedPreferences directly for simpler Windows deployment
      final prefs = await SharedPreferences.getInstance();
      final storedKey = prefs.getString('subscription_key');
      if (storedKey != null && storedKey.startsWith('ij_sub_')) {
        return storedKey;
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error loading stored subscription key: $e');
      return null;
    }
  }

  /// Generate unique device ID (only needed for Stripe subscriptions)
  Future<String> _getDeviceId() async {
    try {
      // Try SharedPreferences first (more reliable than secure storage for device ID)
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString(_deviceIdKey);
      if (deviceId != null) return deviceId;

      // Generate new device ID with simpler approach
      String uniqueId;

      try {
        final deviceInfo = DeviceInfoPlugin();

        if (Platform.isMacOS) {
          final macInfo = await deviceInfo.macOsInfo;
          // Use only computer name and avoid systemGUID (requires entitlements)
          uniqueId = '${macInfo.computerName}_${macInfo.arch}_macos';
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          uniqueId = '${iosInfo.name}_${iosInfo.model}_ios';
        } else if (Platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          uniqueId = '${androidInfo.device}_${androidInfo.model}_android';
        } else if (Platform.isWindows) {
          final windowsInfo = await deviceInfo.windowsInfo;
          uniqueId = '${windowsInfo.computerName}_windows';
        } else if (Platform.isLinux) {
          final linuxInfo = await deviceInfo.linuxInfo;
          uniqueId = '${linuxInfo.name}_linux';
        } else {
          uniqueId = 'unknown_${Platform.operatingSystem}';
        }
      } catch (e) {
        debugPrint('⚠️ DeviceInfo failed, using fallback: $e');
        uniqueId =
            'fallback_${Platform.operatingSystem}_${DateTime.now().millisecondsSinceEpoch}';
      }

      // Hash the unique ID for privacy and add timestamp for uniqueness
      final bytes =
          utf8.encode('$uniqueId${DateTime.now().millisecondsSinceEpoch}');
      final digest = sha256.convert(bytes);
      deviceId = digest.toString();

      // Cache in SharedPreferences (more reliable than secure storage)
      await prefs.setString(_deviceIdKey, deviceId);
      debugPrint('✅ Generated new device ID: ${deviceId.substring(0, 8)}...');

      return deviceId;
    } catch (e) {
      debugPrint('❌ Error generating device ID: $e');
      // Ultimate fallback
      final fallbackId = 'fallback_${DateTime.now().millisecondsSinceEpoch}';
      return fallbackId;
    }
  }
}
